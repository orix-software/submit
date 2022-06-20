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
.include "macros/SDK-ext.mac"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import save_a, save_y
.import submit_line

.import skip_spaces
.import string_delim

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_echo

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
;		-
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc cmnd_echo
		; Prendre en compte un paramètre ON|OFF
		; Prendre en compre une redirection vers un fichier?


		; Pas de flag -n par défaut
		clc
		ror	save_y

		; Aucun paramètre -> crlf
		jsr	skip_spaces
		beq	_crlf

		sta	save_a

		lda	submit_line,x
		cmp	#'-'
		bne	_echo

		; -n?
		lda	submit_line+1,x
		cmp	#'n'
		bne	_echo
		ror	save_y
		inx
		inx

		; Rien à afficher et -n -> fin
		jsr	skip_spaces
		beq	end

		sta	save_a

	_echo:
		lda	save_a
		jsr	string_delim
.if 0
		sta	exec_address
		; sty	exec_address+1

		lda	submit_line,x
		cmp	#'"'
		bne	echo

	loop:
		; /!\ Attention si X revient à 0 (normalement impossible)
		inx
		lda	submit_line,x
		beq	loop_end
		cmp	#'"'
		bne	loop

		; Remplace le '"' terminal par un $00 pour le print
		; /!\ On suppose qu'il n'y a plus rien après le '"'
		;     (pas de redirection par exemple)
		lda	#$00
		sta	submit_line, x

	loop_end:
		; Saute le premier '"'
		inc	exec_address
		bne	echo
		iny

	echo:
.endif
;		lda	exec_address
		.byte	$00, XWSTR0

	;end:
		bit	save_y
		bmi	end

	_crlf:
		crlf

	end:
		; lda	#EOK
		clc
		rts

.endproc

