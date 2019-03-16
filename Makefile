# install/build various repos needed by pionic 

# git repos to fetch, note we must escape the ":"
repos=https\://github.com/glitchub/beacon
repos+=https\://github.com/glitchub/runfor
repos+=https\://github.com/glitchub/fbput
repos+=https\://github.com/glitchub/FM_Transmitter_RPi3

# apt packages to install
packages=sox graphicsmagick

# system service to disable
disable=avahi-daemon

# Text to append to dhcpcd.conf
# The first line must contain the string 'pionic'
define DHCPCD
# This is installed by pionic Makefile, do not edit! Changes to dhcpcd.conf must be above this line!
allowinterfaces eth0
noipv6
noipv4ll
endef
export DHCPCD

# Make sure we're on RPi and not root
default: $(if $(shell grep Raspberry /etc/rpi-issue),,$(error Can only be run on Raspberry PI))
default: $(if $(filter root,${USER}),$(error Must not be run as root))

default: ${repos} ${packages} ${disable} .gitignore
	sudo sed -i '/pionic/d; /^exit/i /home/pi/pionic/pionic.sh start' /etc/rc.local
	sudo sed -i '/pionic/Q' /etc/dhcpcd.conf
	echo "$$DHCPCD" | sudo bash -c 'cat >> /etc/dhcpcd.conf'
	sync

.PHONY: ${repos}
${repos}:
	[ -d "$(notdir $@)" ] || git clone $@
	make -C $(notdir $@)

.PHONY: ${packages}
${packages}:
	sudo apt install $@

.PHONY: ${disable}
${disable}:
	sudo systemctl disable $@  

.PHONY: .gitignore
.gitignore:
	echo $@ > $@    
	$(foreach r,$(notdir ${repos}),echo $r >> $@;)

clean:
	sudo ./pionic.sh stop
	sudo sed -i "/pionic/d" /etc/rc.local
	sudo sed -i '/pionic/Q' /etc/dhcpcd.conf
	rm -rf $(notdir ${repos})
	sync
