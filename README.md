Hello.

I have managed to fix the original AVFPLAY player for AVGCART in a way that sound plays exactly in the same cycle of the line.

This is crucial, because play audio method used is PWM, so even one-cycle 1.79MHz shift is audible (for purists).

You can drop this player on your SD card and replace the old one.

If you want to make one compressed with exomizer, you should install it and type "make build".

Added features:

- OPTION - exits to cart menu

- Desync-check and resync if desynced.
