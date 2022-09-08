.SUFFIXES: .s
.SUFFIXES: .xex
c:
	mads movplay_smoothsound.asm -o:AVFPLAY

%.xex: %.s
	mads -l $< -o:$@

build: c
	exomizer sfx 0x2800 -C -n -t 168 AVFPLAY -o AVFPLAY
	# exomizer sfx sys -Di_load_addr=0xc00 -Datari_init=1 ai.xex -t 168 -n -o aic.xex

cp: build
	while ! [ -d /Volumes/UNTITLED -o -d /Volumes/AVGCART ] ; do sleep 1 ; done
	sleep 1
	[ -d /Volumes/UNTITLED ] &&  cp AVFPLAY /Volumes/UNTITLED/AVFPLAY && echo "Wait for the card to eject..." &&  diskutil eject /Volumes/UNTITLED || true
	[ -d /Volumes/AVGCART ] &&  cp AVFPLAY /Volumes/AVGCART/AVFPLAY && echo "Wait for the card to eject..." &&  diskutil eject /Volumes/AVGCART || true
cpb: 
	while ! [ -d /Volumes/UNTITLED -o -d /Volumes/AVGCART ] ; do sleep 1 ; done
	sleep 1
	[ -d /Volumes/UNTITLED ] &&  cp AVFPLAY /Volumes/UNTITLED/AVFPLAY && echo "Wait for the card to eject..." && diskutil eject /Volumes/UNTITLED || true
	[ -d /Volumes/AVGCART ] &&  cp AVFPLAY /Volumes/AVGCART/AVFPLAY && echo "Wait for the card to eject..." &&  diskutil eject /Volumes/AVGCART || true

