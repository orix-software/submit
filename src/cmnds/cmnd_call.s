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
;.include "macros/utils.mac"
;.include "macros/SDK-ext.mac"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import fpos
.import linenum

.import buffer_reset
.import cmnd_goto

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_call
.export cmnd_return

.export stack_ptr
.export push
.export pop

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
MAX_LEVELS = 20

typedef .struct stack_item
	unsigned short line
	unsigned long offset
.endstruct

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"

		unsigned short stack_ptr

		; Voir pour utiliser un malloc et un pointeur vers la pile
		struct stack_item, stack[MAX_LEVELS]
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
;		-
; Sous-routines:
;	push
;	cmnd_goto
;----------------------------------------------------------------------
.proc cmnd_call
		jsr	push
		bcs	error
		jmp	cmnd_goto

	error:
		rts
.endproc

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
;		-
; Sous-routines:
;	pop
;----------------------------------------------------------------------
.proc cmnd_return
		jsr	pop
		bcs	error

	error:
		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	-
; Sortie:
;
; Variables:
;	Modifiées:
;		stack_ptr
;		stack
;	Utilisées:
;		linenum
;		fpos_text
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc push
		; Voir pour utiliser un malloc et un pointeur vers la pile

		pha

		ldy	stack_ptr
		cpy	#MAX_LEVELS
		bcs	error

		; Sauvegarde le numéro de la ligne suivant le call
		; (utile uniquement pour les messages d'erreurs)
;		sed
;		clc
		lda	linenum
;		adc	#$01
		sta	stack,y
		lda	linenum+1
;		adc	#$00
		sta	stack+1,y
;		cld

		; Sauvegarde l'offset de la ligne suivant le call
		lda	fpos_text
		sta	stack+2,y
		lda	fpos_text+1
		sta	stack+3,y
		lda	fpos_text+2
		sta	stack+4,y
		lda	fpos_text+3
		sta	stack+5,y

		clc
		lda	#.sizeof(stack_item)
		adc	stack_ptr
		sta	stack_ptr

		pla
		rts

	error:
		pla

		; Out of memory (trop d'appels imbriqués)
		lda	#$f0
		rts

.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	-
; Sortie:
;
; Variables:
;	Modifiées:
;		stack_ptr
;		linenum
;		fpos
;		fpos_text
;	Utilisées:
;		stack
; Sous-routines:
;	buffer_reset
;----------------------------------------------------------------------
.proc pop
		pha

		lda	stack_ptr
		beq	error
		sec
		sbc	#.sizeof(stack_item)
		sta	stack_ptr
		tay

		; Restaure le numéro de ligne
		; (utile uniquement pour les messages d'erreurs)
		lda	stack,y
		sta	linenum
		lda	stack+1,y
		sta	linenum+1

		; Restaure l'offset de la ligne
		lda	stack+2,y
		sta	fpos
		sta	fpos_text
		lda	stack+3,y
		sta	fpos+1
		sta	fpos_text+1
		lda	stack+4,y
		sta	fpos+2
		sta	fpos_text+2
		lda	stack+5,y
		sta	fpos+3
		sta	fpos_text+3

		jsr	buffer_reset

		clc
		pla
		rts

	error:
		pla
		sec
		; Return without gosub
		lda	#$f1
		rts
.endproc

