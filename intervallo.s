; Intervallo - a slideshow with beauties from Italy

	Section	rc,CODE_F
  ; Place addr in d0 and the copperlist pointer addr in a1 before calling
POINTINCOPPERLIST MACRO
  move.w              d0,6(a1)
  swap                d0
  move.w              d0,2(a1)
  ENDM

AUDIO_CHUNK EQU 512
CHANGEPICTUREDELAY EQU 19*50
TRANSITION_DELAY EQU 3
IMAGE_TRANSITION_MAX_PHASES equ 25

SWAP_BPL MACRO
    neg.l SCREEN_OFFSET
    move.l SCREEN_OFFSET,d1
    move.l SCREEN_PTR_0,SCREEN_PTR_OTHER_0
    move.l SCREEN_PTR_1,SCREEN_PTR_OTHER_1
    add.l d1,SCREEN_PTR_0
    add.l d1,SCREEN_PTR_1
    ENDM

AUDIO_VOL EQU $0040

	IFD LOL
	;moveq #10,e9
;label:
	;nop
	;dc.w  $714a
	;dbra d1,label ; $74a (=bank) makes d1 into e9

	LEA	$BFE001,A2	; CIAA base -> USATO
	MOVE.B	#0,$800(A2)	; TODLO - bit 7-0 del timer a 50-60hz


	;movec ccc,d0
	;movec iep1,d1
	;movec iep2,d2
	movem.l d0/d1/d2,-(sp)
	move.w #50,IMAGE_PHASE
	jsr LOAD_NEXT_IMAGE ;2.17

	LEA	$BFE001,A2	; CIAA base -> USATO
	move.B	$800(A2),d0

	lea	$bfd000,a5
	sf	$f00(a5)
	move.b	$700(a5),d0
	lsl.w	#8,d0
	move.b	$600(a5),d0
	not.w	d0
alessio:
	movem.l (sp)+,d0/d1/d2
	movec ccc,d3
	movec iep1,d4
	movec iep2,d5

	sub.l d0,d3
	bpl ccclabel
	neg.l d3
ccclabel

	sub.l d1,d4
	bpl iep1label
	neg.l d4
iep1label

	sub.l d2,d5
	bpl iep2label
	neg.l d5
iep2label
	ENDC


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
	include "AProcessing/libs/vampfpu/copfade2.s"
	include "sqrt.s"

START:

	IFD LOL
	; Setup first image
	jsr 				LOAD_IMAGE
	ENDC

	moveC				VBR,A0
	;move.l 				BaseVBR,a0
	move.l  			#VblHandler,$6c(A0)

	;move.l				#AudioHandler,$70(A0)	; Set Level 4 (audio) Vector.


	* On V4 we can use ARNE 32bit Audio DMA to play the Music 
* V4 will play stereo music on chan 0
*
* On V2 we only have Paula and need to copy chunks to chipmem to allow her to play it
* V2 will use channel 0 and 1 to play music
*
	move.b	$DFF3FC,D0		; Vampire version
	move.b	#4,VERSION
	cmp.b	#1,D0
	beq.s	V2
	cmp.b	#2,D0
	beq.s	V2
	cmp.b	#6,D0
	bne.s	ENDDETECTION
V2
	move.b	#2,VERSION
ENDDETECTION

	cmp.b	#4,VERSION
	bne.s	.V2
.V4
	move.l	#musiT+64,$DFF400	; Set music Addr
	move.l	#(musiT_e-musiT-64)/8,$DFF404	; set musik length
	move.w	#$FFFF,$DFF408		; max Volume
	move.w	#160,$DFF40C		; 22 Khz
	move.w	#4,$DFF40A		; 16bit stereo music
	move.w	#$8201,$DFF096		; turn Audio DMA on
	bra	.endmusic
.V2
	
	; Transfer initial audio data into buffers
   	move.l	#musiT+64,AudioStart		; StartPointer
	move.l	#musiT_e,AudioEnd	; End

	bsr	InitV2Audio
.endmusic


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


	lea 				$dff000,a5
    MOVE.W				#DMASET,$96(a5)		; DMACON - enable bitplane, copper, sprites and audio (optional).

	; copperlist setup
	move.l				#COPPERLIST,$80(a5)	; Copperlist point
	move.w				d0,$88(a5)			; Copperlist start
	move.w				#0,$1fc(a5)			; AGA disable
	move.w				#$c00,$106(a5)		; AGA disable
	move.w				#$11,$10c(a5)		; AGA disable

	move.w 				#$C0A0,$dff09a 		; intena, enable interrupt for vbl and aud0

	jsr 				CHUNKYTOPLANAR

	; Start of gameloop
mouse:
    cmpi.b  			#$ff,$dff006    ; Linea 255?
    bne.s   			mouse

	; do we need to load transition phases??? 
	; if transition write register (b0) is not equal to CHUNKY_TRANSITION_END
	; it means yes!
	cmp.l				#CHUNKY_TRANSITION_END,TRANS_IMG_WRITE_PTR
	beq.s				noloadtransitions
	jsr					LOAD_NEXT_IMAGE
	move.l				#CHUNKY_TRANSITION_START,TRANS_IMG_READ_PTR
	bra.w				Aspetta
noloadtransitions:

	; timer delay to sync v4 with v2
testaudiocounter:
	move.l AUDIOCOUNTER,d0
	cmp.l #CHANGEPICTUREDELAY,d0
	bcc audiocounterok
	IFD COLORDEBUG
	move.w #$0F0,$dff180
	ENDC
	bra.w Aspetta
audiocounterok:


	; Manage transition phase
	; delay?
	sub.w				#1,TRANSITION_COUNTER
	bne.w				Aspetta
	move.w				#TRANSITION_DELAY,TRANSITION_COUNTER
	
	; now we are really transitioning!!!!
	move.l				TRANS_IMG_READ_PTR,a0
	adda.l				#320*256,a0
	cmp.l				#CHUNKY_TRANSITION_END,a0
	beq.w				finishtransition

	; copy colors!!!
	move.l				TRANS_COL_READ_PTR,a2
	lea					COLORS+2,a3
	adda.l				#32*2,a2

	; first 8 colors
	move.w				(a2),(a3) 		; 0 - 0
	move.w				$2(a2),$4(a3) 	; 2 - 4
	move.w				$4(a2),$8(a3) 	; 4 - 8
	move.w				$6(a2),$C(a3) 	; 6 - 12
	move.w				$8(a2),$10(a3)	; 8 - 16
	move.w				$A(a2),$14(a3)	; 10 - 20
	move.w				$C(a2),$18(a3)	; 12 - 24
	move.w				$E(a2),$1c(a3) 	; 14 - 28

	; second 8 colors
	move.w				$10(a2),$20(a3) 	; 16 - 32
	move.w				$12(a2),$24(a3) 	; 18 - 36
	move.w				$14(a2),$28(a3) 	; 20 - 40
	move.w				$16(a2),$2C(a3) 	; 22 - 44
	move.w				$18(a2),$30(a3) 	; 24 - 48
	move.w				$1A(a2),$34(a3)		; 26 - 52
	move.w				$1C(a2),$38(a3)		; 28 - 56
	move.w				$1E(a2),$3c(a3) 	; 30 - 60

	; third 8 colors
	move.w				$20(a2),$40(a3) 	; 32 - 64
	move.w				$22(a2),$44(a3) 	; 34 - 68
	move.w				$24(a2),$48(a3) 	; 36 - 72
	move.w				$26(a2),$4C(a3) 	; 38 - 76
	move.w				$28(a2),$50(a3) 	; 40 - 80
	move.w				$2A(a2),$54(a3)		; 42 - 84
	move.w				$2C(a2),$58(a3)		; 44 - 88
	move.w				$2E(a2),$5c(a3) 	; 46 - 92

	; fourth 8 colors
	move.w				$30(a2),$60(a3) 	; 48 - 96
	move.w				$32(a2),$64(a3) 	; 50 - 100
	move.w				$34(a2),$68(a3) 	; 52 - 104
	move.w				$36(a2),$6C(a3) 	; 54 - 108
	move.w				$38(a2),$70(a3) 	; 56 - 112
	move.w				$3A(a2),$74(a3)		; 58 - 116
	move.w				$3C(a2),$78(a3)		; 60 - 120
	move.w				$3E(a2),$7c(a3) 	; 62 - 124

	move.l				a2,TRANS_COL_READ_PTR

	; time to update the chunky screen
	move.l				a0,TRANS_IMG_READ_PTR
    jsr 				CHUNKYTOPLANAR
	bra.s				Aspetta

; code to execute when the transition is complete
finishtransition:
	clr.w				IMAGE_PHASE
	move.w				#TRANSITION_DELAY,TRANSITION_COUNTER

	jsr					GET_IMAGES_ADDR
	move.l 				a1,a0
	MEMCPY16			a0,CHUNKY_IMAGE,81920/16 		; copy image to chunky area
	jsr					GET_IMAGES_ADDR
	move.l				a1,currentImage
	move.l 				#CHUNKY_IMAGE,TRANS_IMG_READ_PTR
	move.l 				#CHUNKY_TRANSITION_START,TRANS_IMG_WRITE_PTR
	move.l 				#CHUNKY_COLORS_START,TRANS_COL_WRITE_PTR
	move.l				#CHUNKY_COLORS_START,TRANS_COL_READ_PTR
	clr.l 				AUDIOCOUNTER

	;move.w				#$000,$dff180

Aspetta:
	;move.w				#$000,$dff180
    cmpi.b  			#$ff,$dff006    ; linea 255?
    beq.s   			Aspetta

	;btst				#10,$dff016	; rmb pressed?
	;bne.s				nochangeimage
	;jsr					LOAD_NEXT_IMAGE

nochangeimage:

    btst				#6,$bfe001	; fire pressed?
	beq.w				exit

	bra.w 				mouse
exit:

	rts			; esci

	IFD DEBUG
    include "debug.s"
    ENDC

******************************
InitV2Audio:
	move.l	AudioStart,A0
	lea	leftBuffer1,a1
	lea	rightBuffer1,a2
	move.w	#221-1,d0               ; Number of samples to copy.
.copy
	move.w	(A0)+,D1                ; Load 16bit sample (L)
	move.w	(A0)+,D2                ; Load 16bit sample (R)
	move.b	(A0),D1
	addq.l	#2,A0
	move.b	(A0),D2
	addq.l	#2,A0

	move.w  D1,(A1)+
	move.w	D2,(A2)+    
	dbra	D0,.copy

	move.l	A0,AudioWorkPtr		; save Ptr

	; Setup Audio Channel IRQ
	moveC	VBR,A0
	move.l	#AudioHandler,$70(A0)	; Set Level 4 (audio) Vector.

	; Set Sampling Rate and Period
	; PAL Clock Constant = 3546895
	; Period = Clock Constant / Hz (22050hz -> 160.857)
	move.w	#160,$DFF0A6
	move.w	#160,$DFF0B6

	; Set Audio Data Buffer Lengths
	move.w	#(442/2),$DFF0A4         ; Set Audio Length for Channel 0.
	move.w	#(442/2),$DFF0B4         ; Set Audio Length for Channel 1.

	; Set Audio Buffer Locations
    	move.l	#leftBuffer1,$DFF0A0
	move.l	#rightBuffer1,$DFF0B0

	; Enable Audio IRQ 
	; -> As both channels are in lock-step, we only need a single IRQ.
	move.w	#$c080,$dff09a

	; Set Volume and Start DMA
	move.w	#AUDIO_VOL,$DFF0A8      ; Set Volume for Channel 0.
	move.w	#AUDIO_VOL,$DFF0B8      ; Set Volume for Channel 1.
	move.w	#$8203,$DFF096          ; Enable Audio Channel DMA 0+1
	clr.b	Audioticktock

	rts

IMAGE_PHASE: dc.w 0

TRANSITION_COUNTER dc.w TRANSITION_DELAY

LOAD_IMAGE:
	move.l 				currentImage,a0 				; get image address
	MEMCPY16			a0,CHUNKY_IMAGE,81920/16 		; copy image to chunky area
	MEMCPY16			a0,COLORS,32*4/16 				; copy copperlist color section
	rts

WRITE_COLOR MACRO
	move.l 				(a0)+,d0 ; start color taken from old image
  	move.l 				(a1)+,d1 ; end color taken from new image

  	fmove 				#IMAGE_TRANSITION_MAX_PHASES,fp1 ; load total amount of phases
	fmove.w 			IMAGE_PHASE,fp2 ; load current phase
  	jsr 				COPFADEFPU2

	move.w				d0,(a3)+ ; write color into copperlist

	vperm 				\1,\2,e23,\2
	
	ENDM

LOAD_NEXT_IMAGE:
	;cmpi.w				#IMAGE_TRANSITION_MAX_PHASES+1,IMAGE_PHASE
	;beq.w 				noresetimage
	jsr					GET_IMAGES_ADDR ; after this a0 = current image and a1 next

	; go to color copperlist
	adda.l				#81920,a0
	adda.l				#81920,a1

	move.l				TRANS_COL_WRITE_PTR,a3

	WRITE_COLOR			#$0123CDEF,e0 ; color 0
	WRITE_COLOR			#$CDEF4567,e0 ; color 1
	WRITE_COLOR			#$0123CDEF,e1 ; color 2
	WRITE_COLOR			#$CDEF4567,e1 ; color 3

	WRITE_COLOR			#$0123CDEF,e2 ; color 4
	WRITE_COLOR			#$CDEF4567,e2 ; color 5
	WRITE_COLOR			#$0123CDEF,e3 ; color 6
	WRITE_COLOR			#$CDEF4567,e3 ; color 7

	WRITE_COLOR			#$0123CDEF,e4 ; color 8
	WRITE_COLOR			#$CDEF4567,e4 ; color 9
	WRITE_COLOR			#$0123CDEF,e5 ; color 10
	WRITE_COLOR			#$CDEF4567,e5 ; color 11

	WRITE_COLOR			#$0123CDEF,e6 ; color 12
	WRITE_COLOR			#$CDEF4567,e6 ; color 13
	WRITE_COLOR			#$0123CDEF,e7 ; color 14
	WRITE_COLOR			#$CDEF4567,e7 ; color 15

	WRITE_COLOR			#$0123CDEF,e8 ; color 16
	WRITE_COLOR			#$CDEF4567,e8 ; color 17
	WRITE_COLOR			#$0123CDEF,e9 ; color 18
	WRITE_COLOR			#$CDEF4567,e9 ; color 19

	WRITE_COLOR			#$0123CDEF,e10 ; color 20
	WRITE_COLOR			#$CDEF4567,e10 ; color 21
	WRITE_COLOR			#$0123CDEF,e11 ; color 22
	WRITE_COLOR			#$CDEF4567,e11 ; color 23

	WRITE_COLOR			#$0123CDEF,e12 ; color 24
	WRITE_COLOR			#$CDEF4567,e12 ; color 25
	WRITE_COLOR			#$0123CDEF,e13 ; color 26
	WRITE_COLOR			#$CDEF4567,e13 ; color 27

	WRITE_COLOR			#$0123CDEF,e14 ; color 28
	WRITE_COLOR			#$CDEF4567,e14 ; color 29
	WRITE_COLOR			#$0123CDEF,e15 ; color 30
	WRITE_COLOR			#$CDEF4567,e15 ; color 31

	move.l				a3,TRANS_COL_WRITE_PTR

	jsr					PIXELINTERPOLATION

	; now increment PHASE
	add.w				#1,IMAGE_PHASE

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

	;lea CHUNKY_IMAGE,a0
    move.l 				TRANS_IMG_READ_PTR,a0
	lea 				TRACK_DATA_1,a1
	lea 				TRACK_DATA_2,a2
	lea 				TRACK_DATA_3,a3
	lea 				TRACK_DATA_4,a4
	lea 				TRACK_DATA_5,a5

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

READ_COLOR_FROM_COPPERLIST MACRO
	; here d0 holds the color we want to find inside the copperlist
	vperm 			\2,\3,\3,d6 ; d6 holds the color inside the copperlist (copy on eX regs)

    psubw 			d6,e23,e16
    pmull 			e16,e16,e16

	; alignment for final addition start
	vperm 			#$00000007,e16,e17,d1
	vperm 			#$00000006,e16,e17,e17
	vperm 			#$00000005,e16,e17,e19
	; alignment for final addition end

    paddw 			d1,e17,d1
    paddw 			d1,e19,d1

    lsl.w 			#5,d1
    move.w 			0(a6,d1.w*2),e16
	
	cmp.w 			e16,e22 
	bcs.s 			vampire_fpu9_upd_max\1
	; if we are here it means we found a shorter distance
	load 			e16,e22
	LOAD 			#\1,E18
vampire_fpu9_upd_max\1:
	ENDM

PIXELINTERPOLATION:
	IFD COLORDEBUG
	move.w #$F00,$dff180
	ENDC

	;movem.l d0-d7/a0-a6,-(sp)
	; ---------------- CODE TO TEST !!!! -----------------------------
	;now remap all chunky data according to the new copperlist - START!!!!!!
	jsr					GET_IMAGES_ADDR ; after this a0 = current image and a1 next

	; now we have to figure out the start color (just one pixel for now)

	lea 				(320*256+0.l,a0),a3
	lea 				(320*256+0.l,a1),a4

	; now i must interpolate to find the new color
	fmove.w 			IMAGE_PHASE,fp2 ; load current phase
	fmove.w 			#IMAGE_TRANSITION_MAX_PHASES,fp1 ; load total amount of phases

	; load destination address where to store the transition image
	move.l				TRANS_IMG_WRITE_PTR,a5

	; recap, at this point i have
	; a0 - pointer to old image
	; a1 - pointer t new image
	; a3 - pointer to copperlist colors
	move.l 				#320*256-1,d7
chunkyremaploop: ; for each pixel
	
	clr.w 				d0
	clr.w 				d1

	move.b 				(a0)+,d0
	move.b 				(a1)+,d1

	lea 				SQRT_TABLE_Q11_5,a6

	move.l 				0(a4,d1.w*4),d1 ; Now d1 holds the destination color
	move.l 				0(a3,d0.w*4),d0 ; Now d0 holds the source color

  	jsr 				COPFADEFPU2

	; d0 now holds the color i am looking for
	; find the index of the new color
	move.w 				#$FFFF,e22

	READ_COLOR_FROM_COPPERLIST 0,#$00000567,e0 ; check color 0
	READ_COLOR_FROM_COPPERLIST 1,#$00000123,e0 ; check color 1
	READ_COLOR_FROM_COPPERLIST 2,#$00000567,e1 ; check color 2
	READ_COLOR_FROM_COPPERLIST 3,#$00000123,e1 ; check color 3

	READ_COLOR_FROM_COPPERLIST 4,#$00000567,e2 ; check color 4
	READ_COLOR_FROM_COPPERLIST 5,#$00000123,e2 ; check color 5
	READ_COLOR_FROM_COPPERLIST 6,#$00000567,e3 ; check color 6
	READ_COLOR_FROM_COPPERLIST 7,#$00000123,e3 ; check color 7

	READ_COLOR_FROM_COPPERLIST 8,#$00000567,e4 ; check color 8
	READ_COLOR_FROM_COPPERLIST 9,#$00000123,e4 ; check color 9
	READ_COLOR_FROM_COPPERLIST 10,#$00000567,e5 ; check color 10
	READ_COLOR_FROM_COPPERLIST 11,#$00000123,e5 ; check color 11

	READ_COLOR_FROM_COPPERLIST 12,#$00000567,e6 ; check color 12
	READ_COLOR_FROM_COPPERLIST 13,#$00000123,e6 ; check color 13
	READ_COLOR_FROM_COPPERLIST 14,#$00000567,e7 ; check color 14
	READ_COLOR_FROM_COPPERLIST 15,#$00000123,e7 ; check color 15

	READ_COLOR_FROM_COPPERLIST 16,#$00000567,e8 ; check color 16
	READ_COLOR_FROM_COPPERLIST 17,#$00000123,e8 ; check color 17
	READ_COLOR_FROM_COPPERLIST 18,#$00000567,e9 ; check color 18
	READ_COLOR_FROM_COPPERLIST 19,#$00000123,e9 ; check color 19

	READ_COLOR_FROM_COPPERLIST 20,#$00000567,e10 ; check color 20
	READ_COLOR_FROM_COPPERLIST 21,#$00000123,e10 ; check color 21
	READ_COLOR_FROM_COPPERLIST 22,#$00000567,e11 ; check color 22
	READ_COLOR_FROM_COPPERLIST 23,#$00000123,e11 ; check color 23

	READ_COLOR_FROM_COPPERLIST 24,#$00000567,e12 ; check color 24
	READ_COLOR_FROM_COPPERLIST 25,#$00000123,e12 ; check color 25
	READ_COLOR_FROM_COPPERLIST 26,#$00000567,e13 ; check color 26
	READ_COLOR_FROM_COPPERLIST 27,#$00000123,e13 ; check color 27

	READ_COLOR_FROM_COPPERLIST 28,#$00000567,e14 ; check color 28
	READ_COLOR_FROM_COPPERLIST 29,#$00000123,e14 ; check color 29
	READ_COLOR_FROM_COPPERLIST 30,#$00000567,e15 ; check color 30
	READ_COLOR_FROM_COPPERLIST 31,#$00000123,e15 ; check color 31

	move.b 				e18,(a5)+ ; write new chunky index
	dbra.l 				d7,chunkyremaploop
	move.l				a5,TRANS_IMG_WRITE_PTR

	rts
	; ---------------- CODE TO TEST !!!! -----------------------------

AUDIOCOUNTER:	dc.l 0

VblHandler:
	btst.b #5,$dff01f
	beq.s novbl
	addi.l #1,AUDIOCOUNTER
novbl:
	move.w #%1110000,$DFF09C
	rte

AudioHandler:
	movem.l	d0-d2/a0-a2,-(sp)

	move.w	#$0080,$DFF09C	; Clear INTREQ for Audio 0.

	tst.b	Audioticktock
	beq.s	.pong
.ping
	lea	leftBuffer1,a1
	lea	rightBuffer1,a2
	bra.s	.process
.pong
	lea	leftBuffer2,a1
	lea	rightBuffer2,a2

    ; We process both left and right channels from
    ; a single IRQ, as both are running at the same rate in lock-step
.process
	neg.b	Audioticktock
	move.l	A1,$DFF0A0	; Set New Buffer Address.
	move.l	A2,$DFF0B0	; Set New Buffer Address.

	move.l	AudioWorkPtr,a0
	move.w	#442/2-1,D0	; Number of samples to copy.
.copy
	move.w	(A0)+,D1                ; Load 16bit sample (L)
	move.w	(A0)+,D2                ; Load 16bit sample (R)
	move.b	(A0),D1
	addq.l	#2,A0
	move.w	D1,(A1)+
	move.b	(A0),D2
	addq.l	#2,A0
	move.w	D2,(A2)+
	dbra	D0,.copy

	move.l	AudioEnd,a1
	cmp.l	a1,a0
	blt.s	.noloop
	move.l	AudioStart,A0
.noloop
	move.l	A0,AudioWorkPtr
.done

	movem.l	(sp)+,D0-D2/A0-A2
	rte

CHUNKY_IMAGE:
	incbin 				  "images/pennabilli.data" ; 320*256 indexed chunky image here
	include 			  "images/pennabilli.col" ; color copperlist here

	; start of transition space
CHUNKY_TRANSITION_START:
	dcb.b   			  320*256*IMAGE_TRANSITION_MAX_PHASES,0
CHUNKY_TRANSITION_END:
CHUNKY_COLORS_START:
	dcb.l   			  32*IMAGE_TRANSITION_MAX_PHASES,0
CHUNKY_COLORS_END:

AudioStart:				  dc.l 0
AudioWorkPtr:			  dc.l 0
AudioEnd:				  dc.l 0
oldAudioVector:			  dc.l 0
VERSION:				  dc.l 0
Audioticktock dc.b 0
	even
currentImage:			  dc.l IMAGES : pointer to the current image
TRANS_IMG_WRITE_PTR:	  dc.l CHUNKY_TRANSITION_START
TRANS_COL_WRITE_PTR:	  dc.l CHUNKY_COLORS_START
TRANS_IMG_READ_PTR:		  dc.l CHUNKY_IMAGE
TRANS_COL_READ_PTR:		  dc.l CHUNKY_COLORS_START

IMAGES:
PENNABILLI:
						  incbin 				  "images/pennabilli.data" ; 320*256 indexed chunky image here
						  include 			  	  "images/pennabilli.col2" ; color copperlist here
SANTACOLOMBA:		  	  incbin 				  "images/santacolomba.data" ; santacolomba
						  include				  "images/santacolomba.col2"
SINALUNGA:		  		  incbin 				  "images/sinalunga.data" ; sinalunga
						  include				  "images/sinalunga.col2"
RECANATI:				  incbin 				  "images/recanati.data" ; recanati image
						  include				  "images/recanati.col2"
CASTIGLIONDELLAGO:		  incbin 				  "images/castigliondellago.data" ; lake image
						  include				  "images/castigliondellago.col2"
RIDRACOLI:		  		  incbin 				  "images/ridracoli.data" ; ridracoli
						  include				  "images/ridracoli.col2"
CHIUSIDELLAVERNA:		  incbin 				  "images/chiusidellaverna.data" ; chiusidellaverna
						  include				  "images/chiusidellaverna.col2"
SPOLETO:		  		  incbin 				  "images/spoleto.data" ; spoleto
						  include				  "images/spoleto.col2"
SANMARINO:		  		  incbin 				  "images/sanmarino.data" ; sanmarino
						  include				  "images/sanmarino.col2"

IMAGES_END:

	section	musiT,DATA_F
musiT
	IFND COLORDEBUG1
	incbin										  "music/intervallo.aiff"
	ENDC
musiT_e

    SECTION GRAPHICS,DATA_C

	;include "AProcessing/libs/rasterizers/processing_bitplanes_fast.s"
	include 									  "copperlist.s"

TRACK_DATA_1:
	dcb.b   									  40*240,0
DASHBOARD_DATA_1:
	dcb.b   									  40*16,0
TRACK_DATA_2:
	dcb.b   									  40*240,0
DASHBOARD_DATA_2:
	dcb.b   									  40*16,0
TRACK_DATA_3:
	dcb.b   									  40*240,0
DASHBOARD_DATA_3:
	dcb.b   									  40*16,0
TRACK_DATA_4:
	dcb.b   									  40*240,0
DASHBOARD_DATA_4:
	dcb.b   									  40*16,0
TRACK_DATA_5:
	dcb.b   									  40*240,0
DASHBOARD_DATA_5:
	dcb.b   									  40*16,0

CHIPAUDIODATA:                       ; Audio data must be in Chip memory
	dcb.b 										  AUDIO_CHUNK,0
    SECTION AppBSS,BSS_C
leftBuffer1  									  ds.w 221           ; We use 2 buffers for each left/right 
leftBuffer2  									  ds.w 221           ; so that we can ping-pong between them when reloading
rightBuffer1 									  ds.w 221           ; during the IRQ.
rightBuffer2 									  ds.w 221