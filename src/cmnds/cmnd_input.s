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
.include "../include/submit.inc"
.include "macros/readline.mac"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import skip_spaces
;.import string_delim

.import spar1
	spar := spar1
.importzp var1

.importzp object

.import vars_index
.import vars_data_index
.import keylen

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_input

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
		.segment "ZEROPAGE"
			unsigned short ptr
			unsigned short varptr

		.segment "DATA"
			unsigned char prompt[40]
			unsigned char save_x

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
;		save_a
;		save_x
;		save_y
;		var1
;		entry
;		vars_index
;		vars_data_index
;		ptr
;		varptr
;		errorlevel
;	Utilisées:
;		prompt
;		submit_line
;		keylen
; Sous-routines:
;	skip_spaces
;	get_string_delim
;	init_entry
;	var_new
;	XWSTR0
;	spar
;	cursor
;	input
;----------------------------------------------------------------------
.proc cmnd_input
		; Initialise les valeurs par défaut
		lda	#$20
		sta	var1
		lda	#$00
		sta	var1+1
		beq	suite

	error:
		lda	#EINVAL
		sec
		rts

	value_error:
		ldx	save_x
		lda	#ERANGE
		sec
		rts

	suite:
		jsr	skip_spaces
		beq	error

		jsr	get_string_delim
		stx	save_x

		lda	#<prompt
		ldy	#>prompt

		.byte	$00, XWSTR0

		ldx	save_x

		jsr	skip_spaces
		beq	error

		lda	submit_line, x
		cmp	#','
	to_nerror:
		bne	error

		inx
		jsr	skip_spaces
	to_error:
		beq	error

		sta	save_a
		stx	save_x
		sty	save_y

		; Inverse le poids fort et le poids faible
		; il faut A=MSB et Y=LSB pour spar
		lda	save_y
		ldy	save_a

		ldx	#%10100000
		jsr	spar
		.byte	var1, $00
		bcs	value_error

		; Ici AY pointe sur le caractère suivant la valeur (A=MSB)
		sta	save_y
		sty	save_a

		; Vérifie la validité de var1 (<40)
		lda	var1+1
		bne	value_error

		lda	var1
		beq	value_error
		cmp	#$20+1
		bcs	value_error

		; Recalcule l'offset par rapport à submit_line
		sec
		lda	save_a
		sbc	#<submit_line
		tax
		stx	save_x

		cursor	on
;		input	": ", var1, varptr
		input	, var1, varptr
		php
		cursor	off
		plp
;		beq	eos
		bcc	set_var
		jmp	ctrl_c

	set_var:
		jsr	init_entry

		ldx	save_x
		lda	submit_line,x
		beq	to_error
;	to_nerror2:
;		bne	to_nerror

;		inx
;
;		jsr	skip_spaces
;		beq	to_error

		stx	save_x

		; Récupère le nom de la variable
		; Après init_entry A=0, Y=$ff
;		ldx	save_x
		ldy	#$00

		dex
	loop2:
		inx
		lda	submit_line,x
		; Autorise les caractères alpha uniquement et force
		; en majuscules (à modifier)
		cmp	#'A'
		bcc	eos

		and	#$DF

		cmp	#'Z'+1
		bcs	error2

		cpy	keylen
		beq	error3

		sta	entry+st_entry::name,y
		iny
		jmp	loop2

	eos:
		cmp	#$00
		bne	error_noeol

		; Nombre maximal de variables atteint?
		lda	vars_index
		cmp	#VARS_MAX
		bcs	error4

		; Update value
		lda	#'C'
		sta	entry+st_entry::type
		lda	vars_data_index
		sta	entry+st_entry::data_ptr
		sta	ptr
		lda	vars_data_index+1
		sta	entry+st_entry::data_ptr+1
		sta	ptr+1

		ldy	#$00
	loop3:
		lda	(varptr),y
		sta	(ptr),y
		beq	eov
		cpy	#VARS_DATALEN
		beq	error5
		iny
		jmp	loop3

	eov:
		sty	entry+st_entry::len
		jsr	var_new
		bne	error6

		inc	vars_index

		clc
		lda	#VARS_DATALEN
		adc	vars_data_index
		sta	vars_data_index
		lda	#$00
		adc	vars_data_index+1
		sta	vars_data_index+1

		lda	entry+st_entry::len
		bne	end

		lda	#$01
		sta	errorlevel
		bne	errorlevel_msb

	end:
		lda	#$00
		sta	errorlevel

	errorlevel_msb:
		lda	#$00
		sta	errorlevel+1

		clc
		rts

	ctrl_c:
		lda	#$02
		sta	errorlevel
		bne	errorlevel_msb

	error6:
		; Set ERRORLEVEL = 6 (pb ajout variable dans la table)
		lda	#$06
		bne	set_errorlevel

	error_noeol:
		lda	#EINVAL
		sec
		rts

	error2:
		; caractère incorrecte dans le nom de la variable)
		lda	#$02
		bne	set_errorlevel

	error3:
		; Set ERRORLEVEL = 3 (nom de variable trop long)
		lda	#$03
		bne	set_errorlevel

	error4:
		; Set ERRORLEVEL = 4 (nombre maximal de variables atteint)
		; TODO: Remonter une erreur fatale?
		lda	#$04
		bne	set_errorlevel

	error5:
		; Set ERRORLEVEL = 5 (chaine trop longue)
		lda	#$05

	set_errorlevel:
		sta	errorlevel
		lda	#$00
		sta	errorlevel+1
		sec
		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	AY: adresse des arguments (submit_line)
;	X: offset sur le premier caractère suivant la commande
;
; Sortie:
;	Z: 1-> chaine vide
;	A: Longueur de la chaine
;	X: offset vers la fin de la chaine (pointe après le '"' final)
;
; Variables:
;	Modifiées:
;		- prompt
;		- exec_address
;	Utilisées:
;		submit_line
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc get_string_delim
		; Chaine vide
		lda	#$00
		sta	prompt

		lda	submit_line,x
		cmp	#'"'
		bne	end

		ldy	#$ff
	loop:
		iny
		; /!\ Attention si X revient à 0 (normalement impossible)
		inx
		lda	submit_line,x
		sta	prompt,y
		beq	loop_end
		cmp	#'"'
		bne	loop

		lda	#$00
		sta	prompt,y

		inx

	loop_end:


;		ldy	exec_address+1
;
;		; Saute le dernier '"'
;		inc	exec_address
;		bne	end
;		iny

	end:
;		lda	exec_address
		tya
		rts
.endproc

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
.proc get_int
.endproc

