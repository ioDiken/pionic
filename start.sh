#!/bin/bash
# This runs at boot, start test station operation
# It can also be run manually to restart all services

set -ue; trap 'echo $0: line $LINENO: exit status $? >&2' ERR

die() { echo "$*" >&2; exit 1; }
((UID==0)) || die "Must be root!"

beacon=~pi/pionic/beacon/beacon
[ -x $beacon ] || die "Need executable $beacon"

cgiserver=~pi/pionic/cgiserver.py
[ -x $cgiserver ] || die "Need executable $cgiserver"


case "${1:-}" in
    start)
        # Factory is attached to eth0, DUT is attached to eth1 via usb ethernet dongle
        # The factory interface gets an address via DHCP, the DUT interace is static
        ip l set eth1 up
        ip a a dev eth1 172.31.255.1/24
        
        # NAT the DUT to the factory
        echo 1 > /proc/sys/net/ipv4/ip_forward
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
        #sudo iptables -A FORWARD -i eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT  

        # Forward port 2222 from the factory to DUT's ssh
        iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 2222 -j DNAT --to 172.31.255.2:22
        # iptables -A FORWARD -i eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT  

        # Start the beacon server on eth1, the payload tells DUT what address to use
        # and the ip:port of the test controller cgi interface.
        $beacon send eth1 "172.31.255.2/24 172.31.255.1:80" &

        # Start cgi server
        #$cgiserver -b 172.31.255.1 -p 80 -d cgi &
        $cgiserver -p 80 -d ~pi/pionic/cgi &

        echo "$0 has been started"
        ;;

    stop)
        pkill -f beacon || true
        pkill -f cgiserver.py || true
        ip a flush eth1 
        ip l set eth1 down
        echo 0 > /proc/sys/net/ipv4/ip_forward
        iptables -F; iptables -X; iptables -t nat -F
        echo "$0 has been stopped"
        ;;
       
    res*) 
        $0 stop
        $0 start
        ;;

    *) die "Usage: $0 stop|start|restart"
esac    
