;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"
.include "errno.inc"
;.include "fcntl.inc"

;----------------------------------------------------------------------
;			includes SDK
;----------------------------------------------------------------------
.include "SDK.mac"
.include "types.mac"

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------
.include "macros/utils.mac"
.include "macros/SDK-ext.mac"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import spar1
	spar := spar1


.importzp var1, var2
.import save_a, save_x, save_y

.import submit_line
.import skip_space

.import cmns_echo

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_at

;----------------------------------------------------------------------
;			Programme principal
;----------------------------------------------------------------------
.segment "CODE"

;----------------------------------------------------------------------
;
; Entrée:
;	X: offset sur le premier caractère suivant la commande
; Sortie:
;
; Variables:
;	Modifiées:
;		save_a
;		save_x
;		save_y
;		var1
;		var2
;	Utilisées:
;		submit_line
; Sous-routines:
;	skip_spaces
;	cmnd_echo
;	spar
;	cputc
;----------------------------------------------------------------------
.proc cmnd_at
		jsr	skip_spaces
		beq	error

		stx	save_x

		; Initialise les valeurs par défaut
		lda	#$ff
		sta	var1
		sta	var1+1

		sta	var2
		sta	var2+1

		ldy	#>submit_line
		clc
		txa
		adc	#<submit_line
		sta	save_a
		bcc	_at
		iny

		; Inverse le poids fort et le poids faible
		; il faut A=MSB et Y=LSB pour spar
	_at:
		tya
		ldy	save_a

		; jsr	setcbp

		ldx	#%10000000
		jsr	spar
		.byte	var1, var2, $00
		bcs	value_error

		; Ici AY pointe sur le caractère suivant la valeur (A=MSB)
		sta	save_a
		sty	save_y

		lda	var1+1
		bne	value_error
		lda	var2+1
		bne	value_error

		lda	var1
		cmp	#28
		bcs	value_error
		adc	#$40
		sta	var1

		lda	var2
		cmp	#40
		bcs	value_error
		adc	#$40
		sta	var2

		cputc	$1f
		lda	var1
		cputc
		lda	var2
		cputc

		; Recalcule l'offset par rapport à submit_line
		sec
		lda	save_y
		sbc	#<submit_line
		tax

;		lda	save_y
;		ldy	save_a
;		ldx	save_x

		lda	submit_line,x
		bne	echo
		clc
		rts

	echo:
		jmp	cmnd_echo
;		clc
;		rts

	value_error:
		; Recalcule l'offset par rapport à submit_line
		;sec
		;lda	save_y
		;sbc	#<submit_line
		;tax
		ldx	save_x

	error:
		lda	#ERANGE
		sec
		rts
.endproc

