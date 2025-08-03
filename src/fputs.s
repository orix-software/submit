.feature string_escapes

;----------------------------------------------------------------------
;                       cc65 includes
;----------------------------------------------------------------------
.include "telestrat.inc"

;----------------------------------------------------------------------
;			Orix SDK includes
;----------------------------------------------------------------------
.include "types.mac"

;----------------------------------------------------------------------
;				Imports
;----------------------------------------------------------------------

;----------------------------------------------------------------------
;				Exports
;----------------------------------------------------------------------
.export fputs
.export fputc
.export fput_crlf

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
CASE_SENSITIVE_LABELS .set 0

;----------------------------------------------------------------------
;				Page Zéro
;----------------------------------------------------------------------
.pushseg
	.segment "ZEROPAGE"
.popseg

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
		unsigned char fchar
		crlf:
			.byte	$0d, $0a
.popseg

;----------------------------------------------------------------------
;				fputs
;----------------------------------------------------------------------
;
; Entrée:
;	- AY: adresse de la chaine
;	- X : fp
;
; Sortie:
;	- AX: nombre d'octets écrits
;	- Y : modifié
;	Z: 1-> INT_SUCCESS, 0-> Erreur
;
; Variables:
;	Modifiées:
;		- PTR_READ_DST
;	Utilisées:
;		-
;
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc fputs
		sta	PTR_READ_DEST
		sty	PTR_READ_DEST+1
		; stx	fp

		; Calcul de la longueur de la chaine
		ldy	#$ff
	loop:
		iny
		lda	(PTR_READ_DEST),y
		bne	loop

		sty	chk_len+1
		; size
		tya
		beq	end

		ldy	#$00

		.byte	$00, XFWRITE

		cpx	#$00
		bne	end

	chk_len:
		cmp	#$00
	end:
		rts
.endproc

;----------------------------------------------------------------------
;				fputc
;----------------------------------------------------------------------
;
; Entrée:
;	- A: caractère
;	- X : fp
;
; Sortie:
;	- AX: longueur de la chaine (1)
;	- Y : modifié
;	- Z: 1-> INT_SUCCESS, 0-> Erreur
;
; Variables:
;	Modifiées:
;		- PTR_READ_DST
;	Utilisées:
;		-
;
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc fputc
		sta	fchar

		lda	#<fchar
		sta	PTR_READ_DEST
		lda	#>fchar
		sta	PTR_READ_DEST+1

		lda	#$01
		ldy	#$00

		.byte	$00, XFWRITE
		cpx	#$00
		bne	end

	chk_len:
		cmp	#$01
	end:
		rts
.endproc

;----------------------------------------------------------------------
;				fput_crlf
;----------------------------------------------------------------------
;
; Entrée:
;	- X : fp
;
; Sortie:
;	- AX: longueur de la chaine (2)
;	- Y : modifié
;	- Z: 1-> INT_SUCCESS, 0-> Erreur
;
; Variables:
;	Modifiées:
;		- PTR_READ_DST
;	Utilisées:
;		-
;
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc fput_crlf
		lda	#<crlf
		sta	PTR_READ_DEST
		lda	#>crlf
		sta	PTR_READ_DEST+1

		lda	#$02
		ldy	#$00

		.byte	$00, XFWRITE
		cpx	#$00
		bne	end

	chk_len:
		cmp	#$02
	end:
		rts
.endproc


