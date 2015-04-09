.LOROM

; Cartridge header should be copied from the original ROM
.SNESHEADER
 ID    "ADYJ"
 NAME  "MADOMONOGATARI       "
 LOROM
 FASTROM
 CARTRIDGETYPE $02
 ROMSIZE $0B
 SRAMSIZE $03
 COUNTRY $00
 LICENSEECODE $33
 VERSION $00
.ENDSNES

.MEMORYMAP
 SLOTSIZE $8000
 DEFAULTSLOT 0
 SLOT 0 $8000
.ENDME

.ROMBANKSIZE $8000
.ROMBANKS 1

.SNESNATIVEVECTOR               ; Define Native Mode interrupt vector table
  COP EmptyHandler
  BRK EmptyHandler
  ABORT EmptyHandler
  NMI VBlank
  IRQ EmptyHandler
.ENDNATIVEVECTOR

.SNESEMUVECTOR                  ; Define Emulation Mode interrupt vector table
  COP EmptyHandler
  ABORT EmptyHandler
  NMI EmptyHandler
  RESET Start
  IRQBRK EmptyHandler
.ENDEMUVECTOR


.BANK 0 SLOT 0

.ORG $0000
.SECTION "SETUP" SEMIFREE

.EMPTYFILL $FF

.DEFINE PARAM_SONG = $808000
	.db	$00
.DEFINE PARAM_SONG_PRELOAD = $808001
	.db	$00
.DEFINE PARAM_SONG_TYPE = $808002
	.db	$00
.DEFINE PARAM_RESERVED = $808003
	.db	$00

; setup routine derived from the original setup ($80/8000)
Start:
	sei
	clc
	xce

	; zero memory ($0000-$1FFF)
	rep	#$30
	ldx	#$0000
	ldy	#$0001
	stz	$00
	lda	#$1ffd
	mvn	$00,$00

	sep	#$20
	phk
	plb
	rep	#$20

	; set direct page 0
	lda	#$0000
	tcd

	; set stack pointer
	sep	#$20
	ldx	#$1fff
	txs

	; setup interrupt
	sep	#$20
	lda	#$81
	sta	$0c84
	lda	#$81
	sta	$4200
	cli

	; transfer SPC program
	jsr	$e6ad

	lda	#$01
	jsl	$00e74f
	lda	#$02
	jsl	$00e74f
	lda	#$03
	jsl	$00e74f

	; set stereo
	jsl	$00ecc9
	lda	#$01
	jsl	$00ecb8

;	lda	#$f1
;	jsl	$00e87f

	; enable sound processing
	lda	#$01
	sta	$5d

	; check preload request
	lda	PARAM_SONG_PRELOAD
	bpl	loc_PlaySound

loc_PreloadBGM:
	; request BGM playback
	and	#$7f
	jsl	$80ebfa
;	jsl	$80ec44

	; nullify the playback
	; FIXME: broken SRCN 3 in Last Battle song
	; The issue is caused by SPC program (not a bug of SNSF driver!)
	; Anyway, we need to write #1 to PSRAM:$00 for the workaround, but how?
	stz	$1c6d

loc_WaitForPreload
	; wait for data transfer
	lda	$1c6c
	bne	loc_WaitForPreload

loc_PlaySound:
	lda	PARAM_SONG_TYPE
	beq	loc_PlayBGM
	bpl	loc_PlaySFX
	bmi	loc_PlayVoice

loc_PlayBGM:
	lda	PARAM_SONG
	jsl	$80ebfa
;	jsl	$80ec44

	bra loc_MainLoop

loc_PlaySFX:
	lda	PARAM_SONG
	jsl	$80e891

	bra loc_MainLoop

loc_PlayVoice:
	lda	PARAM_SONG
	jsl	$80ebb0

loc_MainLoop:
	wai
	bra	loc_MainLoop

VBlank:
	; NMI ($80/8864)
	rep	#$30
	phb
	pha
	phx
	phy
	phd

	; clear NMI flag
	phk
	plb
	lda	$4210

	; disable interrupt
	lda	#$01
	sta	$4200

	lda	$5d
	beq	loc_SkipSoundReq

	; dispatch sound requests
	sep	#$10
	jsr	$e8da
	rep	#$10

loc_SkipSoundReq:
	; restore interrupt
	lda	$0c84
	sta	$4200

	rep	#$20
	pld
	ply
	plx
	pla
	plb
	sep	#$20
	rti

EmptyHandler:
	RTI

.ENDS