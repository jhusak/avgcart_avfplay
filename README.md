Hello.

I have managed to fix the original AVFPLAY player for AVGCART in a way that sound plays exactly in the same cycle of the line.

This is crucial, because play audio method used is PWM, so even one-cycle 1.79MHz shift is audible (for purists).

You can drop this player on your SD card and replace the old one.

The active production version is movplay_smoothsound.asm (as declared in Makefile)

Type "make" to build AVFPLAY, then copy the binary to the root of the AVGCART's sd card.

If you want to make one compressed with exomizer (that runs on Atari on 6502 CPU), type "make build".
Then copy the binary to sd card.

Added features:

- OPTION - exits to cart menu
