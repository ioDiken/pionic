#!/bin/bash
# This runs at boot, start test station operation
# It can also be run manually to restart all services

set -ue; trap 'echo $0: line $LINENO: exit status $? >&2' ERR

die() { echo "$*" >&2; exit 1; }

grep -q Raspberry /etc/rpi-issue || die "Can only be run on Raspberry PI"
((UID==0)) || die "Must be run as root"

here=${0%/*}

lookup() { awk 'BEGIN{X=1} {gsub(/[ \t]+/,"");if($1=="'$1'"){print $2; X=0; exit}} END{exit X}' FS== $here/pionic.cfg; }

# return ip address for interface $1 or "" 
ipaddr() { ip -4 -o a show dev $1 | awk '{print $4}'; }

# return true if interface $1 is up and has ip address, false if not, sets $stat1 and $stat2
isup()
{
    if stat1=$(cat /sys/class/net/$1/address); then
        stat2=$(ipaddr $1)
        ! [[ $stat2 ]] || return 0
        (($(cat /sys/class/net/$1/carrier))) && stat2="NO IP" || stat2="UNPLUGGED"
        return 1
    fi
    stat1="NO DEVICE"
    stat2=""
    return 0
}

case "${1:-start}" in
    start)
        # extract interesting configuration from pionic.cfg
        for key in use_beacon factory_ip pionic_ip dut_ip bind_cgi; do
            val=$(lookup $key) || die "Must define '$key' in pionic.cfg"
            declare $key=$val
        done    
        
        sysctl net.ipv6.conf.all.disable_ipv6=1
        sysctl sys.net.ipv4.ip_forward=1

        # eth1 attaches to dut via usb ethernet dongle
        # bring it up and assign static IP
        SECONDS=0
        echo "Waiting for eth1 to come up"
        while true; do
            if ip l set dev eth1 up 2>/dev/null; then
                ip a add dev eth1 $pionic_ip
                sleep 1

                # Maybe start the beacon server on eth1, the payload contains the factory server address
                if ((use_beacon)); then
                    $here/beacon/beacon send eth1 $factory_ip &
                    disown
                fi    

                # Start cgi server, maybe bind to eth1
                ((bind_cgi)) && bind="-b ${pionic_ip%/*}" || bind=""
                $here/cgiserver $bind -p 80 -d ~pi/pionic/cgi &
                disown

                break
            fi
            ((SECONDS < 10)) || break
            sleep .5
        done

        # eth0 attaches to the factory 
        # wait for it to get an address from dhcp
        echo "Waiting for eth0 to come up"
        while true; do
            if [[ $(ipaddr eth0) ]]; then
                # NAT the DUT to the factory
                iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

                # Forward port 2222 from the factory to DUT's ssh
                iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 2222 -j DNAT --to $dut_ip:22

                break
            fi
            ((SECONDS < 10)) || break
            sleep .5
        done

        $0 show
        ;;

    stop)
        pkill -f beacon || true
        pkill -f cgiserver || true
        ip a flush eth1 || true
        ip l set eth1 down || true
        iptables -F; iptables -X; iptables -t nat -F
        cat /dev/zero > /dev/fb0 2>/dev/null || true
        ;;

    res*)
        $0 stop
        $0 start
        ;;

    show)
        # disable console output
	setterm --cursor off > /dev/tty1
        echo 0 > /sys/class/vtconsole/vtcon1/bind
	dmesg -n 1

        ok=1
        isup eth0 || ok=0; eth0_stat1=$stat1; eth0_stat2=$stat2
        isup eth1 || ok=0; eth1_stat1=$stat1; eth1_stat2=$stat2
        pgrep -f cgiserver &>/dev/null && cup=1 || { cup=0; ok=0; }
        use_beacon=$(lookup use_beacon)
        ((use_beacon)) && { pgrep -f beacon &>/dev/null && bup=1 || { bup=0; ok=0; }; }

        {
            ((ok)) && echo Test station started OK || echo TEST STATION DID NOT START
            echo
            echo "ETH0  : $eth0_stat1"
            ! [[ $eth0_stat2 ]] || echo "        $eth0_stat2"
            echo "ETH1  : $eth1_stat1"
            ! [[ $eth1_stat2 ]] || echo "        $eth1_stat2"
            ((cup)) && echo CGISRV: OK || echo CGISRV: NOT RUNNING
            ((use_beacon)) && { ((bup)) && echo BEACON: OK || echo BEACON: NOT RUNNING; }
        } | ~pi/pionic/cgi/display text fg=white point=40 $( ((ok)) && echo bg=green || echo bg=red)
        ;;

    *) die "Usage: $0 stop|start|restart"
esac
true

