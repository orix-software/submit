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
.include "submit.inc"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import save_x

.import skip_spaces, string_delim

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_on
.export on_error

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"

		unsigned char on_error[LINE_MAX_SIZE]

	.segment "RODATA"
		on_opts:
			string80	"ERROR"
			.byte	$00

;		on_ptrs:
;			.word	on_error
.popseg

;----------------------------------------------------------------------
;
; Entrée:
;	X: offset sur le premier caractère suivant la commande
;
; Sortie:
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	skip_spaces
;----------------------------------------------------------------------
.proc cmnd_on
		jsr	skip_spaces
		; beq	error_enoent
		beq	error2

		stx	save_x

		lda	#<on_opts
		ldy	#>on_opts
		clc
		jsr	find_cmnd
		bcs	error

		; Ici A = indice de l'optoon
;		asl
;		tay
;		lda	on_ptrs,y
;		sta	stxx+1
;		lda	on_ptrs+1,y
;		sta	stxx+2

		jsr	skip_spaces
		beq	disable

		dex
		ldy	#$ff
	loop:
		iny
		inx
		lda	submit_line,x
;	stxx:
		sta	on_error,y
		bne	loop

		clc
		rts

	error:
		ldx	save_x
	error2:
		lda	#ERANGE
;		.byte	$2c
;	error_enoent:
;		lda	#ENOENT

		sec
		rts

	disable:
		lda	#$00
		sta	on_error

		clc
		rts
.endproc

