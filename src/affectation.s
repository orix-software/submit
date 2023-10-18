;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"
.include "fcntl.inc"
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
.include "include/submit.inc"

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
;.importzp ptr

.import save_a, save_x, save_y
.import submit_line
.import error_level

.import skip_spaces
.import line

; From cmnd_call
;.import push
;.import pop

; From fgets
;.import buffer_reset

.importzp object

.import vars_index
.import vars_data_index

.import init_entry
.import keylen

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export affectation

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "ZEROPAGE"
		unsigned short ptr

	.segment "DATA"
.popseg

;----------------------------------------------------------------------
;			Chaines statiques
;----------------------------------------------------------------------
.pushseg
	.segment "RODATA"
.popseg

;----------------------------------------------------------------------
;			Programme principal
;----------------------------------------------------------------------
.segment "CODE"

;----------------------------------------------------------------------
;
; Entrée:
;	X: offset sur le premier caractère de l'identifiant
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
.proc affectation
		stx	save_x

		; Après init_entry A=0, Y=$ff
		jsr	init_entry
		tay

		dex

		; Uniquement des caractères alpha pour le moment
		; + conversion minuscules/MAJUSCULES
	loop:
		inx
		lda	submit_line,x
		cmp	#'A'
		bcc	eos
		and	#$df
		cmp	#'Z'+1
		bcs	error2

		cpy	keylen
		beq	error3

		sta	entry+st_entry::name,y
		iny
		jmp	loop

	eos:
		cmp	#' '
		bne	_equal
		jsr	skip_spaces
		lda	submit_line,x

	_equal:
		cmp	#'='
		beq	store

;		inx
;
;		jsr	skip_spaces

		; Nombre maximal de variables atteint?
;		lda	vars_index
;		cmp	#VARS_MAX
;		bcs	error4

		; Update value
;		lda	#'C'
;		sta	entry+st_entry::type
;		lda	vars_data_index
;		sta	entry+st_entry::data_ptr
;		sta	ptr
;		lda	vars_data_index+1
;		sta	entry+st_entry::data_ptr+1
;		sta	ptr+1

;		; Délimiteur
;		lda	#$00
;		sta	save_a
;
;		lda	submit_line,x
;		cmp	#'"'
;		beq	set_delim
;		cmp	#'''
;		bne	get_val
;	set_delim:
;		sta	save_a
;		inx
;
;	get_val:
;		ldy	#$00
;
;	loop3:
;		lda	submit_line,x
;		sta	(ptr),y
;
;		beq	eov
;		cmp	save_a
;		beq	eov
;
;		cpy	#VARS_DATALEN
;		beq	error5
;
;		inx
;		iny
;		jmp	loop3

	error2:
		; Set ERRORLEVEL = 2 (caractère '=' non trouvé ou
		; caractère incorrecte dans le nom de la variable)
		ldx	save_x
		lda	#ENOENT
		sec
		rts

	error6:
		; Set ERRORLEVEL = 6 (pb ajout variable dans la table)
		lda	#$06
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

		;ldx	save_x
		;clc
		;rts

	error:
		sec
		rts

	error3:
		; Set ERRORLEVEL = 3 (nom de variable trop long)
		lda	#$03
		bne	set_errorlevel

;	eov:
;		; Ajoute \00 à la fin de la chaine
;		lda	#$00
;		sta	(ptr),y
;
;		sty	entry+st_entry::len
		; On vérifie qu'on n'essaye pas d'écraser une variable système
	store:
		jsr	var_search
		bne	add_var

		; 3 = nombre de variables réservées
		cmp	#$03
		bcc	error3

		jsr	var_getvalue
		beq	found

	add_var:
		; Nombre maximal de variables atteint?
		lda	vars_index
		cmp	#VARS_MAX
		bcs	error4

		; On met à jour le type...
		lda	#'C'
		sta	entry+st_entry::type

		; ... et data_ptr
		lda	vars_data_index
		sta	entry+st_entry::data_ptr
		lda	vars_data_index+1
		sta	entry+st_entry::data_ptr+1

		; Mise à jour des pointeurs
		inc	vars_index

		clc
		lda	#VARS_DATALEN
		adc	vars_data_index
		sta	vars_data_index
		lda	#$00
		adc	vars_data_index+1
		sta	vars_data_index+1

	found:
		lda	entry+st_entry::data_ptr
		sta	ptr
		lda	entry+st_entry::data_ptr+1
		sta	ptr+1

	update_var:
		; Délimiteur
		lda	#$00
		sta	save_a

		inx

		jsr	skip_spaces

		lda	submit_line,x
		cmp	#'"'
		beq	set_delim
		cmp	#'''
		bne	get_val
	set_delim:
		sta	save_a
		inx

	get_val:
		ldy	#$00

	loop3:
		lda	submit_line,x
		sta	(ptr),y

		beq	eov
		cmp	save_a
		beq	eov

		cpy	#VARS_DATALEN
		beq	error5

		inx
		iny
		jmp	loop3

	eov:
		; Ajoute \00 à la fin de la chaine
		lda	#$00
		sta	(ptr),y

		sty	entry+st_entry::len

		jsr	var_new
		beq	end
		jmp	error6
	end:
		clc
		rts

;	error6:
;		; Set ERRORLEVEL = 6 (pb ajout variable dans la table)
;		lda	#$06
;		bne	set_errorlevel
;
;	error4:
;		; Set ERRORLEVEL = 4 (nombre maximal de variables atteint)
;		; TODO: Remonter une erreur fatale?
;		lda	#$04
;		bne	set_errorlevel
;
;	error5:
;		; Set ERRORLEVEL = 5 (chaine trop longue)
;		lda	#$05
;
;	set_errorlevel:
;		sta	errorlevel
;		lda	#$00
;		sta	errorlevel+1
;
;		;ldx	save_x
;		;clc
;		;rts
;
;	error:
;		sec
;		rts
.endproc

