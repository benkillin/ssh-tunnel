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

localTunAddr="10.0.0.100";

remoteTunAddr="10.0.0.200";
remoteTunNATAddr="${remoteTunAddr}/32";

tunnelIf="tun0";
internetIf="eth0";

if [ "$1" == "up" ] ;
then
        ifconfig $tunnelIf $localTunAddr pointopoint $remoteTunAddr

        arp -sD $remoteTunAddr $internetIf pub

        echo 1 > /proc/sys/net/ipv4/ip_forward
        echo 1 > /proc/sys/net/ipv4/conf/all/forwarding

        iptables --table nat --flush

# TODO: Figure out how to make this firewall rule work with DROP

        iptables -P FORWARD ACCEPT
        iptables -t nat -A POSTROUTING -o $internetIf -s $remoteTunNATAddr -j MASQUERADE
#       iptables -A FORWARD -i $internetIf -m state --state NEW,INVALID -j DROP
else
        echo 0 > /proc/sys/net/ipv4/ip_forward
        echo 0 > /proc/sys/net/ipv4/conf/all/forwarding

        iptables --table nat --flush
        iptables -F FORWARD
        iptables -P FORWARD DROP

        /etc/init.d/firewall restart
fi