#!/bin/bash

SETUP_PATH="$(dirname "${BASH_SOURCE[0]}")"
LOG_PATH="${SETUP_PATH}/log"
SERVERS="/home/hadoop/hadoop-current/etc/hadoop/slaves"
PROCESS_LOG="${LOG_PATH}/process.log"
INSTALLED_MARK='/data/.hadoop-installed'

HADOOP_BIN='/home/hadoop/hadoop-current/bin'
HADOOP_SBIN='/home/hadoop/hadoop-current/sbin'
HBASE_BIN='/home/hadoop/hbase-current/bin'

function log() {
  local level="${1}"
  local message="${2}"
  local date="$(date +'%Y-%m-%d %H:%M:%S')"
  local log="${LOG_PATH}/autostart.log"
  echo "${date} [${level}] - ${message}" >> "${log}"
}

function log_info() {
  local message="${1}"
  log 'INFO' "${message}"
}

function log_warn() {
  local message="${1}"
  log 'WARN' "${message}"
}

function log_error() {
  local message="${1}"
  log 'ERROR' "${message}"
}

function init() {
  mkdir -p "${LOG_PATH}"
}

function get_master() {
  head -n 1 "${SERVERS}"
}

function is_master() {
  if [[ "$(hostname -f)" == "$(get_master)" ]]; then
    return 0
  else
    return 1
  fi
}

function remote_cmd() {
  local host="${1}"
  local cmd="${2}"
  ssh -n -o StrictHostKeyChecking=no -o ConnectTimeout=1 "${host}" "${cmd}"
}

function check_all_servers_up() {
  local all_up=true
  for i in {1..300}; do
    all_up=true
    while read -r host; do
      log_info "check ${host} status"
      if ! remote_cmd "${host}" 'exit'; then
        log_warn "${host} is down"
        all_up=false
        break
      fi
    done < "${SERVERS}"
    if ${all_up}; then
      log_info 'all servers are up'
      return 0
    else
      log_info 'waiting for down server'
      sleep 1
    fi
  done
  return 1
}

function copy_known_hosts() {
  log_info 'copy known_hosts to slaves'
  local known_hosts='/home/hadoop/.ssh/known_hosts'
  echo > "${known_hosts}"
  while read -r host; do
    ssh-keyscan -t rsa -H "${host}" >> "${known_hosts}"
  done < "${SERVERS}"

  while read -r host; do
    scp "${known_hosts}" "${host}:~/.ssh/"
  done < "${SERVERS}"
}

function check_services() {
  local pid_file="${1}"
  local process="${2}"
  local all_up=true
  for i in {1..30}; do
    all_up=true
    while read -r host; do
      log_info "check ${host}'s ${process} status"
      if ! remote_cmd "${host}" 'jps | grep $(< '"${pid_file}"") | grep ${process} > /dev/null"; then
        log_warn "${host}'s ${process} is down"
        all_up=false
      fi
    done < "${SERVERS}"
    if ${all_up}; then
      log_info "all ${process} are up"
      return 0
    else
      log_info 'waiting for down service'
      sleep 5
    fi
  done
  return 1
}

function check_services_on_host() {
  local host="${1}"
  local pid_file="${2}"
  local process="${3}"
  for i in {1..30}; do
    log_info "check ${host}'s ${process} status"
    if remote_cmd "${host}" 'jps | grep $(< '"${pid_file}"") | grep ${process} > /dev/null"; then
      return 0
    else
      log_warn "${host}'s ${process} is down"
      sleep 1
    fi
  done
  return 1
}

function start_journalnodes() {
  log_info 'start journalnodes'
  "${HADOOP_SBIN}"/hadoop-daemons.sh start journalnode 1>>"${PROCESS_LOG}" 2>&1

  local pid_file='/home/hadoop/cluster-data/pids/hadoop-hadoop-journalnode.pid'
  if check_services "${pid_file}" 'JournalNode'; then
    return 0
  else
    return 1
  fi
}

function start_namenodes() {
  log_info 'start namenodes'
  local nn1="$(sed -n '1p' "${SERVERS}")"

  "${HADOOP_BIN}"/hdfs namenode -format 1>>"${PROCESS_LOG}" 2>&1
  "${HADOOP_SBIN}"/hadoop-daemon.sh start namenode 1>>"${PROCESS_LOG}" 2>&1

  local pid_file='/home/hadoop/cluster-data/pids/hadoop-hadoop-namenode.pid'
  if ! check_services_on_host "${nn1}" "${pid_file}" 'NameNode'; then
    log_error "failed to start ${nn1}'s namenode"
    return 1
  fi

  local nn2="$(sed -n '2p' "${SERVERS}")"
  remote_cmd "${nn2}" "${HADOOP_BIN}/hdfs namenode -bootstrapStandby"
  remote_cmd "${nn2}" "${HADOOP_SBIN}/hadoop-daemon.sh start namenode"

  if ! check_services_on_host "${nn2}" "${pid_file}" 'NameNode'; then
    log_error "failed to start ${nn2}'s namenode"
    return 1
  fi

  return 0
}

function start_datanodes() {
  log_info 'start datanodes'
  "${HADOOP_SBIN}"/hadoop-daemons.sh start datanode 1>>"${PROCESS_LOG}" 2>&1

  local pid_file='/home/hadoop/cluster-data/pids/hadoop-hadoop-datanode.pid'
  if check_services "${pid_file}" 'DataNode'; then
    return 0
  else
    return 1
  fi
}

function check_hdfs() {
  local nn1="$(sed -n '1p' "${SERVERS}")"
  local pid_file='/home/hadoop/cluster-data/pids/hadoop-hadoop-namenode.pid'
  if ! check_services_on_host "${nn1}" "${pid_file}" 'NameNode'; then
    log_error "failed to start ${nn1}'s namenode"
    return 1
  fi

  pid_file='/home/hadoop/cluster-data/pids/hadoop-hadoop-datanode.pid'
  if ! check_services "${pid_file}" 'DataNode'; then
    log_error "failed to start datanodes"
    return 1
  fi

  local nn2="$(sed -n '2p' "${SERVERS}")"
  pid_file='/home/hadoop/cluster-data/pids/hadoop-hadoop-namenode.pid'
  if ! check_services_on_host "${nn2}" "${pid_file}" 'NameNode'; then
    log_error "failed to start ${nn2}'s namenode"
    return 1
  fi

  pid_file='/home/hadoop/cluster-data/pids/hadoop-hadoop-journalnode.pid'
  if ! check_services "${pid_file}" 'JournalNode'; then
    log_error "failed to start journalnodes"
    return 1
  fi

  return 0
}

function set_active_namenode() {
  local namenode="${1}"
  for i in {1..30}; do
    log_info "set ${namenode} active"
    "${HADOOP_BIN}"/hdfs haadmin -transitionToActive "${namenode}" 1>>"${PROCESS_LOG}" 2>&1
    local state="$("${HADOOP_BIN}"/hdfs haadmin -getServiceState "${namenode}")"
    if [[ "${state}" == 'active' ]]; then
      return 0
    else
      log_warn "failed to set ${namenode} active - state: ${state}"
      sleep 1
    fi
  done
  return 1
}

function main() {
  init

  if ! is_master; then
    log_info "slave [$(hostname -f)] exits"
    exit 0
  fi

  if ! check_all_servers_up; then
    log_error 'some servers are down'
    exit 1
  fi

  if ls "${INSTALLED_MARK}" > /dev/null 2>&1; then
    log_info 'hadoop was installed'

    log_info 'start dfs'
    "${HADOOP_SBIN}"/start-dfs.sh 1>>"${PROCESS_LOG}" 2>&1

    if ! check_hdfs; then
      log_error 'failed to start hdfs'
      exit 1
    fi

    if ! set_active_namenode 'nn1'; then
      log_error 'failed to set nn1 active'
      exit 1
    fi

    log_info 'start hbase'
    "${HBASE_BIN}"/start-hbase.sh 1>>"${PROCESS_LOG}" 2>&1

    exit 0
  fi

  copy_known_hosts

  if ! start_journalnodes; then
    log_error 'failed to start journalnodes'
    exit 1
  fi

  if ! start_namenodes; then
    log_error 'failed to start namenodes'
    exit 1
  fi

  if ! start_datanodes; then
    log_error 'failed to start datanodes'
    exit 1
  fi

  log_info 'set nn1 active'
  "${HADOOP_BIN}"/hdfs haadmin -transitionToActive nn1 1>>"${PROCESS_LOG}" 2>&1

  log_info 'set installed mark'
  touch "${INSTALLED_MARK}"

  log_info 'start hbase'
  "${HBASE_BIN}"/start-hbase.sh 1>>"${PROCESS_LOG}" 2>&1
}

main "${@}"
