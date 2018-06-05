#!/bin/sh

ifconfig br0 down
brctl delif br0 eth0
brctl delif br0 wlan0
brctl delbr br0

#ifconfig eth0 up
#ifconfig eth0 192.168.0.4 netmask 255.255.255.0
#route add default gw 192.168.0.1 eth0

