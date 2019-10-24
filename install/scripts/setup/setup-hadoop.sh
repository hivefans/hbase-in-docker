#!/bin/bash

# generate known_hosts
known_hosts='/home/hadoop/.ssh/known_hosts'
echo > "${known_hosts}"
while read -r host; do
  ssh-keyscan -t rsa -H "${host}" >> "${known_hosts}"
done < /home/hadoop/hadoop-current/etc/hadoop/slaves
chmod 0600 "${known_hosts}"

while read -r host; do
  scp "${known_hosts}" "${host}:~/.ssh/"
done < /home/hadoop/hadoop-current/etc/hadoop/slaves

# start hadoop cluster
hadoop-daemons.sh start journalnode

slaves='/home/hadoop/hadoop-current/etc/hadoop/slaves'
nn1="$(sed -n '1p' "${slaves}")"
nn2="$(sed -n '2p' "${slaves}")"
ssh "${nn1}" '/home/hadoop/hadoop-current/bin/hdfs namenode -format'
ssh "${nn1}" '/home/hadoop/hadoop-current/sbin/hadoop-daemon.sh start namenode'
ssh "${nn2}" '/home/hadoop/hadoop-current/bin/hdfs namenode -bootstrapStandby'
ssh "${nn2}" '/home/hadoop/hadoop-current/sbin/hadoop-daemon.sh start namenode'

hadoop-daemons.sh start datanode
hdfs haadmin -transitionToActive nn1
