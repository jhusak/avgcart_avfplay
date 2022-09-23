;
; 4C00-4EFF		Playback display list
; 4F00-4FFF		Error display list
; 5000-5FFF		Framebuffer
;
		icl		'hardware.inc'
		icl		'os.inc'

IDE_BASE = $d5f0
ide_data = $d5f0
ide_status	equ	IDE_BASE+7

pause_imaddr	equ	$8150
pause_imaddr2	equ	$9000

		org	$0
		opt	o-
zpsndbuf:
	
		org	$c0
zp_start:
log_curx	dta		0
log_curln	dta		a(0)
log_srcptr	dta		a(0)
log_lncnt	dta		0
back_consol	dta		0
pause		dta		0
waitcnt	dta		0
;nextpg	dta		0
delycnt	dta		0
.if (COVOX==0)
volume	dta		0
.endif
sector	dta	0
		dta	0
		dta	0
		dta	0
		
d0		dta		0
d1		dta		0
d2		dta		0
d3		dta		0
d4		dta		0
;d5		dta		0
;d6		dta		0
;d7		dta		0
a0		dta		a(0)
a1		dta		a(0)
a2		dta		a(0)
a3		dta		a(0)
zp_end:

;============================================================================
		org		$2800
		opt		o+

.proc	main
		jsr reset_sound
		.if (COVOX=$D300)
		lda	$D302
		and	#$fb
		sta	$D302
		lda 	#$ff
		sta	$D300
		lda	$D302
		ora	#$4
		sta	$D302
		.endif
		sei

		;clear PIA interrupts
		mva		#$3c pactl
		;lda		porta
		;lda		portb

		;zero working variables

		ldx		#0
		lda		#0
clear_zp:
		sta		zp_start,x
		dex
		bne		clear_zp

		;nuke startup bytes to force cold reset
		sta		pupbt1
		sta		pupbt2
		sta		pupbt3


		mva 	#$e0	$e0
		;set up audio
		; timer 1: 16-bit linked, audio enabled
		; timer 2: 16-bit linked, audio disabled
		lda		#$a0
		sta		audc1
		sta		audc2
		sta		audc3
		sta		audc4
		mva		#$ff audf2
		mva		#$71 audctl
		mva		#$03 skctl

		;initialize text display
		jsr		FlipToTextDisplay
		
		;set up NTSC/PAL differences
		lda		#$08
		bit		pal
		bne		is_ntsc
		; PAL VARIABLES SECTION
		mva 		#{bit.b 0 } ntsc_eat_cycle
		mva		#$40 prior_byte_1
		mva		#$c7 prior_byte_2
		mva		#<(-67) wait_loop_count
		mva		#<(soundbuf-$100+68) wait_loop_offset
		
		jmp		is_pal
		; NTSC VARIABLES SECTION
is_ntsc:
		mva		#$c0 prior_byte_1
		mva		#$47 prior_byte_2
		mva		#<(-17) wait_loop_count
		mva		#<(soundbuf-$100+18) wait_loop_offset

is_pal:

		ldx		#$01
		stx		$d510
		; needed because sometimes background is not black.
		mva		#$00 colbk
		
		dex
		ldy		#$20
@
		lda		$d5f0
		dex
		bne		@-
		dey
		bne		@-
		
		mva		#$00 colbk

;		mva	#0 irqen
;		mva	#$40 irqen
;		bit:rvs	irqst
		
		jsr		FlipToVideoDisplay
		
		;set up for reading
		lda		#248/2
		cmp:req	vcount
		cmp:rne	vcount
		
		mwa		#dlist_wait dlistl
		mva		#$22 dmactl
		
		mva		#>ide_base chbase
		sta		nmires

		sta		wsync
		jmp		main_loop_start
	
main_loop_delay:
		mva		#0 dmactl
		sta		audc1
		
		lda		#124
		cmp:rne	vcount
		mwa		#dlist dlistl
		
		mva		#$22 dmactl
err:
main_loop:

		;MAIN KERNEL
		;
		;With normal width lines (40 bytes), we need some pad bytes to ensure that
		;sector boundaries are maintained.
		
		;DLI should be on by now; if not, wait for it.
		lda:rpl	nmist
		sta		nmires
		
:7		nop
		.if (COVOX==0)
		lda	volume
		sta	audc1
		bne	chk_pause

		lda	init_volume:#$af
		sta	volume
		.endif
chk_pause
		lda	pause
		beq	nopause
		; IDE Ready to read frame, so read by hand
		; and display paused frame from memory
		jsr	FlipToPauseDisplay
nopause
		lda $d209
		cmp #28
		sne
		jmp exit

		ldx		#$c0			;2 (changed to $47 for PAL)
prior_byte_1 = * - 1
		lda		#$47			;2 (changed to $c0 for PAL)
prior_byte_2 = * - 1
		
		;pha:pla
		
		sta		wsync
		bit		$00
		
		
;          1         2         3         4         5         6         7         8         9         0         1   
;012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123
;===========================================================================================================....... -> 7+16 = 23 cycles
;.D..............F.FCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCRVV.V... -> 7+16 = 23 cycles
;.D..............F.FCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCRVV.V... -> 7+25 = 32 cycles
;.D................F.FCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCRC..............


.rept 192
		;jump to right before even line (start vscrol region - vscrol=7)
		;jump to right before odd line (end vscrol region - vscrol=0)
		;24 cycles
		
.if (#%2)==0
		sta		prior			;106, 107, 108, 109
		sta		vscrol			;110, 111, 112, 113
		sta		chactl			;0, 2, 3, 4
.else	
		stx		prior			;4
		stx		vscrol			;4
		stx		chactl			;4
.endif
		
.if [(#%3)==2]
		ldy.w		zpsndbuf+#		;5, 6, 7
		PLAY_SAMPLE				;8,9,10,11,12,13,14,15
.if (#!=191)	
		:4 nop
.endif
.else
		ldy		zpsndbuf+#		;5, 6, 7
		PLAY_SAMPLE				;8,9,10,11,12,13,14,15
.endif

.endr
			
		;With 192 scanlines, there are 320 bytes left over. 262 of these are used for
		;sound, and the other 58 we toss. We read 10 bytes a scanline and so this
		;takes 32 scanlines.
				
		ldx		$e0 ; #$e0
		
		;we are coming in hot from the last visible scanline, so we need to skip
		;the wsync
		bne		sndread_loop_start
		
sndread_loop:
		sta		wsync						;4
		bit.w		$00
sndread_loop_start:
		ldy		ide_data					;4
		lda		ide_data
		sta		zpsndbuf+$20,x		;9
		lda		ide_data					;4
		PLAY_SAMPLE				;8,9,10,11,12,13,14,15
		sta		zpsndbuf+$40,x				;4
		mva		ide_data zpsndbuf+$60,x		;9
		mva		ide_data zpsndbuf+$80,x		;9
		mva		ide_data zpsndbuf+$a0,x		;9
		mva		ide_data zpsndbuf+$c0,x		;9
		mva		ide_data soundbuf-$e0,x		;9
		mva		ide_data soundbuf-$c0,x		;9
		lda		ide_data					;4

		inx									;2
		bne		sndread_loop				;3
		
		sta		wsync
		ldy		ide_data
		mva		ide_data soundbuf+$40
		lda		ide_data
		bit.w		$00
		PLAY_SAMPLE				;8,9,10,11,12,13,14,15
		:7 lda	ide_data		;28
		mwa		#dlist dlistl

		ldx		#<(-18)
eat_loop:
		sta		wsync ; here one cycle too many in NTSC.
		ldy		ide_data
		mva		ide_data soundbuf+$40-<(-19),x
		cpx		#$fb
ntsc_eat_cycle = *
		bne		*+2
		nop
		PLAY_SAMPLE				;8,9,10,11,12,13,14,15
		:8 lda	ide_data		;28
		inx
		bne		eat_loop
		
		.if (COVOX==0)
		; here update, because time room
		lda volume
		sta init_volume
		.endif
		;Do a line of audio, so we get some time again.
		sta		wsync
		ldy		ide_data
		lda		ide_data
		pha:pla
		bit		$00
		nop
		PLAY_SAMPLE				;8,9,10,11,12,13,14,15
		
main_loop_start:				
; cca 41
;:17		nop
		lda		$d510 ;4
		beq		@+ ;3
exit
		.if (COVOX=$D300)
		lda	$D302
		and	#$fb
		sta	$D302
		lda 	#$00
		sta	$D300
		lda	$D302
		ora	#$4
		sta	$D302
		.endif
		lda		#$01
		sta		$d511
		sta		wsync
		sta		wsync
		lda		#$00
		sta		$d511
		jmp		$e477
@
		
		;We have 47 scanlines to wait (~4ms), so in the meantime let's play
		;some audio.
		sta		wsync
		ldy		soundbuf

		bit		$0100
		bit		$0100
		nop
		
		; logic:
		; start - toggle pause
		; select (playing) - volume down
		; option (playing) - volume up
		; select (paused) - one frame-
		; option (paused) - one frame+
		lda		consol
		cmp		#$6 ; bare start key

		PLAY_SAMPLE		; 8

		bne		no_switch
		cmp		back_consol
		beq		no_switch
		sta		back_consol
		lda		pause
		eor		#$ff
		sta		pause
		jmp no_consol

no_switch:
		sta		back_consol
		cmp		#$5	; select
		bne		no_select				;2
		.if (COVOX==0)
		; tricky dec if greater then a0
		lda		#$a0
		cmp		volume
		bcs		no_consol
		dec		volume
		bne		no_consol
		.endif
no_select:	cmp		#$3 ; option
		bne		no_consol
		.if (COVOX==0)
		lda		#$ae
		cmp		volume
		bcc		no_consol
		inc		volume
		;bne		no_consol
		.endif

no_consol:
		ldx		#<(-17)			;modified to -67 for PAL
wait_loop_count = *-1

wait_loop:
		ldy		soundbuf-$100+18,x
wait_loop_offset = *-2
		sta		wsync

		cpx		#$e8	;2
		bne		*+2 	;3/2 ;skip dl dma
		cpx		#$f0	;2
		bne		*+2 	;3/2 ;skip dl dma
		cpx		#$f8	;2
		bne		*+2 	;3/2 ;skip dl dma
		nop
		bit.b 		0
		
		PLAY_SAMPLE		;8

		lda		consol
		lsr
;		and		#4
;		bne		@+
;		jmp		main_loop_start+5
;@
		inx
		bne		wait_loop
		jmp		main_loop
.endp

; This macro has to be exactly 8 cycles long
.if (COVOX == 0)
PLAY_SAMPLE	.macro
		; pokey PWM play
		sty		audf1
		sty		stimer
.endm
.elseif (COVOX==$D300)
PLAY_SAMPLE	.macro
		; COVOX PCM play
		sty	COVOX
		sty 	COVOX
.endm

.else
PLAY_SAMPLE	.macro
		; COVOX PCM play
		sty	COVOX
		sty 	COVOX+2
.endm
.fi

reset_sound
		lda #3
		ldx #$0f
again
		sta	audf1,x
		sta	audf1+$10,x
		sta	audf1+$20,x
		sta	audf1+$30,x
		lda #0
		dex
		bpl again
		rts

;============================================================================
.proc FlipToVideoDisplay

		;shut off all interrupts and kill display
		mva		#0 nmien
		mva		#0 dmactl
		sta		nmires

		;move sprites out of the way
		ldx		#7
		lda		#0
sprclear:
		sta		hposp0,x
		dex
		bpl		sprclear

		;clear playfield page
		lda		#[(ide_data&$3ff)/8]
		ldx		#>framebuf
		ldy		#0
clear_loop:
		stx		clear_loop_2+2
clear_loop_2:
		sta		framebuf,y
		iny
		bne		clear_loop_2
		inx
		cpx		#(>framebuf)+$10
		bne		clear_loop
		
		;prime memory scan counter to $4000
		lda		#124
		cmp:rne	vcount
		
		mwx		#dlist_init dlistl
		mva		#$20 dmactl

		sta		wsync
		sta		wsync
		cmp:rne	vcount

		mva		#12 hscrol
		mva		#7 vscrol
		;mva		#$af audc1
		rts
.endp

;============================================================================
.proc FlipToPauseDisplay
		;shut off all interrupts and kill display
		mva             #0 nmien
		mva             #0 dmactl
		sta             nmires

		mva 		#$a0	audc1
		mva		#64	lcnt
		mwa		#pause_imaddr	a3
		ldy		#0
line_next
		:1 lda ide_data	; eat sound
		ldx		#40
@		mva		ide_data (a3),y+ ; transfer line
		dex
		bne @-

		:4 lda ide_data	; eat sound
		ldx		#40
@		mva		ide_data (a3),y+ ; transfer line
		dex
		bne @-

		:3 lda ide_data	; eat sound
		ldx		#40
@		mva		ide_data (a3),y+ ; transfer line
		dex
		bne @-
		tya
		clc
		adc	a3
		sta	a3
		scc:inc a3+1
		ldy	#0

		dec lcnt
		bne	line_next

		ldy		#248/2 ; wait for screen for be displayed
		cpy:rne	vcount

		mwa		#dlist_paused dlistl
		mva		#$22 dmactl
		lda		#$08
		bit		pal
		bne		is_ntsc
		
		ldx		#$40
		lda		#$c0
		
		jmp		is_pal
is_ntsc:
		ldx		#$c0
		lda		#$40
is_pal:

pause_loop
		ldy:rpl	nmist	; wait for sync line (dliint set in line)
		sty		nmires
		ldy		#96

pause_engine
		sta 		wsync
		sta		prior			;106, 107, 108, 109
		sta 		wsync
		stx		prior			;4
		dey
		bne	pause_engine

; keyboard and consol handling
		; INC_RTC
		bit		irqst
		bvs		chk_consol
		ldy 		$d209
		cpy		#28 ; ESC
		bne		chk_consol
		jmp		main.exit
chk_consol
		ldy		consol
		cpy		#$6 ; bare start key
		bne		no_switch ; 
		cpy		back_consol
		beq		no_switch
		sty		back_consol
		ldy		#0
		sty		pause
		jmp no_consol

no_switch:
		sty		back_consol

		jmp		pause_loop

no_consol:
		jsr FlipToVideoDisplay
		mva		#$22 dmactl

		rts
lcnt	dta 0
.endp

;============================================================================
.proc FlipToTextDisplay
		;kill audio and VBI
		sei
		lda		#0
		sta		nmien
		
		mva		#$a0 audc1
		;kill VBI
		mva		#0 nmien
		;turn ROM back on
		mva		#$ff portb
		
		; wait for the display to be finished
		lda		#248/2
		cmp:rne	vcount
		
		;reset display list
		mwa		#dlist_text dlistl
		lda		#0
		sta		prior
		sta		colbk
		mva		#$22 dmactl
		mva		#$e0 chbase
		rts
.endp
;============================================================================
		org		$4b00
soundbuf:

;============================================================================
		org		$4c00
dlist:
		dta		$70
		dta		$70
		dta		$f0

.rept 32
		dta		$32,$12,$22
		dta		$12,$32,$02
.endr

dlist_wait:
		dta		$41,a(dlist)
		
dlist_init:
		dta		$4f,a(framebuf)
		dta		$41,a(dlist_init)
		
;============================================================================
		org		$4d00
dlist_paused:
		dta		$70
		dta		$70
		dta		$f0

		dta	$4F, a(pause_imaddr)
		:93 dta $0f
		dta	$4F, a(pause_imaddr2)
		:97 dta $0f
		dta		$41,a(dlist_paused)

;============================================================================
		org		$4f00
dlist_text:
		dta		$70
		dta		$70
		dta		$70
		dta		$42,a(framebuf)
		:23 dta	$02
		dta		$41,a(dlist_text)
		
		org		$5000
framebuf:

		run	main

	end
