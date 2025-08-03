;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

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

; From scan.s
.import push_if
.import pop_else

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_if

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
;	C: 0-> Ok, 1-> erreur
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	push_if
;	pop_else
;	get_logical_expr
;----------------------------------------------------------------------
.proc cmnd_if
		jsr	push_if
		bcs	error

		jsr	get_cond_expr
		bcs	error_A

		beq	false

	true:
		rts

	false:
		jmp	pop_else

	error:
		sec
		lda	#EINVAL

	error_A:
		rts

.endproc

