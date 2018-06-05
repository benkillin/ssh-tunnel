# USAGE: {scriptname} [up [reverse]]
# if up is specified as first argument, that means start the tunnel
# if no parameters are specified, that means tear down the tunnel
# if up and reverse are specified as the first and second parameter, 
# that means start the tunnel in reverse order, meaning you have the endpoint
# initiate the ssh call (for example if the endpoint is behind nat and you cant
# set up port forwarding on that end but you control your end).
# normally you start `ssh_tunnel.sh up` on your local box first, then during the
# duration pause, you start `ssh_tunnel_endpoint.sh up` on the remote box 
# if in reverse you start `ssh_tunnel_endpoint.sh up reverse` first on the 
# remote box, then `ssh_tunnel.sh up reverse` on the local box. 
#
# then if you want other machines to go through the tunnel set the local box
# ip as their default gateway, or set up the routing on the other machines to
# only use the local box as the gateway for a certain network, whatever you want
#
# Note: You must edit the endpoint, endpointip, bypassips, localGateway, 
# localSubnet, and internetIf variables at the top of ssh_tunnel.sh
# endpoint is the hostname or IP of the remote server that is given to ssh.
# endpoint ip is the ip of the remote server that is used in setting up the 
#  routing tables
# internetIf is the name of the interface that provides your internet connection
# localGateway is the local default gateway that you use to access the internet.
# localSubnet is the subnet that you are on behind your gateway. 
# tunnelIf is the interface that is created and used for the SSH tunnel. If this
# tunnel interface is already in use, you must change this tunnelIf variable, AND
# you must change the line below where SSH is executed with the -w option, and 
# and change the -w 0:0 to 1:1 or 2:2, etc... where the number will be the number 
# used in the tunnelIf variable such as tun1 or tun2.
# localTunAddr and remoteTunAddr are the IP's used on the point to point link
# established by the SSH tunnel, locally and remotely. If this address is already
# used locally or remotely, you must change it.
echo you gotta cut these up!
exit 999999999
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
sshKey="/home/asdfasdfasdfasdfsafdasdf/.ssh/id_rsa";

endpoint="asdfasdfasdfasdfasdf.asdf";
endpointip="xxx.xxx.xxx.xxx";

#the following hosts and nets will bypass the tunnel and go through the 
#default gateway
# NOTE: If you use the net: prefix, you must specify netmask in CIDR notation
bypassips="host:xxx.xxx.xxx.xxx net:xxx.xxx.xxx.xxx/xx";

localTunAddr="10.0.69.201";
localGateway="192.168.69.1";
localSubnet="192.168.69.0/24";

remoteTunAddr="10.0.69.101";
tunNet="10.0.69.0";
tunNetMask="255.255.254.0";

tunnelIf="tun0";
internetIf="br0";

gracePeriod=10;

if [ "$1" == "up" ] ;
then
	# set up tunnel
	
	if [ "$2" != "reverse" ] ;
	then
	    $ssh -NTCf -w 0:0 -p $sshport -i $sshKey $endpoint
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





#!/bin/bash
## This script will set up an ssh tunnel and set this computer up as a router
## to route all traffic through the tunnel.
##
## Author: benkillin 
## Date: 14 September 2010
## File: ssh_tunnel_endpoint.sh
##
## see https://help.ubuntu.com/community/SSH_VPN
## see http://www.net42.co.uk/os/linux/sharing_3g_with_hostapd.html
## see http://www.tldp.org/HOWTO/IP-Masquerade-HOWTO/firewall-examples.html
## see http://www.yolinux.com/TUTORIALS/LinuxTutorialIptablesNetworkGateway.html
## see http://forum.slicehost.com/comments.php?DiscussionID=3424
## This script is for machine A in that ubuntu example document.
## This script must be run as root.

ssh="/usr/bin/ssh -C4c arcfour,blowfish-cbc";
sshport="22";
sshKey="/asdfasdfasdf/.ssh/id_rsa";

endpoint="xxx.xxx.xxx.xxx";

localTunAddr="10.0.69.101";

remoteTunAddr="10.0.69.201";
remoteTunNATAddr="${remoteTunAddr}/32";

tunnelIf="tun0";
internetIf="eth0";

if [ "$1" == "up" ] ;
then
    
    if [ "$2" == "reverse" ] ;
    then
        $ssh -NTCf -w 0:0 -p $sshport -i $sshKey $endpoint
    fi

	ifconfig $tunnelIf $localTunAddr pointopoint $remoteTunAddr
	
	arp -sD $remoteTunAddr $internetIf pub
	
	echo 1 > /proc/sys/net/ipv4/ip_forward
	echo 1 > /proc/sys/net/ipv4/conf/all/forwarding

	iptables --table nat --flush

# TODO: Figure out how to make this firewall rule work with DROP

	iptables -P FORWARD ACCEPT
	iptables -t nat -A POSTROUTING -o $internetIf -s $remoteTunNATAddr -j MASQUERADE
else
	echo 0 > /proc/sys/net/ipv4/ip_forward
	echo 0 > /proc/sys/net/ipv4/conf/all/forwarding
	
	iptables --table nat --flush
	iptables -F FORWARD
	iptables -P FORWARD DROP
	
	/etc/init.d/firewall restart
fi


