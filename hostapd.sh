#!/bin/bash
## script for starting the hostapd wifi bridge:
# author: benkillin
#######
# This assumes your config is set up to require a bridge, such as the case with
# the nl80211 and madwifi wlan drives.
######
#

WLANIF=wlan0
BR=br0
hostapdconf=/etc/hostapd/hostapd.conf

brctl=/usr/sbin/brctl
grep=/bin/grep
hostapd=/usr/sbin/hostapd

echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv4/conf/all/forwarding

inthebridge=`$brctl show | $grep $WLANIF`
go=true

if [ -z "$inthebridge" ] ;
then
	$brctl addif $BR $WLANIF

	if [ ! $? ]; 
	then
		# this is a little workaround I have discovered when sometimes 
		# on my computer (I use the nl80211 driver) I am unable to add
		# wlan0 to the bridge after a reboot for some reason. If I 
		# activate hostapd then kill it, then I can add the wlan if
		# to the bridge:
		
		`$hostapd $hostapdconf &`
		sleep 5
		killall hostapd
		sleep 1 
		
		$brctl addif $BR $WLANIF
		if [ ! $? ];
		then 
			echo  "YOU ARE FUCKED!" 1>&2
			go=false
		fi
	fi
fi

if [ $go ];
then
	$hostapd $hostapdconf
fi
