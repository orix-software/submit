;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"
.include "errno.inc"
;.include "fcntl.inc"

XOPENDIR = $2f

;----------------------------------------------------------------------
;			includes SDK
;----------------------------------------------------------------------
.include "SDK.mac"
.include "types.mac"

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------
.include "macros/utils.mac"
.include "macros/SDK-ext.mac"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import save_x
.import submit_line
.import path

.import skip_spaces

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_cd

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
;	-
;----------------------------------------------------------------------
.proc cmnd_cd
		; TODO: ajouter le support de "cd -"

		jsr	skip_spaces
		beq	error

		sta	exec_address
		stx	save_x
		sty	exec_address+1

		; Ferme le fichier .sub
		;jsr	submit_close

		; opendir()
		lda	exec_address
		ldy	exec_address+1
		ldx	#$00
		.byte	$00, XOPENDIR
		cmp	#$ff
		bne	_cd
		cpx	#$ff
		beq	error

	_cd:
		; Place le fp dans AY
		pha
		txa
		tay
		pla

		; closedir()
		ldx	#$02
		.byte	$00, XOPENDIR

		; Recherche le '/*' ajouté par XOPENDIR
		; et le remplace par un $00
		jsr	restore_line

		; chdir()
		chdir	path

	end:
		; lda	#EOK
		ldx	save_x
		;jsr	submit_reopen

		clc
		rts

	error:
		; Recherche le '/*' ajouté par XOPENDIR
		; et le remplace par un $00
		jsr	restore_line

		ldx	save_x
		lda	#EINVAL
		sec
		rts

	.proc restore_line
			; Recherche le '/*' ajouté par XOPENDIR
			ldx	save_x
			dex
			ldy	#$ff
		loop:
			inx
			iny
			lda	submit_line,x
			sta	path,y
			cmp	#'*'
			bne	loop

			; et le remplace par un $00
			lda	#$00
			sta	path,y
			sta	submit_line,x

			rts
	.endproc
.endproc


