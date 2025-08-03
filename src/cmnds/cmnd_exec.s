.feature string_escapes

;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.include "telestrat.inc"
.include "errno.inc"

;----------------------------------------------------------------------
;			includes SDK
;----------------------------------------------------------------------
.include "SDK.mac"

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
; From main.s
.import errorlevel

; From submit.s
.import submit_line

; From internal_cmnd.s
.import save_x
.import skip_spaces

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_exec

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
.proc cmnd_exec
		jsr	skip_spaces
		stx	save_x

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
		ldx	#$01
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

