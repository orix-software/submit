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

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import PrintRegs

.import submit_close
.import submit_reopen

.import submit_line

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export external_command

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
		unsigned char save_x

.popseg

;----------------------------------------------------------------------
;			Programme principal
;----------------------------------------------------------------------
.segment "CODE"

;----------------------------------------------------------------------
;
; Entrée:
;	X: offset vers le premier caractère non ' '
;
; Sortie:
;
; Variables:
;       Modifiées:
;               -
;       Utilisées:
;               -
; Sous-routines:
;       -
;----------------------------------------------------------------------
.proc external_command
		stx	save_x

		;jsr	submit_close

		; Sauvegarde la banque active
		; EXEC revient avec la banque 5 active
		lda	$0321
		pha

		clc
		lda	#<submit_line
		adc	save_x
		ldy	#>submit_line
		bcc	go
		iny
	go:
		ldx	#$00
		.byte	$00, XEXEC

;		jsr	PrintRegs

		cmp	#EOK
		bne	error

		; Restaure la banque
		pla
		sta	$0321

		;jsr	submit_reopen
		clc
		rts

	error:
		; Restaure la banque
		pla
		sta	$0321
;		print	unknown_msg
;		print	submit_line
;		crlf

		;jsr	submit_reopen

		ldx	save_x
		lda	#ENOENT
		sec
		rts

;	unknown_msg:
;		.asciiz "\r\nUnknown command: "

.endproc


