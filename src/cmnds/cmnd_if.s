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
.importzp var1, var2
.import save_a, save_x, save_y
.importzp ptr

.import fp

.import submit_line, line
.import internal_var_table
.import vartab

.import skip_spaces
.import internal_command

.import spar1
	spar := spar1

;.import var_getvalue
;.importzp object
.import find_var
.import entry

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_if

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

.if 0
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
.proc cmnd_if
		jsr	skip_spaces
		beq	error

		; if "string1" = "string2"?
		sta	save_a
		lda	submit_line,x
		cmp	#'"'
		bne	if_value
		jsr	if_string
		bcs	error
		beq	found
		; Équivalent à bne false
		; le clc est inutile ici
		; clc
		rts

	if_value:
		; Initialise la valeur de test par défaut
		lda	#$00
		sta	var2
		sta	var2+1

		lda	#<internal_var_table
		ldy	#>internal_var_table
		clc
		jsr	find_cmnd
		bcs	error

		; A: indice de la variable interne
		; (EXIST = pseudo variable 0)
		;pha
		bne	if_var

		; if exist <file> <instruction>
	if_exist:
		jsr	cmnd_exist
		bcs	error
		lda	var1
		beq	found
		clc
		rts

	error:
		sec
		lda	#EINVAL
		rts

	no_value:
		;pla
		ldx	save_x
		lda	#$ff
		sec
		rts

	found:
		pla
		pla
		jsr	skip_spaces
		jmp	internal_command

	if_var:
		; Récupère la valeur de la variable
		; On arrive ici avec C=0
		sbc	#$00
		asl
		tay
		lda	vartab,y
		sta	var1
		lda	vartab+1,y
		sta	var1+1

		; if <variable> <value> <instruction>
		; Saute les espaces
		jsr	skip_spaces
		; Sauvegarde l'offset dans submit_line
		stx	save_x
		beq	no_value


		ldy	#>submit_line
		clc
		txa
		adc	#<submit_line
		sta	save_a
		bcc	_if
		iny

	_if:
		; Inverse le poids fort et le poids faible
		; il faut A=MSB et Y=LSB pour setcbp
		tya
		ldy	save_a

		; jsr	setcbp

		; Ajout comparateur
		sty	ptr
		sta	ptr+1

		; <: 60 -> 1	-> 3C 0011 11 00
		; =: 61 -> 2	-> 3D 0011 11 01
		; >: 62 -> 4	-> 3E 0011 11 10
		; Par défaut: >=
		lda	#($02 | $04)
		sta	cmp_op

		ldy	#$00
		lda	(ptr),y
		ldx	#($01|$04)
		cmp	#'#'
		beq	ok
		cmp	#'0'
		bcc	error
		cmp	#'9'+1
		bcc	num

		cmp	#'>'+1
		bcs	error
		ldx	#$01
		cmp	#'<'
		bcc	error
		beq	ok
		ldx	#$02
		cmp	#'='
		beq	ok
		ldx	#$04
		cmp	#'>'
		bne	error
	ok:
		stx	cmp_op
		inc	ptr
		bne	num
		inc	ptr+1

	num:
		ldy	ptr
		lda	ptr+1
		; Fin ajout


		ldx	#%10000000
		jsr	spar
		.byte	var2, $00
		bcs	value_error

		; Ici AY pointe sur le caractère suivant la valeur (A=MSB)
		sta	save_a
		sty	save_y

	compare:

		; Il faudrait utiliser l'indice de la variable interne pour
		; faire la comparaison
		lda	var1+1
		cmp	var2+1
		bne	test
		lda	var1
		cmp	var2

		; IF ERRORLEVEL n xxxx
		; Exécute xxx si ERRORLEVEL >= n
		; À voir pour étendre la syntaxe en autorisant un comparateur (<, =, .>)
	test:
		php
		lda	cmp_op
		plp
		beq	eq
		bcs	gt

	lt:
		and	#$01
		bne	true

	false:
		clc
		rts

	sup_equal:
	eq:
		and	#$02
		beq	false
		bne	true

	gt:
		and	#$04
		beq	false

	true:
		; Recalcule l'offset par rapport à submit_line
		sec
		lda	save_y
		sbc	#<submit_line
		tax

		; Oublie le retour vers internal_command
		pla
		pla

		; Relance une recherche avec la nouvelle commande
		jmp	internal_command

	value_error:
		; pla
		ldx	save_x
		lda	#$fe
		sec
		rts
.endproc
.else
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
;		var2
;		ptr
;		cmp_op
;	Utilisées:
;		submit_line
;		entry
; Sous-routines:
;	skip_spaces
;	if_string
;	find_var
;	cmnd_exist
;	internal_command
;	spar
;----------------------------------------------------------------------
.proc cmnd_if
		jsr	skip_spaces
		beq	error

		; if "string1" = "string2"?
		sta	save_a
		lda	submit_line,x
		cmp	#'"'
		bne	if_value
		jsr	if_string
		bcs	error
		beq	found
		; Équivalent à bne false
		; le clc est inutile ici
		; clc
		rts

	if_value:
		; Initialise la valeur de test par défaut
		lda	#$00
		sta	var2
		sta	var2+1

		; Sauvegarde X en cas d'erreur
		stx	save_x
		; Recherche la variable
		jsr	find_var
		bcs	error_x

		; A: indice de la variable interne
		; (EXIST = pseudo variable 0)
		;pha
		cmp	#$00
		bne	if_var

		; if exist <file> <instruction>
	if_exist:
		jsr	cmnd_exist
		bcs	error
		lda	var1
		beq	found
		clc
		rts

	error_x:
		; Restaure X, sinon on indique une erreur à la fin du nom
		; de la variable et non au début
		ldx	save_x

	error:
		sec
		lda	#EINVAL
		rts

	no_value:
		;pla
		ldx	save_x
		lda	#$ff
		sec
		rts

	found:
		pla
		pla
		jsr	skip_spaces
		jmp	internal_command


	if_var:
		; Récupère sa valeur
		lda	entry+st_entry::data_ptr
		ldy	entry+st_entry::data_ptr+1
		sta	var1
		sty	var1+1

	; À partir d'ici, le reste est identique

		; if <variable> <value> <instruction>
		; Saute les espaces
		jsr	skip_spaces

		; Sauvegarde l'offset dans submit_line
		stx	save_x
		beq	no_value

		ldy	#>submit_line
		clc
		txa
		adc	#<submit_line
		sta	save_a
		bcc	_if
		iny

	_if:
		; Inverse le poids fort et le poids faible
		; il faut A=MSB et Y=LSB pour setcbp
		tya
		ldy	save_a

		; jsr	setcbp

		; Ajout comparateur
		sty	ptr
		sta	ptr+1

		; <: 60 -> 1	-> 3C 0011 11 00
		; =: 61 -> 2	-> 3D 0011 11 01
		; >: 62 -> 4	-> 3E 0011 11 10
		; Par défaut: >=
		lda	#($02 | $04)
		sta	cmp_op

		ldy	#$00
		lda	(ptr),y

		ldx	#($01|$04)
		cmp	#'#'
		beq	ok

		cmp	#'0'
		bcc	error

		cmp	#'9'+1
		bcc	num

		cmp	#'>'+1
		bcs	error

		ldx	#$01
		cmp	#'<'
		bcc	error

		beq	ok

		ldx	#$02
		cmp	#'='
		beq	ok

		ldx	#$04
		cmp	#'>'
		bne	error

	ok:
		stx	cmp_op
		inc	ptr
		bne	num
		inc	ptr+1

	num:
		ldy	ptr
		lda	ptr+1
		; Fin ajout


		ldx	#%10000000
		jsr	spar
		.byte	var2, $00
		bcs	value_error

		; Ici AY pointe sur le caractère suivant la valeur (A=MSB)
		sta	save_a
		sty	save_y

	compare:

		; Il faudrait utiliser l'indice de la variable interne pour
		; faire la comparaison
		lda	var1+1
		cmp	var2+1
		bne	test
		lda	var1
		cmp	var2

		; IF ERRORLEVEL n xxxx
		; Exécute xxx si ERRORLEVEL >= n
		; À voir pour étendre la syntaxe en autorisant un comparateur (<, =, .>)
	test:
		php
		lda	cmp_op
		plp
		beq	eq
		bcs	gt

	lt:
		and	#$01
		bne	true

	false:
		clc
		rts

	sup_equal:
	eq:
		and	#$02
		beq	false
		bne	true

	gt:
		and	#$04
		beq	false

	true:
		; Recalcule l'offset par rapport à submit_line
		sec
		lda	save_y
		sbc	#<submit_line
		tax

		; Oublie le retour vers internal_command
		pla
		pla

		; Relance une recherche avec la nouvelle commande
		jmp	internal_command

	value_error:
		; pla
		ldx	save_x
		lda	#$fe
		sec
		rts
.endproc
.endif

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
.endproc


;----------------------------------------------------------------------
; TODO: ajouter test '#'
;
; Entrée:
;	X: offset sur le premier "
;
; Sortie:
;	C: 1-> erreur de syntaxe
;	Z: 1-> string1 = string2
;	Z: 0-> string1 != string2
;
; Variables:
;	Modifiées:
;		save_a
;		save_x
;		var1
;		var2
;
;	Utilisées:
;		- submit_line
; Sous-routines:
;	- string_delim
;	- skip_spaces
;----------------------------------------------------------------------
.proc if_string
		; Pointeur vers le début de la chaîne (après le ")
		stx	save_x
		inc	save_x

		lda	save_a
		jsr	string_delim
		; AY = Adresse de la chaine terminée par un \0
		; X  = Offset vers le \0
		sta	var1
		sty	var1+1

		; Remet le '"' à la fin de la chaîne (pour affichage de la ligne
		; en cas d'erreur)
		lda	#'"'
		sta	submit_line,x

		; Calcul de la longueur de la chaine
		sec
		txa
		sbc	save_x
		sta	var2+1

		; Fin de ligne?
		inx
		jsr	skip_spaces
		beq	error

		; '='?
		sta	save_a
		lda	submit_line,x
		ldy	#$02
		cmp	#'='
		beq	ok

		ldy	#($01|$04)
		cmp	#'#'
		bne	error

	ok:
		sty	cmp_op
		; "string2"
		inx
		lda	save_a
		jsr	skip_spaces
		beq	error

		sta	save_a
		lda	submit_line,x
		cmp	#'"'
		bne	error
		; Pointeur vers le début de la chaîne (après le ")
		stx	save_x
		inc	save_x

		lda	save_a
		jsr	string_delim
		; Sauvegarde poids faible de string2
		sta	var2

		; Remet le '"' à la fin de la chaîne (pour affichage de la ligne
		; en cas d'erreur)
		lda	#'"'
		sta	submit_line,x

		; Ajuste X pour pointer après string2
		inx
		; Calcul de la longueur de la chaine
		; (faire clc et non sec à cause du inx juste au dessus)
		;sec
		clc
		txa
		sbc	save_x
		; Même longueur que string1?
		cmp	var2+1
		bne	string_neq

	string_cmp:
		; Sauvegarde poids fort de string2
		sty	var2+1

		; Sauvegarde la longueur des chaines
		tay

;		; Ajuste X pour pointer après string2
;		inx

	string_loop:
		dey
		bmi	string_eq
		lda	(var1),y
		cmp	(var2),y
		beq	string_loop

	string_neq:
		; Si on arrive ici -> Z=0
		; Inversion si pas '='
		lda	cmp_op
		and	#$02			; =
		clc
		rts

	string_eq:
		; On peut arriver ici via le bmi string_eq
		; donc on force Z=1
;		iny
		; Inversion si '#'
		lda	cmp_op
		and	#($01|$04)		; #
		clc
		rts

	error:
		sec
		rts
.endproc

