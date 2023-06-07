;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"

;----------------------------------------------------------------------
;			includes SDK
;----------------------------------------------------------------------
.include "SDK.mac"
.include "types.mac"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
;.importzp var1, var2

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export xbindx

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
.popseg

;----------------------------------------------------------------------
;				Constantes
;----------------------------------------------------------------------
.pushseg
	.segment "RODATA"
		const_10_decimal_low:
			.lobytes	10, 100, 1000, 10000

		const_10_decimal_high:
			.hibytes	10, 100, 1000, 10000
.popseg

;----------------------------------------------------------------------
;			Programme principal
;----------------------------------------------------------------------
.segment "CODE"

;----------------------------------------------------------------------
; Routine du kernel modifiée pour gérer la suppression de la justification
; à droite.
;
; Entrée:
;	AY: Valeur (A=LSB)
;	X: Puissance de 10
;	TR5-TR6: Adresse du buffer
;
; Sortie:
;	A: Dernier chiffre (ASCII)
;	X: $ff
; 	Y: Offset du dernier caractère
;
; Variables:
;       Modifiées:
;               TR0
;		TR1
;		TR2
;		TR3
;		TR4: nombre de caractères du nombre
;
;       Utilisées:
;		DEFAFF
;               TR5-TR6
;		const_10_decimal_low
;		const_10_decimal_high
;
; Sous-routines:
;       -
;----------------------------------------------------------------------
.proc xbindx
		sta	TR1
		sty	TR2

		lda	#$00 ; 65c02
		sta	TR3
		sta	TR4
	L5:
		lda	#$FF
		sta	TR0

	L4:
		inc	TR0
		sec
		lda	TR1
		tay
		sbc	const_10_decimal_low,X
		sta	TR1
		lda	TR2
		pha
		sbc	const_10_decimal_high,X ;
		sta	TR2
		pla
		bcs	L4
		sty	TR1
		sta	TR2
		lda	TR0
		beq	L2
		sta	TR3
		bne	L3+1

	L2:
		ldy	TR3
		bne	L3+1
		lda	DEFAFF
		; Modification
		; [
		beq	next
		; ]

	L3:
		.byt	$2C
		ora	#$30

		jsr	L1

	next:
		dex
		bpl	L5
		lda	TR1
		ora	#$30
	L1:
		ldy	TR4
		sta	(TR5),Y
		inc	TR4

		rts
.endproc

.if 0
;----------------------------------------------------------------------
;
; Entrée:
;	AY: Valeur (A=LSB)
;	TR5: adresse du buffer
;
; Sortie:
;	X: offset du premier chiffre significatif dans le buffer
;
; Variables:
;       Modifiées:
;               -
;       Utilisées:
;               - TR5
; Sous-routines:
;       -
;----------------------------------------------------------------------
.proc itoa
		sta	var1		;Save Low byte
		sty	var1+1		;Save High byte
		ldy	#5		;Get ASCII buffer offset

;		stz	DATABUFF,x	;Zero last buffer byte for null end
;
	cnvert:
		lda	#$00		;Clear remainder
		ldx	#16		;Set loop count for 16-bits
;
	dvloop:
		cmp	#$05		;Partial remainder >= 10/2
		bcc	dvloop2		;Branch if less
		sbc	#$05		;Update partial (carry set)
;
	dvloop2:
		rol	var1		;Shift carry into dividend
		rol	var1+1		;Which will be quotient
		rol			;Rotate A Reg
		dex			;Decrement count
		bne	dvloop		;Branch back until done
		ora	#$30		;OR in $30 for ASCII
;
		dey			;Decrement buffer offset
		sta	(TR5),y		;Store digit into buffer
;
		lda	var1		;Get the Low byte
		ora	var1+1		;OR in the High byte (check for zero)
		bne	cnvert		;Branch back until done

		rts
.endproc

.endif
