#!/bin/bash
## This script will set up an ssh tunnel and set this computer up as a router
## to route all traffic through the tunnel.
##
## Author: benkillin 
## Date: 14 September 2010
## File: ssh_tunnel.sh
##
## see https://help.ubuntu.com/community/SSH_VPN
## see http://www.net42.co.uk/os/linux/sharing_3g_with_hostapd.html
## see http://www.tldp.org/HOWTO/IP-Masquerade-HOWTO/firewall-examples.html
## see http://www.yolinux.com/TUTORIALS/LinuxTutorialIptablesNetworkGateway.html
## see http://forum.slicehost.com/comments.php?DiscussionID=3424
## This script is for machine B in that ubuntu example document.
## This script must be run as root.

ssh="/usr/bin/ssh -C4c arcfour,blowfish-cbc";
sshport="22";
#ssh="/opt/sshhpn/bin/ssh";
#sshport="48879";
sshKey="/home/b3nk/.ssh/id_rsa";

#endpoint="EXAMPLE.HOST";
#endpointip="EXAMPLE.IPV4.IP.ADDRESS";
#endpoint="EXAMPLE.HOST2";
#endpointip="EXAMPLE.IPV4.IP.ADDRESS2";
endpoint="EXAMPLE.IPV4.IP.ADDRESS3";
endpointip="EXAMPLE.IPV4.IP.ADDRESS4";

#the following hosts and nets will bypass the tunnel and go through the 
#default gateway
# NOTE: If you use the net: prefix, you must specify netmask in CIDR notation
bypassips="host:xx.xx.xx.xx net:xx.xx.xx.xx/xx";

localTunAddr="10.0.69.200";
localGateway="192.168.69.1";
localSubnet="192.168.69.0/24";

remoteTunAddr="10.0.69.100";
tunNet="10.0.69.0";
tunNetMask="255.255.254.0";

tunnelIf="tun1";
internetIf="eth0";

gracePeriod=1;

if [ "$1" == "up" ] ;
then
	# set up tunnel
	
	if [ "$2" != "reverse" ] ;
	then
	    $ssh -NTCf -w 1:1 -p $sshport -i $sshKey $endpoint
	fi

	ifconfig $tunnelIf $localTunAddr pointopoint $remoteTunAddr
	
	echo "Sleeping $gracePeriod seconds.";
	echo "You must execute the sister script on the tunnel endpoint before the grace period expires..";
	sleep $gracePeriod;
	echo "Continuing...";
	sleep 3;
	
	route add -net $tunNet netmask $tunNetMask gw $localTunAddr $tunnelIf

    # add explicit route to be able to get to the endpoint.
	route add $endpointip gw $localGateway $internetIf
	
	for ip in $bypassips ;
	do
		# have traffic for certain IPs not go through the tunnel.

		type=`echo $ip | awk -F ':' '{ print $1; }'`;
		addr=`echo $ip | awk -F ':' '{ print $2; }'`;
		
		if [ "$type" == "host" ] ;
		then
			route add $addr gw $localGateway $internetIf;
		else
			route add -net $addr gw $localGateway $internetIf;
		fi
	done;

	route add default gw $remoteTunAddr $tunnelIf
	
	route del default gw $localGateway $internetIf

	echo 1 > /proc/sys/net/ipv4/ip_forward
	echo 1 > /proc/sys/net/ipv4/conf/all/forwarding

	iptables --table nat --flush

# TODO: Figure out how to make this firewall rule work with DROP.

	iptables -P FORWARD ACCEPT
	iptables -t nat -A POSTROUTING -o $tunnelIf -s $localSubnet -j MASQUERADE

#	iptables -A FORWARD -o $tunnelIf -s $localSubnet -j ACCEPT
#	iptables -A FORWARD -d $localSubnet -m state --state ESTABLISHED,RELATED -i $tunnelIf -j ACCEPT
else
	# tear down tunnel
	echo adding default gw
	route add default gw $localGateway $internetIf

	echo removing tunnel default gw
	route del default gw $remoteTunAddr $tunnelIf

	echo removing tunnel network route
	route del -net $tunNet netmask $tunNetMask gw $localTunAddr $tunnelIf

	echo removing explicit route through localGw to endpointip...
	route del $endpointip gw $localGateway $internetIf
	
	echo removing explicit routes for ips set up to not go through tunnel
	
	for ip in $bypassips ;
        do
                # have traffic for certain IPs not go through the tunnel.

                type=`echo $ip | awk -F ':' '{ print $1; }'`;
                addr=`echo $ip | awk -F ':' '{ print $2; }'`;

                if [ "$type" == "host" ] ;
                then
                        route del $addr gw $localGateway $internetIf;
                else
                        route del -net $addr gw $localGateway $internetIf;
                fi
        done;
	
	echo 0 > /proc/sys/net/ipv4/ip_forward
	echo 0 > /proc/sys/net/ipv4/conf/all/forwarding
	
	iptables --table nat --flush
	iptables -F FORWARD
	iptables -P FORWARD DROP
	
	echo "killing `ps aux | grep "$ssh -NTCf" | grep -v grep | awk '{ print $2; }'`;";
	kill -9 `ps aux | grep "$ssh -NTCf" | grep -v grep | awk '{ print $2; }'`;
	
	echo "routing table:";
	route -n;
	echo "iptables;";
	iptables -L;
fi





