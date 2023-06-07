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

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------
;.include "macros/utils.mac"
;.include "macros/SDK-ext.mac"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import submit_line
.import exec_address

.import skip_spaces

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_type

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
;		exec_address
;		submit_line
;	Utilisées:
;		-
; Sous-routines:
;	skip_spaces
;----------------------------------------------------------------------
.proc cmnd_type
		; Alias pour cat
		jsr	skip_spaces
		beq	end

		; Ici X=offset vers le premier caractère du paramètre
		sta	exec_address

		; Remplace 'type' par 'cat '
		dex
		lda	#' '
		sta	submit_line,x
		dex
		lda	#'t'
		sta	submit_line,x
		dex
		lda	#'a'
		sta	submit_line,x
		dex
		lda	#'c'
		sta	submit_line,x

		sec
		lda	exec_address
		sbc	#$04
		bcs	cat
		dey

	cat:
		; Indique qu'il n'y a pas de commande interne TYPE
		; jmp	external_command
		sec
		lda	#ENOENT
		rts

	end:
		; Erreur pas de paramètre
		lda	#EINVAL
		sec
		rts
.endproc

