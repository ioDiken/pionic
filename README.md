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

    Download the SDcard image:
    
        http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2018-11-15/2018-11-13-raspbian-stretch-lite.zip,

    Unzip and extract file 2018-11-13-raspbin-stretch-lite.img which is about
    1.8GB. 

    Install the .img file to an 8GB SDcard using dd on linux or Win32DiskImager
    on Windows.

    Insert the card into the Pi, attach monitor and usb keyboard. It should
    boot to a text console (if it boots to X, you have the wrong image). Log in
    as user 'pi', password 'raspberry'

    sudo raspi-config:

        Change User Password:

            Set user 'pi' password as desired

        Interfacing Options:

            SSH: Yes
            VNC: No
            I2C: Yes
            Serial: Yes

        Advanced Options:

            Memory split: 0

    Attach ethernet, wait for IP to come up.
    
        sudo apt update
        sudo apt upgrade
        sudo apt install git
        git clone https://github.com/glitchub/pionic
        make -C pionic

    Make sure ethernet dongle is attached to USB, then reboot.
    
    Note Pionic takes over the display, will show green status screen if started successfully, or red
    screen if not. Subsequent login must occur via SSH or serial terminal.
