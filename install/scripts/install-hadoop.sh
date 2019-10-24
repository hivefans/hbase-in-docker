#!/bin/bash

HOME="/home/hadoop"
hadoop_package="$(find /root/install/archives/ -type f -name 'hadoop-*.tar.gz')"
tar -zxvf "${hadoop_package}" -C "${HOME}"
hadoop_path="$(find "${HOME}" -mindepth 1 -maxdepth 1 -type d | grep hadoop-)"
ln -snf "${hadoop_path}" "${HOME}/hadoop-current"

hadoop_conf_path="${HOME}/hadoop-current/etc/hadoop"
cp /root/install/conf/hadoop/* "${hadoop_conf_path}/"

mv /root/install/scripts/setup "${HOME}/"

chown -R hadoop:hadoop "${HOME}"/hadoop-* "${HOME}/setup"

sudo -u hadoop mkdir -p /data/conf
sudo -u hadoop mv "${hadoop_conf_path}" /data/conf/

JAVA_HOME='/usr/lib/jvm/java-1.8.0-openjdk-amd64'
HADOOP_LOG_DIR='/home/hadoop/cluster-data/logs'
HADOOP_PID_DIR='/home/hadoop/cluster-data/pids'

commands='
s/${JAVA_HOME}/'"${JAVA_HOME//\//\\\/}"'/
s/#export HADOOP_LOG_DIR=.*/export HADOOP_LOG_DIR='"${HADOOP_LOG_DIR//\//\\\/}"'/
s/export HADOOP_PID_DIR=.*/export HADOOP_PID_DIR='"${HADOOP_PID_DIR//\//\\\/}"'/
'
sudo -u hadoop sed -i "${commands}" /data/conf/hadoop/hadoop-env.sh
sudo -u hadoop ln -snf /data/conf/hadoop "${hadoop_conf_path}"

# setup environment
hadoop_bin_path="/home/hadoop/hadoop-current/bin:/home/hadoop/hadoop-current/sbin"
sudo -u hadoop echo 'export PATH="'"${hadoop_bin_path}"':${PATH}"' >> /home/hadoop/.bash_profile
