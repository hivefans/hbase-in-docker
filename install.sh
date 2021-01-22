#!/bin/bash

HOME="$(dirname "${BASH_SOURCE[0]}")"
INSTALL_PATH="${HOME}/install"
ARCHIVES_PATH="${INSTALL_PATH}/archives"
SSHKEY_PATH="${INSTALL_PATH}/ssh"

hadoop_package='hadoop-2.9.2.tar.gz'
hadoop_package_url='https://mirrors.aliyun.com/apache/hadoop/common/hadoop-2.9.2/hadoop-2.9.2.tar.gz'

hbase_package='hbase-2.2.6-bin.tar.gz'
hbase_package_url='https://mirrors.aliyun.com/apache/hbase/2.2.6/hbase-2.2.6-bin.tar.gz'

if [[ ! -f "${ARCHIVES_PATH}/${hadoop_package}" ]]; then
  echo 'download hadoop'
  curl -fLo "${ARCHIVES_PATH}/${hadoop_package}" --create-dirs "${hadoop_package_url}"
fi

if [[ ! -f "${ARCHIVES_PATH}/${hbase_package}" ]]; then
  echo 'download hbase'
  curl -fLo "${ARCHIVES_PATH}/${hbase_package}" --create-dirs "${hbase_package_url}"
fi

mkdir -p "${SSHKEY_PATH}"
yes | ssh-keygen -t rsa -N '' -f "${SSHKEY_PATH}/id_rsa"

docker build -t hbase-in-docker .
