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
.import fpos

;----------------------------------------------------------------------
;				Exports
;----------------------------------------------------------------------
.export fseek

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


