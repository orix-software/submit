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

XOPENDIR = $2f

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------
.include "submit.inc"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
;.importzp ptr

; From main.s
.import fp

; From internal_cmmnd.s
.importzp var1
.import submit_line, line
.import save_a, save_x, save_y

.import skip_spaces

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_exist

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
		; <: 60 -> 1 => b6
		; =: 61 -> 2 => b7
		; >: 62 -> 3 => b7+b6
		unsigned char cmp_op
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
;
; Variables:
;	Modifiées:
;		save_a
;		save_x
;		save_y
;		line
;		fp
;	Utilisées:
;		submit_line
; Sous-routines:
;	skip_spaces
;	is_dir
;	fopen
;	fclose
;----------------------------------------------------------------------
.proc cmnd_exist
		jsr	skip_spaces
		beq	error

		stx	save_x
		sta	save_a
		sty	save_y

		; Copie le nom du fichier dans le tampon line
		ldy	#$ff
		dex
	loop:
		inx
		iny
		lda	submit_line,x
		sta	line, y
		beq	open
		cmp	#' '
		bne	loop

		lda	#$00
		sta	line,y

	open:
		sty	save_y
		stx	save_x
		lda	#<line
		ldy	#>line

; TEMPORAIRE - TESTS
;		jsr	is_dir
;		beq	is_file
;		lda	#$00
;		php
;		beq	set_error

	is_file:
		; Supprime le "/*" placé à la fin du nom de fichier par opendir
		; (remet le $00 à sa place)
		ldy	save_y
		lda	#$00
		sta	line,y

		fopen	line, O_RDONLY
		sta	fp
		stx	fp+1
		eor	fp+1
		php

		fclose	(fp)
		; errorlevel: 0-> existe, 1 -> inexistant
		; MSDOS: "if exist xxxx" exist ne modifie par errorlevel

	set_error:
		lda	#$00
		tay
		sta	var1+1
		plp
		bne	end
		iny
	end:
		sty	var1

		; Ajuste AY
		ldx	save_x
		clc
		ldy	#>submit_line
		lda	#<submit_line
		adc	save_x
		bcc	_exit
		iny
	_exit:
		clc
		rts

	error:
		lda	#EINVAL
		sec
		rts

	;----------------------------------------------------------------------
	;
	; Entrée:
	;	-
	;
	; Sortie:
	;
	; Variables:
	;	Modifiées:
	;		-
	;	Utilisées:
	;		-
	; Sous-routines:
	;	XOPENDIR
	;----------------------------------------------------------------------
	.if 0
		; TEMPORAIRE - TESTS
		.proc is_dir
				; Sortie:
				;	Z=0: si c'est un répertoire
				;	Z=1: si le répertoire n'existe pas (mais on peut
				;	     avoir un fichier)

				; opendir()
				;lda	exec_address
				;ldy	exec_address+1
				ldx	#$00
				.byte	$00, XOPENDIR

				cmp	#$ff
				bne	end
				cpx	#$ff

			end:
				; jsr	PrintRegs

				; Sauvegarde le résultat du test
				php
				; closedir()
				ldx	#$02
				.byte	$00, XOPENDIR

				plp
				rts
		.endproc
	.endif
.endproc

