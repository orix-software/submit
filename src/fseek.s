.feature string_escapes

;----------------------------------------------------------------------
;                       cc65 includes
;----------------------------------------------------------------------
.include "telestrat.inc"
.include "fcntl.inc"

;----------------------------------------------------------------------
;			Orix Kernel includes
;----------------------------------------------------------------------
.include "kernel/src/include/kernel.inc"

;----------------------------------------------------------------------
;			Orix SDK includes
;----------------------------------------------------------------------
.include "ch376.inc"

;----------------------------------------------------------------------
;				Imports
;----------------------------------------------------------------------
; From main.s
.import fpos
.import fsize

;----------------------------------------------------------------------
;				Exports
;----------------------------------------------------------------------
.export fseek
.export fseek_end

;----------------------------------------------------------------------
;			fseek (en attendant XFSEEK 32 bits)
;----------------------------------------------------------------------
;
; Entrée:
;	-
; Sortie:
;	Z: 1-> INT_SUCCESS, 0-> Erreur
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		fpos
; Sous-routines:
;	WaitResponse
;----------------------------------------------------------------------
.proc fseek
		lda	#CH376_BYTE_LOCATE
		sta	CH376_COMMAND

		lda	fpos
		sta	CH376_DATA

		lda	fpos+1
		sta	CH376_DATA

		lda	fpos+2
		sta	CH376_DATA

		lda	fpos+3
		sta	CH376_DATA

		jsr	WaitResponse
		cmp	#CH376_USB_INT_SUCCESS

		rts
.endproc

;----------------------------------------------------------------------
;			fseek_end (en attendant XFSEEK SEEK_END)
;----------------------------------------------------------------------
;
; Entrée:
;	-
; Sortie:
;	A,X,Y: modifiés
;	Z: 1-> INT_SUCCESS, 0-> Erreur
;
; Variables:
;	Modifiées:
;		- fpos (mais restorée)
;	Utilisées:
;		-
; Sous-routines:
;	- fsize
;	- fseek
;----------------------------------------------------------------------
.if 0
	.proc fseek_end
			; Sauvegarde fpos modifié par fseek
			lda	fpos
			sta	ld_fpos+1
			lda	fpos+1
			sta	ld_fpos1+1
			lda	fpos+2
			sta	ld_fpos2+1
			lda	fpos+3
			sta	ld_fpos3+1

			; On se place à la fin du fichier
			jsr	fsize
			jsr	fseek
			php

			; Restore fpos
		ld_fpos:
			lda	#$00
			sta	fpos
		ld_fpos1:
			lda	#$00
			sta	fpos+1
		ld_fpos2:
			lda	#$00
			sta	fpos+2
		ld_fpos3:
			lda	#$00
			sta	fpos+3

			plp
			rts
	.endproc
.else

.proc fseek_end
		; fsize
		lda	#CH376_READ_VAR32
		sta	CH376_COMMAND

		lda	#CH376_VAR_FILE_SIZE
		sta	CH376_DATA

		lda	CH376_DATA
		sta	fpos0+1

		lda	CH376_DATA
		sta	fpos1+1

		lda	CH376_DATA
		sta	fpos2+1

		lda	CH376_DATA
		sta	fpos3+1

		; fseek
		lda	#CH376_BYTE_LOCATE
		sta	CH376_COMMAND

	fpos0:
		lda	#$00
		sta	CH376_DATA

	fpos1:
		lda	#$00
		sta	CH376_DATA

	fpos2:
		lda	#$00
		sta	CH376_DATA

	fpos3:
		lda	#$00
		sta	CH376_DATA

		jsr	WaitResponse
		cmp	#CH376_USB_INT_SUCCESS

		rts
.endproc
.endif
;----------------------------------------------------------------------
;
; Entrée:
;
; Sortie:
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc WaitResponse
		ldy     #$ff

	loop1:
		ldx     #$ff
	loop2:
		lda     CH376_COMMAND
		bmi     loop

		lda     #$22
		sta     CH376_COMMAND
		lda     CH376_DATA
		rts

	loop:
		dex
		bne     loop2

		dey
		bne     loop1

		rts
.endproc

