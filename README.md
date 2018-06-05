# ssh-tunnel
Bash scripts for making an ssh tunnel for tunneling general traffic.

# WARNING
There are intentional errors in these scripts.

# Usage
USAGE: {scriptname} [up [reverse]]

If up is specified as first argument, that means start the tunnel.

If no parameters are specified, that means tear down the tunnel.

If up and reverse are specified as the first and second parameter, that means start the tunnel in reverse order, meaning you have the endpoint initiate the ssh call (for example if the endpoint is behind nat and you can't set up port forwarding on that end but you control your end). 

Normally you start `ssh_tunnel.sh up` on your local box first then, during the pause, you start `ssh_tunnel_endpoint.sh up` on the remote box. 

In reverse you start `ssh_tunnel_endpoint.sh up reverse` first on the remote box, then `ssh_tunnel.sh up reverse` on the local box. 

Then if you want other machines to go through the tunnel set the local box ip as their default gateway, or set up the routing on the other machines to only use the local box as the gateway for a certain network, whatever you want

Note: You must edit the endpoint, endpointip, bypassips, localGateway, localSubnet, and internetIf variables at the top of ssh_tunnel.sh

endpoint is the hostname or IP of the remote server that is given to ssh.

endpointip is the ip of the remote server that is used in setting up the routing tables

internetIf is the name of the interface that provides your internet connection

localGateway is the local default gateway that you use to access the internet.

localSubnet is the subnet that you are on behind your gateway. 

tunnelIf is the interface that is created and used for the SSH tunnel. If this tunnel interface is already in use, you must change this tunnelIf variable, AND you must change the line below where SSH is executed with the -w option, and  and change the -w 0:0 to 1:1 or 2:2, etc... where the number will be the number used in the tunnelIf variable such as tun1 or tun2.

localTunAddr and remoteTunAddr are the IP's used on the point to point link established by the SSH tunnel, locally and remotely.  If this address is already used locally or remotely, you must change it.
