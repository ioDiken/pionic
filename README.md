Pionic - an RPI-based factory test station controller

Physical configuration:

    USB network adapter attaches to DUT, gets address 172.31.255.1.  The DUT
    will take 172.31.255.2 and set pionic as the gateway. If necessary it can
    also set a static MAC address, since one may not yet have been assigned. 

    The ethernet attaches to factory, expects address assigned by DHCP.
    Especially, the factory server is on the factory interface.

    40-pin connector attaches to optional test hardware.

Pionic provides:

    NAT translation from the DUT to the factory/factory server. Also, ssh to
    port 2222 on the factory interface will be forwarded to DUT port 22.

    Transmit beacon packet every second on the DUT interface, DUT listens for
    this at boot. If detected, it brings up static IP and attempts to download
    diagnostic tarball from the factory server. Note the beacon payload specifies
    the address and port of the factory server, e.g. "10.2.3.4:80".

    Access to test-specific CGI's on port 80, the DUT uses curl e.g.:

        curl -f http://172.31.255.1/gpio?14=1
    
To install:

    Boot from fresh Raspian SDcard image.

    Attach monitor and usb keyboard, log in as user 'pi', password 'raspberry'

    sudo raspi-config:

        Change User Password:

            Set user 'pi' password as desired

        Boot Options

            Desktop/CLI: Console text login 
            Wait for Network at Boot: yes

        Interfacing Options:

            SSH: Yes
            VNC: No
            I2C: Yes
            Serial: Yes

        Advanced Options:

            Memory split: 0

    Append to ~/.bashrc:
        
        alias resize='shopt -s checkwinsize; (IFS="[;"; printf "\e7\e[r\e[999;999H\e[6n\e8"; read -s -t1 -dR x r c && stty rows $r cols $c) <> /dev/tty'
        resize
    
    (This tells bash to size of the terminal window, use 'resize' command as needed when it changes.)
    
    Attach ethernet, wait for IP to come up.
    
    sudo apt update
    sudo apt upgrade
    sudo apt install git
    git clone https://github.com/glitchub/pionic
    make -C pionic

    Edit pionic/pionic.sh to set the factory server address and port, default is
    "10.2.3.4:80" which is almost certainly wrong.

    Make sure ethernet dongle is attached to USB, then reboot. 
    
    SSH to the device's IP address and run 'curl http://localhost/test' to
    check that cgiserver is running (you will see the server's environment).
