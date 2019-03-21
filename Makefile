# install/build various repos needed by pionic 

# git repos to fetch, note we must escape the ":"
repos=https\://github.com/glitchub/beacon
repos+=https\://github.com/glitchub/runfor
repos+=https\://github.com/glitchub/fbput
repos+=https\://github.com/glitchub/FM_Transmitter_RPi3

# apt packages to install
packages=sox graphicsmagick omxplayer 

# system service to disable
disable=avahi-daemon

# Text to append to dhcpcd.conf, wrapped in 'pionic start' and 'pionic end'
define DHCPCD_CONF
# pionic start
  allowinterfaces eth0
  noipv6
  noipv4ll
# pionic end
endef
export DHCPCD_CONF

# Text to append to /boot/config.txt, wrapped in 'pionic start' and 'pionic end'
define CONFIG_TXT
# pionic start
  hdmi_force_hotplug=1
  hdmi_group=1
  hdmi_mode=1
  hdmi_blanking=0
  hdmi_ignore_edid=0x5a000080
  lcd_rotate=2
  disable_touchscreen
# pionic end
endef
export CONFIG_TXT

# files to modify
files=/boot/config.txt /etc/dhcpcd.conf /etc/rc.local

# Make sure we're on RPi and not root
default: $(if $(shell grep Raspberry /etc/rpi-issue),,$(error Can only be run on Raspberry PI))
default: $(if $(filter root,${USER}),$(error Must not be run as root))
default: INSTALLING=yes

default: ${repos} ${packages} ${disable} ${files}
	sync

# /etc/rc.local invokes pionic.sh start
.PHONY: /etc/rc.local
/etc/rc.local:
	sudo sed -i '/pionic/d' $@
	$(if $(INSTALLING),sudo sed -i '/^exit/i/home/pi/pionic/pionic.sh start' $@)

# /boot/config.txt gets a PIONIC configuration block
.PHONY: /boot/config.txt
/boot/config.txt:
	sudo sed -i '/pionic start/,/pionic end/d' $@
	$(if $(INSTALLING),echo "$$CONFIG_TXT" | sudo bash -c 'cat >> $@')

# /etc/dhcpcd,conf gets a pionic configuration block
.PHONY: /etc/dhcpcd.conf
/etc/dhcpcd.conf:
	sudo sed -i '/pionic start/,/pionic end/d' $@
	sudo sed -i '/pionic/Q' $@ # legacy
	$(if $(INSTALLING),echo "$$DHCPCD_CONF" | sudo bash -c 'cat >> $@')

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

clean: ${files} 
	sudo ./pionic.sh stop
	rm -rf $(notdir ${repos})
	sync
