#!/bin/bash
# This runs at boot, start test station operation
# It can also be run manually to restart all services

# factory server address, change this if needed
factory_server=10.2.3.4:8000

set -ue; trap 'echo $0: line $LINENO: exit status $? >&2' ERR

die() { echo "$*" >&2; exit 1; }
((UID==0)) || die "Must be root!"

ipaddr() { ip -4 -o a show dev $1 | awk '{print $4}'; }
macaddr() { cat /sys/class/net/$1/address; }
carrier() { cat /sys/class/net/$1/carrier; }

netstat()
{
    if mac=$(macaddr $1); then
        stat=$(ipaddr $1)
        [[ $stat ]] && return 0
        (($(carrier $1))) && stat="NO IP" || stat="UNPLUGGED"
        return 1
    fi
    mac="NO DEVICE"
    stat=""
    return 0
}

case "${1:-start}" in
    start)
        beacon=~pi/pionic/beacon/beacon; [ -x $beacon ] || die "Need executable $beacon"
        cgiserver=~pi/pionic/cgiserver; [ -x $cgiserver ] || die "Need executable $cgiserver"

        # DUT is attached to eth1 via usb ethernet dongle
        for t in {1..20}; do
            if ip l set eth1 up; then
                # gets a static IP
                ip a a dev eth1 172.31.255.1/24
                sleep 1

                # Start the beacon server on eth1, the payload contains the factory
                # server address and port.
                $beacon send eth1 $factory_server &

                # Start cgi server, bind to eth1
                #$cgiserver -b 172.31.255.1 -p 80 -d cgi &
                $cgiserver -p 80 -d ~pi/pionic/cgi &
                break
            fi
            sleep 1
        done

        # Factory is attached to eth0, wait for an address via dhcp
        for t in {1..20}; do
            if [[ $(ipaddr eth0) ]]; then

                # NAT the DUT to the factory
                echo 1 > /proc/sys/net/ipv4/ip_forward
                iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
                #sudo iptables -A FORWARD -i eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT

                # Forward port 2222 from the factory to DUT's ssh
                iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 2222 -j DNAT --to 172.31.255.2:22
                # iptables -A FORWARD -i eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT

                break
            fi
            echo "Waiting for eth1..."
            sleep 1
        done

        $0 show
        ;;

    stop)
        pkill -f beacon || true
        pkill -f cgiserver || true
        ip a flush eth1 || true
        ip l set eth1 down || true
        echo 0 > /proc/sys/net/ipv4/ip_forward
        iptables -F; iptables -X; iptables -t nat -F
        cat /dev/zero > /dev/fb0 2>/dev/null || true
        ;;

    res*)
        $0 stop
        $0 start
        ;;

    show)
        # We'll use the console for test output
	setterm --cursor off > /dev/tty1
        echo 0 > /sys/class/vtconsole/vtcon1/bind
	dmesg -n 1

        ok=1
        netstat eth0 || ok=0
        mac0=$mac stat0=$stat
        netstat eth1 || ok=0
        mac1=$mac stat1=$stat
        pgrep -f cgiserver &>/dev/null && cup=1 || { cup=0; ok=0; }
        pgrep -f beacon &>/dev/null && bup=1 || { bup=0; ok=0; }

        {
            ((ok)) && echo Test station started OK || echo TEST STATION DID NOT START
            echo
            echo "ETH0  : $mac0"
            [[ $stat0 ]] && echo "        $stat0"
            echo "ETH1  : $mac1"
            [[ $stat1 ]] && echo "        $stat1"
            ((cup)) && echo CGISRV: OK || echo CGISRV: NOT RUNNING
            ((bup)) && echo BEACON: OK || echo BEACON: NOT RUNNING
        } | ~pi/pionic/cgi/display command=text fg=white point=50 $( ((ok)) && echo bg=green || echo bg=red)
        ;;

    *) die "Usage: $0 stop|start|restart"
esac
true

