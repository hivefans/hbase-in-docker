#!/bin/bash

interface="$(netstat -r | grep default | awk '{print $NF}')"

sudo iptables -A FORWARD -i "${interface}" -o br-hadoop -j ACCEPT
