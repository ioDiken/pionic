# install/build various repos needed by pionic 

ifeq (${USER},root)
default:; @echo Must not be root!; false

else
default: beacon runfor FM_Transmitter_RPi3 fbput
	sudo sed -i "/pionic/d; /^exit/i /home/pi/pionic/pionic.sh start" /etc/rc.local

beacon:
	git clone https://github.com/glitchub/$@
	make -C $@

runfor:
	git clone https://github.com/glitchub/$@
	make -C $@

fbput:
	sudo apt install graphicsmagick
	git clone https://github.com/glitchub/$@
	make -C $@

FM_Transmitter_RPi3:
	sudo apt install sox
	git clone https://github.com/glitchub/$@
	make -C $@
endif

clean:
	sudo ./pionic.sh stop
	rm -rf beacon runfor FM_Transmitter_RPi3 fbput
	sudo sed -i "/pionic/d" /etc/rc.local
