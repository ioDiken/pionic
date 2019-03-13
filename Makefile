# install/build various repos needed by pionic 

ifeq (${USER},root)
default:; @echo Must not be root!; false
else

# note must escape the colon
repos=https\://github.com/glitchub/beacon
repos+=https\://github.com/glitchub/runfor
repos+=https\://github.com/glitchub/fbput
repos+=https\://github.com/glitchub/FM_Transmitter_RPi3

packages=sox graphicsmagick

default: ${repos} ${packages} .gitignore
	sudo sed -i "/pionic/d; /^exit/i /home/pi/pionic/pionic.sh start" /etc/rc.local

.PHONY: ${repos}
${repos}:
	[ -d "$(notdir $@)" ] || git clone $@
	make -C $(notdir $@)

.PHONY: ${packages}
${packages}:
	sudo apt install $@

.PHONY: .gitignore
.gitignore:
	echo $@ > $@    
	$(foreach r,$(notdir ${repos}),echo $r >> $@;)

clean:
	sudo ./pionic.sh stop
	sudo sed -i "/pionic/d" /etc/rc.local
	rm -rf $(notdir ${repos})

endif
