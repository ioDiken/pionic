# install/build various repos needed by pionic

# git repos to fetch and build, note we must escape the ":"
repos=https\://github.com/glitchub/beacon
repos+=https\://github.com/glitchub/runfor
repos+=https\://github.com/glitchub/fbput
repos+=https\://github.com/glitchub/FM_Transmitter_RPi3
repos+=https\://github.com/glitchub/i2cio

# apt packages to install
apt=sox graphicsmagick omxplayer dnsmasq

# apt packages to remove
unwanted=resolvconf avahi-daemon

# files to modify
files=/etc/rc.local /boot/config.txt /etc/dhcpcd.conf /etc/dnsmasq.conf

# Text to append to dhcpcd.conf, contstrain dhcp to eth0
define append_dhcpcd_conf
# pionic start
allowinterfaces eth0
noipv6
noipv4ll
# pionic end
endef
export append_dhcpcd_conf

# Text to append to /boot/config.txt
define append_config_txt
# pionic start
hdmi_force_hotplug=1
hdmi_group=1
hdmi_mode=16 # 1920x1080
hdmi_blanking=0
hdmi_ignore_edid=0x5a000080
lcd_rotate=2
disable_touchscreen
# pionic end
endef
export append_config_txt

# Text to append to /etc/dnsmasq.conf, fail all dns queries
define append_dnsmasq_conf
# pionic start
interface=eth1
no-dhcp-interface=eth1
resolv-file=/dev/null # cause dns queries to fail!
# pionic end
endef
export append_dnsmasq_conf

# Make sure we're on RPi and not root
ifeq ($(shell grep Raspberry /etc/rpi-issue),)
$(error Can only be run on Raspberry PI))
endif

ifneq ($(filter root,${USER}),)
$(error Must NOT be run as root))
endif

# remove pionic stuff from specified file
define pristine
sudo sed -i '/pionic start/,/pionic end/d' $1;\
sudo sed -i '/pionic/Q' $1;
endef

.PHONY: install
install: ${unwanted} ${apt} ${repos} ${files} ${unwanted}
	sudo apt-get -y autoremove
	sync
	@echo "Reboot to start pionic"

# install repos
.PHONY: ${repos}
${repos}:
	[ -d "$(notdir $@)" ] || git clone $@
	make -C $(notdir $@)

# clean repos
clean-repos=$(addprefix CR-,$(notdir ${repos}))
.PHONY: ${unistall-repos}
${clean-repos}:
	rm -rf ${@:CR-%=%}	

# install packages
.PHONY: ${apt}
${apt}:
	sudo apt-get -y install $@

# clean packages
clean-apt=${apt:%=CP-%}
.PHONY: ${clean-apt} ${unwanted}
${clean-apt} ${unwanted}:
	sudo apt-get -y purge ${@:CP-%=%}

# modify files
# /etc/rc.local is a bit different
.PHONY: ${files}
/etc/rc.local:
	sudo sed -i '/pionic/d' $@
	sudo sed -i '/^exit/i/home/pi/pionic/pionic.sh start' $@

# all others get pionic text appended
other-files=$(filter-out /etc/rc.local,${files})
${other-files}:
	$(call pristine,$@)
	echo "$$append_$(subst .,_,$(notdir $@))" | sudo bash -c 'cat >> $@'

# unmodify files
clean-files=${files:%=CF-%}
.PHONY: ${clean-files}

# /etc/rc.local is a bit different
CF-/etc/rc.local:
	sudo sed -i '/pionic/d' ${@:CF-%=%}

${other-files:%=CF-%}:	
	! [ -f ${@:CF-%=%} ] || { $(call pristine,${@:CF-%=%}) }

.PHONY: stop
stop:;sudo ./pionic.sh stop

.PHONY: clean
clean: stop ${clean-files}
	sync

.PHONY: uninstall
uninstall: clean ${clean-apt} ${clean-repos}
	sudo apt-get -y autoremove
	sync

.PHONY: .gitignore
.gitignore:
	echo $@ > $@
	$(foreach r,$(notdir ${repos}),echo $r >> $@;)
