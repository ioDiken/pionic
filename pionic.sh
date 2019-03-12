#!/bin/bash
# This runs at boot, start test station operation
# It can also be run manually to restart all services

# factory server address, change this if needed
factory_server=10.2.3.4:8000

set -ue; trap 'echo $0: line $LINENO: exit status $? >&2' ERR

die() { echo "$*" >&2; exit 1; }
((UID==0)) || die "Must be root!"


case "${1:-start}" in
    start)
        beacon=~pi/pionic/beacon/beacon; [ -x $beacon ] || die "Need executable $beacon"
        cgiserver=~pi/pionic/cgiserver; [ -x $cgiserver ] || die "Need executable $cgiserver"

        # Factory is attached to eth0, DUT is attached to eth1 via usb ethernet dongle
        # The factory interface gets an address via DHCP, the DUT interace is static
        ip l set eth1 up || die "No eth1 device" 
        ip a a dev eth1 172.31.255.1/24
        
        # NAT the DUT to the factory
        echo 1 > /proc/sys/net/ipv4/ip_forward
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
        #sudo iptables -A FORWARD -i eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT  

        # Forward port 2222 from the factory to DUT's ssh
        iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 2222 -j DNAT --to 172.31.255.2:22
        # iptables -A FORWARD -i eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT  

        # Start the beacon server on eth1, the payload contains the factory
        # server address and port.
        $beacon send eth1 $factory_server &

        # Start cgi server, bind to eth1
        #$cgiserver -b 172.31.255.1 -p 80 -d cgi &
        $cgiserver -p 80 -d ~pi/pionic/cgi &

	# use the console for test output
	systemctl stop getty@tty1.service
	setterm --cursor off > /dev/tty1
	dmesg -n 1

        sleep 2
        $0 show
        ;;

    stop)
        pkill -f beacon || true
        pkill -f cgiserver || true
        ip a flush eth1 
        ip l set eth1 down
        echo 0 > /proc/sys/net/ipv4/ip_forward
        iptables -F; iptables -X; iptables -t nat -F
        cat /dev/zero > /dev/fb0 2>/dev/null || true
        ;;
       
    res*) 
        $0 stop
        $0 start
        ;;

    show)
        curl --data-binary @- 'http://localhost/display?command=text&fg=yellow&bg=blue&point=50' <<EOT
PIONIC is alive!
ETH0 MAC: $(cat /sys/class/net/eth0/address) 
ETH1 MAC: $(cat /sys/class/net/eth1/address) 
UPTIME  : $(cat /proc/uptime)
LOADAVG : $(cat /proc/loadavg)
EOT
        ;;        

    *) die "Usage: $0 stop|start|restart"
esac   
true

