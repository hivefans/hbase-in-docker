#!/bin/bash

function start_container() {
  local id="${1}"
  local add_hosts=(${2})
  local ip="$(get_ip "${id}")"
  local hostname="$(get_hostname "${id}")"
  local name="${hostname%.com}"
  local home_path="home${id}"
  local disk_path="disk${id}"

  docker run -itd \
    --mount type=bind,source=/sys/fs/cgroup,target=/sys/fs/cgroup,readonly \
    --mount type=tmpfs,destination=/run \
    --mount type=tmpfs,destination=/run/lock \
    --mount source="${home_path}",target=/home/hadoop \
    --mount source="${disk_path}",target=/data \
    --name "${name}" \
    --hostname "${hostname}" \
    --ip "${ip}" \
    "${add_hosts[@]}" hbase-in-docker
}

function start_cluster() {
  local num="${1}"
  local add_hosts=''
  for i in $(seq 1 "${num}"); do
    local ip="$(get_ip "${i}")"
    add_hosts="${add_hosts}--add-host $(get_hostname "${i}"):${ip} "
  done

  for i in $(seq 1 "${num}"); do
    start_container "${i}" "${add_hosts}"
  done
}

function get_ip() {
  local id="${1}"
  local gateway="172.17.0.2"
  local prefix="${gateway%.*}"
  local suffix="${gateway##*.}"
  echo "${prefix}.$((suffix + i))"
}

function get_hostname() {
  local id="${1}"
  echo "hbase-cluster-n${id}.com"
}

start_cluster 3
