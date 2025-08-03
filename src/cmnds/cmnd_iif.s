.feature string_escapes

;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.include "telestrat.inc"
.include "errno.inc"
.include "fcntl.inc"

;----------------------------------------------------------------------
;			includes SDK
;----------------------------------------------------------------------
.include "SDK.mac"
.include "types.mac"

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------
.include "submit.inc"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
; From get_cond_expr.s
.import get_cond_expr

; From internal_cmnd.s
.import internal_command
.import skip_spaces

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_iif

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
		; <: 60 -> 1 => b6
		; =: 61 -> 2 => b7
		; >: 62 -> 3 => b7+b6
		; unsigned char cmp_op
.popseg

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
;	C: 0-> Ok, 1-> Erreur
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	get_logical_expr
;	skip_spaces
;	internal_command
;----------------------------------------------------------------------
.proc cmnd_iif
		jsr	get_cond_expr
		bcs	error_A

		beq	false
	true:
		pla
		pla
		jsr	skip_spaces
		jmp	internal_command

	false:

	error_A:
		rts

.endproc
