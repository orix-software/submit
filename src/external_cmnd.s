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
;.import PrintRegs

;.import submit_close
;.import submit_reopen

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
;	C: 0->Ok, 1->Erreur
; Variables:
;       Modifiées:
;               save_x
;		errorlevel
;       Utilisées:
;               submit_line
; Sous-routines:
;       XEXEC
;----------------------------------------------------------------------
.proc external_command
		stx	save_x

		;jsr	submit_close

		; Sauvegarde la banque active
		; EXEC revient avec la banque 5 active
		lda	VIA2::PRA
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

		; Le code de retour du kernel est dans:
		; Kernel VERSION_2022_2 ($00) -> Acc (pas de code retour de la commande)
		; Kernel VERSION_2022_3 ($00) -> Acc (pas de code retour de la commande)
		; Kernel VERSION_2022_4 ($01) -> Y (code retour de  la commande dans A)
		;cmp	#EOK
		cpy	#EOK
		bne	error

		; Code erreur de la commande dans ERRORLEVEL
		sta	errorlevel
		lda	#$00
		sta	errorlevel+1

		; Restaure la banque
		pla
		sta	VIA2::PRA

		;jsr	submit_reopen
		clc
		rts

	error:
		; Restaure la banque
		pla
		sta	VIA2::PRA
;		print	unknown_msg
;		print	submit_line
;		crlf

		;jsr	submit_reopen

		ldx	save_x
		; Le code de retour du kernel est dans:
		; Kernel VERSION_2022_2 ($00) -> Acc (pas de code retour de la commande)
		; Kernel VERSION_2022_3 ($00)
		; Kernel VERSION_2022_4 ($01) -> Y (code retour de  la commande dans A)
		; lda	#ENOENT
		tya

		sec
		rts

;	unknown_msg:
;		.asciiz "\r\nUnknown command: "

.endproc


