#!/bin/bash

HOME="/home/hadoop"
hbase_package="$(find /root/install/archives/ -type f -name 'hbase-*.tar.gz')"
tar -zxvf "${hbase_package}" -C "${HOME}"
hbase_path="$(find "${HOME}" -mindepth 1 -maxdepth 1 -type d | grep hbase-)"
ln -snf "${hbase_path}" "${HOME}/hbase-current"

hbase_conf_path="${HOME}/hbase-current/conf"
cp /root/install/conf/hbase/conf/* /home/hadoop/hbase-current/conf/

chown -R hadoop:hadoop "${HOME}"/hbase-*

sudo -u hadoop mkdir -p /data/conf/hbase
sudo -u hadoop mv /home/hadoop/hbase-current/conf /data/conf/hbase/
sudo -u hadoop cp /data/conf/hadoop/hdfs-site.xml /data/conf/hbase/conf/

JAVA_HOME='/usr/lib/jvm/java-1.8.0-openjdk-amd64'
HBASE_LOG_DIR='/home/hadoop/cluster-data/hbase/logs'
HBASE_PID_DIR='/home/hadoop/cluster-data/hbase/pids'

commands='
s/# export JAVA_HOME=.*/export JAVA_HOME='"${JAVA_HOME//\//\\\/}"'/
s/# export HBASE_LOG_DIR=.*/export HBASE_LOG_DIR='"${HBASE_LOG_DIR//\//\\\/}"'/
s/# export HBASE_PID_DIR=.*/export HBASE_PID_DIR='"${HBASE_PID_DIR//\//\\\/}"'/
'
sudo -u hadoop sed -i "${commands}" /data/conf/hbase/conf/hbase-env.sh
sudo -u hadoop ln -snf /data/conf/hbase/conf "${hbase_conf_path}"

# setup environment
hbase_bin_path="/home/hadoop/hbase-current/bin"
sudo -u hadoop echo 'export PATH="'"${hbase_bin_path}"':${PATH}"' >> /home/hadoop/.bash_profile
