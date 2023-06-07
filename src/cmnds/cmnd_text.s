;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"
.include "errno.inc"

;----------------------------------------------------------------------
;			includes SDK
;----------------------------------------------------------------------
.include "SDK.mac"
.include "types.mac"

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------
.include "macros/utils.mac"
;.include "macros/SDK-ext.mac"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import fgets
.import submit_line

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_text

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
; de main.s
LINE_MAX_SIZE = 128

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"

.popseg

;----------------------------------------------------------------------
;			Chaines statiques
;----------------------------------------------------------------------
.pushseg
	.segment "RODATA"
		endtext:
			string80 "ENDTEXT"
			.byte $00
.popseg

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
;		-
;	Utilisées:
;		line
;		endtext
;		submit_line
; Sous-routines:
;	skip_spaces
;	submit_reopen
;	submit_close
;	fgets
;	submit
;	find_cmnd
;	XWSTR0
;	crlf
;----------------------------------------------------------------------
.proc cmnd_text
		jsr	skip_spaces
		bne	error

		jsr	submit_reopen
		bcs	open_error

	loop:
		lda	#<line
		ldy	#>line
		ldx	#LINE_MAX_SIZE

		jsr	fgets
		bcs	end

		; Pour prendre en compte les caractères de contrôle et les
		; paramètres.
		lda	#<line
		ldy	#>line
		ldx	#$00
		jsr	submit
		; Erreur?
		bcs	error

		lda	#<endtext
		ldy	#>endtext
		ldx	#$00
		clc
		jsr	find_cmnd
		bcc	end

		lda	#<submit_line
		ldy	#>submit_line
		.byte	$00, XWSTR0
		crlf
		jmp	loop

	end:
		jsr	submit_close
		rts


	error:
		; Erreur de syntaxe, TEXT doit être seul sur la ligne
		lda	#$ff
		sec
		rts

	open_error:
		rts

.endproc

