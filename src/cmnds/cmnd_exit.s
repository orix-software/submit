;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"
.include "errno.inc"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import spar1
	spar := spar1

.import save_a
.import errorlevel
.importzp var1

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_exit

;----------------------------------------------------------------------
;			Programme principal
;----------------------------------------------------------------------
.segment "CODE"

;----------------------------------------------------------------------
;
; Entrée:
;	X: offset sur le premier caractère suivant la commande
;
; Sortie:
;
; Variables:
;	Modifiées:
;		save_a
;		save_x
;		errorlevel
;		var1
;	Utilisées:
;		submit_line
; Sous-routines:
;	skip_spaces
;	spar
;----------------------------------------------------------------------
.proc cmnd_exit
		; Initialise la valaur par défaut
		lda	#EOK
		sta	errorlevel
		lda	#$00
		sta	errorlevel+1

		; Saute les espaces
		jsr	skip_spaces
		; Sauvegarde l'offset dans submit_line
		stx	save_x
		beq	no_value

		ldy	#>submit_line
		clc
		txa
		adc	#<submit_line
		sta	save_a
		bcc	_exit
		iny

	_exit:
		; Inverse le poids fort et le poids faible
		; il faut A=MSB et Y=LSB pour setcbp
		tya
		ldy	save_a

		ldx	#%10100000
		jsr	spar
		.byte	var1, $00
		bcs	value_error

		; Coppie la valeur dans ERRORLEVEL
		lda	var1
		sta	errorlevel
		lda	var1+1
		sta	errorlevel+1

	no_value:
		lda	#$e4
		sec
		rts

	value_error:
		ldx	save_x
		lda	#ERANGE
		sec
		rts

.endproc

