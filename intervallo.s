; Intervallo - a slideshow with beauties from Italy

	Section	rc,CODE_F
  ; Place addr in d0 and the copperlist pointer addr in a1 before calling
POINTINCOPPERLIST MACRO
  move.w              d0,6(a1)
  swap                d0
  move.w              d0,2(a1)
  ENDM

AUDIO_CHUNK EQU 512

SWAP_BPL MACRO
    neg.l SCREEN_OFFSET
    move.l SCREEN_OFFSET,d1
    move.l SCREEN_PTR_0,SCREEN_PTR_OTHER_0
    move.l SCREEN_PTR_1,SCREEN_PTR_OTHER_1
    add.l d1,SCREEN_PTR_0
    add.l d1,SCREEN_PTR_1
    ENDM

AUDIO_VOL EQU $0040

	movec ccc,d3
	load d3,e20

	jsr PIXELINTERPOLATION ; 5.431785
	movec ccc,d3
	load d3,e21

	load e20,d3
	load e21,d4

	sub.l d3,d4
	bpl noinvert
	neg.l d4
noinvert:


	;include	"daworkbench.s"	; togliere il ; prima di salvare con "WO"

*****************************************************************************
	include	"startup2.s"	; con questo include mi risparmio di
				; riscriverla ogni volta!
*****************************************************************************

DMASET EQU %1000011111100001 ;Master,Copper,Blitter,Bitplanes;Sprites
WaitDisk	EQU	30
	include "AProcessing/libs/precalc/rgbto0r0b0g.s"
	include "AProcessing/libs/precalc/rgbtoregs.s"
	include "AProcessing/libs/rasterizers/globaloptions.s"
	include "AProcessing/libs/vampfpu/copfade.s"
	include "AProcessing/libs/vampfpu/coldistance.s"

START:

	; Setup first image
	;jsr 				LOAD_IMAGE

	; COLORS OF THE FIRST CHUNKY_IMAGE
	;MEMCPY16 			COLOSSEO_2020_COLORS,COLORS,32*4/16

	MEMCPY16 			AnalogString,CHIPAUDIODATA,AUDIO_CHUNK/16
	move.l 				a0,AudioWorkPtr

	LEA     			CHIPAUDIODATA,a1 ;Address of data to
                                ;  audio location register 0
    MOVE.L  			a1,$DFF0A0  ;The 680x0 writes this as though it were a
                                ;  32-bit register at the low-bits location
                                ;  (common to all locations and pointer
                                ;  registers in the system).
    MOVE.W  			#AUDIO_CHUNK/2,$DFF0A4  ;Set length in words

SETAUD0VOLUME:
    MOVE.W  			#64,$DFF0A8 ;Use maximum volume

SETAUD0PERIOD:
    MOVE.W  			#162,$DFF0A6 ; 3579546/22050

	;moveC				VBR,A0
	move.l 			BaseVBR,a0
	move.l				#AudioHandler,$70(A0)	; Set Level 4 (audio) Vector.

	move.l              #TRACK_DATA_1,d0
  	lea                 BPLPTR1,A1
  	bsr.w               POINTINCOPPERLIST_FUNCT

  	move.l              #TRACK_DATA_2,d0
  	lea                 BPLPTR2,A1
  	bsr.w               POINTINCOPPERLIST_FUNCT

  	move.l              #TRACK_DATA_3,d0
  	lea                 BPLPTR3,A1
  	bsr.w               POINTINCOPPERLIST_FUNCT

	move.l              #TRACK_DATA_4,d0
  	lea                 BPLPTR4,A1
  	bsr.w               POINTINCOPPERLIST_FUNCT

	move.l              #TRACK_DATA_5,d0
  	lea                 BPLPTR5,A1
  	bsr.w               POINTINCOPPERLIST_FUNCT


	lea $dff000,a5
    MOVE.W				#DMASET,$96(a5)		; DMACON - enable bitplane, copper, sprites and audio (optional).

	; copperlist setup
	move.l				#COPPERLIST,$80(a5)	; Copperlist point
	move.w				d0,$88(a5)			; Copperlist start
	move.w				#0,$1fc(a5)			; AGA disable
	move.w				#$c00,$106(a5)		; AGA disable
	move.w				#$11,$10c(a5)		; AGA disable

	move.w 				#$C080,$dff09a ; intena, enable interrupt lvl 2

	; Start of gameloop
mouse:
    cmpi.b  			#$ff,$dff006    ; Linea 255?
    bne.s   			mouse

	;move.w #$F00,$dff180

    jsr CHUNKYTOPLANAR

	;move.w				#$000,$dff180

Aspetta:
	;move.w				#$000,$dff180
    cmpi.b  			#$ff,$dff006    ; linea 255?
    beq.s   			Aspetta

	btst				#10,$dff016	; rmb pressed?
	bne.s				nochangeimage
	jsr					LOAD_NEXT_IMAGE

nochangeimage:

    btst				#6,$bfe001	; fire pressed?
	beq.w				exit

	bra.w 				mouse
exit:

	rts			; esci

	IFD DEBUG
    include "debug.s"
    ENDC

IMAGE_PHASE: dc.w 0
IMAGE_TRANSITION_MAX_PHASES equ 10

LOAD_IMAGE:
	move.l 				currentImage,a0 				; get image address
	MEMCPY16			a0,CHUNKY_IMAGE,81920/16 		; copy image to chunky area
	MEMCPY16			a0,COLORS,32*4/16 				; copy copperlist color section
	rts

LOAD_NEXT_IMAGE:
	cmpi.w				#IMAGE_TRANSITION_MAX_PHASES+1,IMAGE_PHASE
	beq.w 				noresetimage
	jsr					GET_IMAGES_ADDR ; after this a0 = current image and a1 next

	; go to color copperlist
	adda.l				#81920,a0
	adda.l				#81920,a1

	lea					COLORS+2,a3

	; cycle for each color
	moveq				#32-1,d7
nextimagecolorloop:

	move.l 				(a0)+,d0 ; start color taken from old image (full copperlist)
  	move.l 				(a1)+,d1 ; end color taken from new image (full copperlist)

	; clean upper part
	andi.l 				#$0FFF,d0
	andi.l 				#$0FFF,d1

  	fmove 				#IMAGE_TRANSITION_MAX_PHASES,fp1 ; load total amount of phases
	;fmove #1,fp2

  	move.w 				IMAGE_PHASE,d3
	ext.l				d3
	fmove.w 				d3,fp2 ; load current phase
	movem.l 			d7,-(sp)
  	jsr 				COPFADEFPU
	movem.l 			(sp)+,d7
	;move.w #$211,d0
	
	;	cmp.w #$211,d0
	;;	beq ok;
	;;	move.w #$FFF,d0
	;	bra.s scrivi
;ok
;	move.w #$0F0,d0
;scrivi

	move.w				d0,(a3) ; write color into copperlist
	addq				#4,a3

	dbra				d7,nextimagecolorloop

	jsr					PIXELINTERPOLATION


	; now increment PHASE
	add.w				#1,IMAGE_PHASE
	;rts ; remove this to resore from test
	IFD LOL
	jsr					GET_IMAGES_ADDR
	move.l 				a1,a0
	MEMCPY16			a0,CHUNKY_IMAGE,81920/16 		; copy image to chunky area
	ENDC
	;MEMCPY16			a1,COLORS,32*4/16 				; copy copperlist color section

	;move.l				a0,currentImage 				; now a0 points to the next image
	;cmpa.l 				#IMAGES_END,a0
	;bne.s 				noresetimage
	;move.l 				#IMAGES,currentImage
noresetimage:
	rts

; this function returns into a0 the current image addr and into a1 the next one
GET_IMAGES_ADDR:
	move.l 				currentImage,a0 				; get image address
	move.l				a0,a1
	adda.l				#81920+32*4,a1
	cmpa.l 				#IMAGES_END,a1
	bne.s 				noresetimageaddr
	lea					IMAGES,a1
noresetimageaddr:
	rts

CHUNKYTOPLANAR:
	LOAD #0,E23

	lea CHUNKY_IMAGE,a0
    lea TRACK_DATA_1,a1
	lea TRACK_DATA_2,a2
	lea TRACK_DATA_3,a3
	lea TRACK_DATA_4,a4
	lea TRACK_DATA_5,a5

	move.w #(320*256/64)-1,d7
c2ploop:
	load d7,e10

    C2P                   (a0)+,E0 ; take a chunk of 8 bytes into E0
	C2P                   (a0)+,E1 ; take a chunk of 8 bytes into E1
	C2P                   (a0)+,E2 ; take a chunk of 8 bytes into E2
	C2P                   (a0)+,E3 ; take a chunk of 8 bytes into E3

	; 32 pixels are now loaded into data registers in planar format

	TRANSLO               E0-E3,D0:D1 ; merge lower
	TRANSHI               E0-E3,D2:D3 ; merge upper

	C2P                   (a0)+,E0 ; take a chunk of 8 bytes into E10
	C2P                   (a0)+,E1 ; take a chunk of 8 bytes into E11
	C2P                   (a0)+,E2 ; take a chunk of 8 bytes into E12
	C2P                   (a0)+,E3 ; take a chunk of 8 bytes into E13

	TRANSLO               E0-E3,D4:D5 ; merge lower
	TRANSHI               E0-E3,D6:D7 ; merge upper

	VPERM                 #$13579BDF,d1,d5,e0 ; BPL0
	VPERM                 #$02468ACE,d1,d5,e1 ;BPL1

	VPERM                 #$13579BDF,d0,d4,e2 ;BPL2
	VPERM                 #$02468ACE,d0,d4,e3 ;BPL3

	VPERM                 #$13579BDF,d3,d7,e4 ; BPL5
  

	; store data into actual bitplanes
	store                 e0,(a1)+
	store                 e1,(a2)+
	store                 e2,(a3)+
	store                 e3,(a4)+
	store                 e4,(a5)+

	load 				  e10,d7

	dbra 				  d7,c2ploop
	rts

POINTINCOPPERLIST_FUNCT:
  	POINTINCOPPERLIST
  	rts

PIXELINTERPOLATION:
	move.w #$F00,$dff180

	;movem.l d0-d7/a0-a6,-(sp)
	; ---------------- CODE TO TEST !!!! -----------------------------
	;now remap all chunky data according to the new copperlist - START!!!!!!
	jsr					GET_IMAGES_ADDR ; after this a0 = current image and a1 next
	
	; now we have to figure out the start color (just one pixel for now)
	;move.l				a0,a3
	;move.l				a1,a4
	;adda.l #320*256+2,a3
	;adda.l #320*256+2,a4
	;lea               320*256+2(a0),a3
	lea (320*256+2.l,a0),a3
	lea (320*256+2.l,a1),a4

	;lea               320*256+2(a1),a4
	
	; now i must interpolate to find the new color
	move.w 				IMAGE_PHASE,d3
	ext.l				d3
	fmove.w 			d3,fp2 ; load current phase
	;fmove.w #IMAGE_TRANSITION_MAX_PHASES/2,fp2; da rimuovere
	fmove.w 				#IMAGE_TRANSITION_MAX_PHASES,fp1 ; load total amount of phases
	
	lea CHUNKY_IMAGE,a5
	; recap, at this point i have
	; a0 - pointer to old image
	; a1 - pointer t new image
	; a3 - pointer to copperlist colors
		move.l 				#320*256-1,d7
chunkyremaploop: ; for each pixel
	movem.l 			d7,-(sp) ; preserve counter
	
	move.b (a0)+,d0
	lsl.b #2,d0
	ext.w d0
	move.w 0(a3,d0.w),d0 ; Now d0 holds the source color

	move.b (a1)+,d1
	lsl.b #2,d1
	ext.w d1
	move.w 0(a4,d1.w),d1 ; Now d1 holds the destination color

	
  	jsr 				COPFADEFPU

	; d0 now holds the color i am looking for
	; find the index of the new color
	movem.l d1-d7/a0-a1,-(sp)
	load d0,e0
	moveq #32-1,d7
	fmove #455,fp6
	lea COLORS,a0
vampire_fpu9_loop:
	move.l (a0)+,d6
	RGBTOREGS d6,d0,d1,d2
	load e0,d6
	RGBTOREGS d6,d3,d4,d5
	jsr COLDIST
	fcmp fp0,fp6
	fmove FPSR,d6
	btst #31-4,d6
	bne.s vampire_fpu9_upd_max
	fmove fp0,fp6
	move.w d7,d6
	swap d7
	move.w d6,d7
	swap d7
vampire_fpu9_upd_max:
	dbra d7,vampire_fpu9_loop
	swap d7
	sub.w #32-1,d7
	neg.w d7 ; d7 now has the new index
	
	move.b d7,(a5)+
	movem.l (sp)+,d1-d7/a0-a1
	movem.l 			(sp)+,d7
	dbra.l d7,chunkyremaploop
	;movem.l (sp)+,d0-d7/a0-a6
	rts
	; ---------------- CODE TO TEST !!!! -----------------------------

; Autovector - this routine is triggered every time a sample has been played
AudioHandler:
	movem.l 			  a0/a1/d7,-(sp)
	move.w				  #$0080,$DFF09C	; Clear INTREQ for Audio 0.
	move.l 				  AudioWorkPtr,a0
	LEA     			  CHIPAUDIODATA,a1 ;Address of data to
	MEMCPY16 			  a0,CHIPAUDIODATA,AUDIO_CHUNK/16
	move.l 				  a0,AudioWorkPtr
	cmp.l 				  #AnalogStringend,a0
	bls.s 				  noresetsample
	move.l 				  #AudioHandler,AudioWorkPtr
noresetsample:
	movem.l (sp)+,a0/a1/d7
	rte

; Music 8bit signed file
AnalogString: 			  incbin "test.raw"
AnalogStringend:

CHUNKY_IMAGE:
    ;dcb.b   			  320*256,0
	incbin 				  "images/pennabilli.data" ; 320*256 indexed chunky image here
	include 			  "images/pennabilli.col" ; color copperlist here
AudioStart:				  dc.l 0
AudioWorkPtr:			  dc.l 0
AudioEnd:				  dc.l 0
oldAudioVector:			  dc.l 0
currentImage:			  dc.l IMAGES : pointer to the current image

IMAGES:
PENNABILLI:
						  incbin 				  "images/pennabilli.data" ; 320*256 indexed chunky image here
						  include 			  	  "images/pennabilli.col" ; color copperlist here
ARENA:					  incbin 				  "images/castigliondellago.data" ; arena image
						  include				  "images/castigliondellago.col"

IMAGES_END:

    SECTION GRAPHICS,DATA_C

	;include "AProcessing/libs/rasterizers/processing_bitplanes_fast.s"
	include "copperlist.s"

TRACK_DATA_1:
	;incbin  "assets/tracks/track1/rc045_320X240X32.raw.aa"
	dcb.b   40*240,0
DASHBOARD_DATA_1:
	dcb.b   40*16,0
TRACK_DATA_2:
	;incbin  "assets/tracks/track1/rc045_320X240X32.raw.ab"
	dcb.b   40*240,0
DASHBOARD_DATA_2:
	dcb.b   40*16,0
TRACK_DATA_3:
	;incbin  "assets/tracks/track1/rc045_320X240X32.raw.ac"
	dcb.b   40*240,0
DASHBOARD_DATA_3:
	dcb.b   40*16,0
TRACK_DATA_4:
	;incbin  "assets/tracks/track1/rc045_320X240X32.raw.ad"
	dcb.b   40*240,0
DASHBOARD_DATA_4:
	dcb.b   40*16,0
TRACK_DATA_5:
	;incbin  "assets/tracks/track1/rc045_320X240X32.raw.ae"
	dcb.b   40*240,0
DASHBOARD_DATA_5:
	dcb.b   40*16,0

CHIPAUDIODATA:                       ; Audio data must be in Chip memory
		dcb.b AUDIO_CHUNK,0
	