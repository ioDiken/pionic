Pionic - PI-based Networked Instrument Controller

Physical configuration:

    The network interface connects to the factory subnet and receives an
    address via DHCP. The DHCP server is configured to assign a specific IP
    address for the PI's MAC, presumably correlates to the test station ID.

    A USB ethernet dongle attaches to the DUT and gets a static IP (defined in pionic.cfg).

    The 40-pin I/O connector attaches to test instrumentation, which is customqqqqqqqqized for
    the specific test station requires and not in scope of this document.

Pionic provides:

    NAT translation from the DUT to the factory subnet. SSH to port 2222 on the
    factory interface is forwarded to DUT port 22.

    If enabled in pionic.cfg, the beacon server is started on the DUT
    interface, this transmits "beacon ethernet packets. The DUT listens for
    beacons during boot, if detected then it enters factory diagnostic mode and
    brings up pre-defined static IP in the same subnet.

    Alternatively if the DUT will automatically bring up static IP during
    boot, it can simply attempt to access Pionic's CGI server, and if a
    response is received then it enters diagnostic mode.

    Access to test-specific CGI's on port 80, the DUT uses curl e.g.:

        curl -f http://172.31.255.1/gpio?14=1
    
To install:

    Download the SDcard image:
    
        http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2018-11-15/2018-11-13-raspbian-stretch-lite.zip,

    Unzip and extract file 2018-11-13-raspbin-stretch-lite.img (about 1.8GB). 

    Install the .img file to an 8GB SDcard using dd on linux or Win32DiskImager
    on Windows.

    Insert the card into the Pi, attach monitor and usb keyboard. It should
    boot to a text console (if it boots to X, you have the wrong image). Log in
    as user 'pi', password 'raspberry'

    Run 'sudo raspi-config':

        Change User Password:

            Set user 'pi' password as desired

        Interfacing Options:

            SSH: Yes
            VNC: No
            I2C: Yes
            Serial: Yes

        Advanced Options:

            Memory split: 0

    Attach ethernet, wait for IP to come up, then run:
    
        sudo apt update
        sudo apt upgrade
        sudo apt install git
        git clone https://github.com/glitchub/pionic
        make -C pionic

    Make sure ethernet dongle is attached to USB and reboot.
    
    Note Pionic takes over the display, will show green status screen if
    started successfully, or red screen if not. Subsequent login must occur via
    SSH or serial terminal.
