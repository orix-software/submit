;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"
.include "errno.inc"
.include "fcntl.inc"

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
.import submit_line
.import errorlevel
.import prev_fpos
.import linenum

.import ftell

.import spar1
	spar := spar1
;.import setcbp

.import PrintHexByte

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export internal_command
.export label_ofs, label_num, forward_label

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
CASE_SENSITIVE_LABELS .set 0
MAX_LABELS = 20
LABEL_TABLE_SIZE = 128
; de main.s
LINE_MAX_SIZE = 128

;----------------------------------------------------------------------
;				Page Zéro
;----------------------------------------------------------------------
.pushseg
	.segment "ZEROPAGE"
		unsigned short ptr
		unsigned short var1
		unsigned short var2
.popseg

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
		unsigned char CurCharPos
		unsigned char CurCharPos_bkp
		unsigned char InstrNum

		; pour éviter une erreur  "jmp (abs)" across page border
		unsigned char dummy
		unsigned short exec_address

		unsigned char save_a
		unsigned char save_x
		unsigned char save_y

		; Offset dans la table labels
		unsigned char label_ofs
		; Table des labels
		unsigned char labels[LABEL_TABLE_SIZE]

		unsigned char label_num
		unsigned long label_offsets[MAX_LABELS]
		unsigned short label_line[MAX_LABELS]

		unsigned char forward_label

		unsigned char save_label[20]

		unsigned char save_linenum[2]
		unsigned long prev_fpos_save
		unsigned long fpos_text_save

		; Tampon lecture du fichier (on pourrait utiliser line[] de main.s
		; Utilisé par GOTO
		unsigned char line[LINE_MAX_SIZE]

.popseg

;----------------------------------------------------------------------
;			Programme principal
;----------------------------------------------------------------------
.segment "CODE"

;----------------------------------------------------------------------
;
; Entrée:
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
.proc internal_command
		lda	submit_line,x
		cmp	#':'
		bne	find

		inx
		jmp	cmnd_label

	find:
		; Adresse de la table des commandes
		lda	#<cmnd_table
		ldy	#>cmnd_table

		clc
		jsr	find_cmnd
		bcs	not_found

		asl
		tay
		lda	cmnd_addr,y
		sta	exec_address
		lda	cmnd_addr+1,y
		sta	exec_address+1
		jsr	exec_internal_cmnd
		; lda	#EOK
		rts

	not_found:
		; jsr	PrintRegs
		lda	#ENOENT
		sec
		rts

	exec_internal_cmnd:
		jmp	(exec_address)
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	AY: Adresse de la table des commandes
;	X: Offset de la commande dans submit_line
;
; Sortie:
;	Commande trouvée:
;		C: 0
;		A: n° de la commande
;		X: index vers la caractère suivant la commande
;
;	Commande inconnue:
;		C: 1
;		A: modifié
;		X: inchangé
;	Y: modifié
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc find_cmnd
		sta	ptr
		sty	ptr+1

		; Sauvegarde le flag C
		php
		pla
		and	#$01
		ror
		sta	save_a

		; X: position du premier caractère de la commande
		; à trouver
		; Optimisations possibles si X=0
;		ldx	#$00
		lda	submit_line,x
		bne	lookup

		sec
		lda	#ENOENT
		rts

	lookup:
		stx	CurCharPos
		stx	CurCharPos_bkp

		ldx	#$00
		stx	InstrNum

		ldy	#$00

	find_string:
		ldx	CurCharPos
		lda	submit_line,x
		beq	not_found

		cmp	#' '
		bne	first_char

	not_found:
		sec
		lda	#ENOENT
		rts

	first_char:
		; lda inutile, déjà fait par find_string
		; lda	submit_line,x

.if ::CASE_SENSITIVE_LABELS
		; Conversion minuscules / majuscules si N=1
		bit	save_a
		bmi	compare
.endif

		cmp	#'a'
		bcc	compare
		cmp	#'z'+1
		bcs	compare
		sbc	#'a'-'A'-1

	compare:
		cmp	(ptr),y
		beq	next_char

		lda	(ptr),y
		bne	last_char

		sec
		lda	#ENOENT
		rts

	last_char:
		and	#$7f
		; si pas de conversion minuscules / majuscule
		; cmp	submit_line,x
		; beq	found
		; sinon
.if ::CASE_SENSITIVE_LABELS
		bit	save_a
		bpl	case_insensitive
		cmp	submit_line,x
		beq	found
		bne	last_char2
.endif
	case_insensitive:
		sec
		sbc	submit_line,x
		beq	found
		cmp	#$100-$20
		beq	found

	last_char2:
		ldx	CurCharPos_bkp
		stx	CurCharPos
;		ldy	#$00
		inc	InstrNum

	skip_string:
		lda	(ptr),y
		bmi	next_string
		iny
		jmp	skip_string

	next_string:
		iny
		jmp	find_string

	next_char:
		inc	CurCharPos
		iny
		jmp	find_string

	found:
		; Pointe vers le caractère suivant la commande
		inc	CurCharPos
		inx

		; Vérifie que le prochain caractère du buffer est bien un espace
		; ou la fin de ligne.
		; Dans le cas contraire on passe à la commande suivante.
		; Ex: buffer: cata => commande trouvée = cat => pas bon
		lda	submit_line,x
		beq	ok
		cmp	#' '
		bne	last_char2

	ok:
		lda	InstrNum
		clc
		rts
.endproc

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
.proc cmnd_at
		jsr	skip_spaces
		beq	error

		stx	save_x

		; Initialise les valeurs par défaut
		lda	#$ff
		sta	var1
		sta	var1+1

		sta	var2
		sta	var2+1

		ldy	#>submit_line
		clc
		txa
		adc	#<submit_line
		sta	save_a
		bcc	_at
		iny

		; Inverse le poids fort et le poids faible
		; il faut A=MSB et Y=LSB pour spar
	_at:
		tya
		ldy	save_a

		; jsr	setcbp

		ldx	#%10000000
		jsr	spar
		.byte	var1, var2, $00
		bcs	value_error

		; Ici AY pointe sur le caractère suivant la valeur (A=MSB)
		sta	save_a
		sty	save_y

		lda	var1+1
		bne	value_error
		lda	var2+1
		bne	value_error

		lda	var1
		cmp	#28
		bcs	value_error
		adc	#$40
		sta	var1

		lda	var2
		cmp	#40
		bcs	value_error
		adc	#$40
		sta	var2

		cputc	$1f
		lda	var1
		cputc
		lda	var2
		cputc

		; Recalcule l'offset par rapport à submit_line
		sec
		lda	save_y
		sbc	#<submit_line
		tax

;		lda	save_y
;		ldy	save_a
;		ldx	save_x

		lda	submit_line,x
		bne	echo
		clc
		rts

	echo:
		jmp	cmnd_echo
;		clc
;		rts

	value_error:
		; Recalcule l'offset par rapport à submit_line
		;sec
		;lda	save_y
		;sbc	#<submit_line
		;tax
		ldx	save_x

	error:
		lda	#ERANGE
		sec
		rts
.endproc

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
.proc cmnd_choice
		; TODO: à transformer en commande externe

		; Liste de choix par défaut
		sta	save_a

		lda	#<default_msg
		sta	ptr
		lda	#>default_msg
		sta	ptr+1

		lda	#$00
		sta	save_y

	get_params:
		lda	save_a

		; Paramètres?
		jsr	skip_spaces
		beq	disp_choices

		sta	save_a

		lda	submit_line,x
		cmp	#'-'
		bne	disp_text

		; -n?
		lda	submit_line+1,x
		cmp	#'n'
		bne	param_c
		ror	save_y
		inx
		inx
		jmp	get_params

		; -c?
	param_c:
		cmp	#'c'
		bne	disp_text

		lda	submit_line+2,x
		beq	disp_text
		cmp	#' '
		beq	disp_text

		; Un seul inx parce que loop_choices commence par un inx
		inx
		; inx

		clc
		lda	save_a
		adc	#$02
		sta	ptr
		bcc	skip
		iny
	skip:
		sty	ptr+1

	loop_choices:
		inx
		lda	submit_line,x
		beq	disp_choices
		cmp	#' '
		beq	get_params

		; Si insensible à la casse
		; Conversion minuscules / majuscules
		cmp	#'a'
		bcc	store_choice
		cmp	#'z'+1
		bcs	store_choice
		sbc	#'a'-'A'-1

	store_choice:
		sta	submit_line,x
		bne	loop_choices

		; Ajuste AY
	ajuste:
		clc
		txa
		adc	#<submit_line
		sta	save_a
		bcc	spaces
		iny

	spaces:
		jsr	skip_spaces
		beq	disp_choices
		sta	save_a

	disp_text:
		lda	save_a
		jsr	string_delim
		.byte	$00, XWSTR0
		cputc	' '

	disp_choices:
		lda	save_y
		bpl	loop_start
		jsr	count_choices
		jmp	input

	loop_start:
		cputc	'['
		ldy	#$00

	disp_loop:
		lda	(ptr),y
		cputc
		iny
		lda	(ptr),y
		beq	end_choices
		cmp	#' '
		beq	end_choices
		cputc	','
		jmp	disp_loop

	end_choices:
		sty	save_x
		cputc	']'
		cputc	'?'


	input:
		; Vide le buffer clavier
                ldx     #$00
                .byte	$00, XVIDBU
		asl	KBDCTC

		; cursor	on

	loop:
		; Initialise errorlevel
		lda	#$00
		sta	errorlevel
		sta	errorlevel+1

		cgetc
		asl	KBDCTC
		bcs	break

		; Si insensible à la casse
		; Conversion minuscules / majuscules
		cmp	#'a'
		bcc	compare
		cmp	#'z'+1
		bcs	compare
		sbc	#'a'-'A'-1

	compare:
		ldy	save_x

	compare_loop:
		dey
		bmi	loop
		cmp	(ptr),y
		bne	compare_loop

	end:
		iny
		sty	errorlevel
		cputc

	break:
		; cursor	off
		crlf

		clc
		rts

	default_msg:
		.asciiz "YN"

	.proc count_choices
			ldy	#$ff

		loop:
			iny
			lda	(ptr),y
			beq	end
			cmp	#' '
			bne	loop

		end:
			sty	save_x
			rts
	.endproc
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
.proc cmnd_cls
		cputc	$0C
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
.proc cmnd_errorlevel
		lda	errorlevel
		ldy	errorlevel+1
		ldx	#$03
		.byte	$00, XDECIM

		crlf
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

		jsr	is_dir
		beq	is_file
		lda	#$00
		php
		beq	set_error

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
.proc cmnd_exit
		lda	#$e4
		sec
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
.proc cmnd_goto
		jsr	skip_spaces
		beq	error

		stx	save_y

		; Table des labels vide?
		lda	label_num
		beq	not_found

		; Cherche dans la table des labels
		lda	#<labels
		ldy	#>labels
.if ::CASE_SENSITIVE_LABELS
		sec
.endif
		jsr	find_cmnd
		bcs	not_found

		; Récupère le numéro de la ligne
		asl
		tax
		lda	label_line,x
		sta	linenum
		lda	label_line+1,x
		sta	linenum+1,x
		txa

		; Récupère l'offset du label
		asl
		tax
		lda	label_offsets,x
		sta	fpos
		sta	fpos_text
		lda	label_offsets+1,x
		sta	fpos+1
		sta	fpos_text+1
		lda	label_offsets+2,x
		sta	fpos+2
		sta	fpos_text+2
		lda	label_offsets+3,x
		sta	fpos+3
		sta	fpos_text+3

		; Utile uniquement si fichier TEXTE
		jsr	buffer_reset

		clc
		rts

	not_found:
		; On a déjà parcouru tout le fichier?
		lda	forward_label
		bne	find_label
		sec
		lda	#ERANGE
		rts

	error:
		sec
		lda	#EINVAL
		rts

	find_label:
		; Sauvegarde la position dans le fichier
		ldx	#$03
	save_fpos:
		lda	prev_fpos,x
		sta	prev_fpos_save,x
		; Utile uniquement si fichier TEXTE
		lda	fpos_text
		sta	fpos_text_save,x
		dex
		bpl	save_fpos

		; Sauvegarde le numéro de ligne
		lda	linenum
		sta	save_linenum
		lda	linenum+1
		sta	save_linenum+1

		jsr	submit_reopen

		; Sauvegarde le label à trouver
		jsr	store_label
		bcc	loop
		rts

		; Lecture du fichier jusqu'à la fin ou jusqu'à ce qu'on trouve
		; le label
	loop:
		lda	#<line
		ldy	#>line
		ldx	#LINE_MAX_SIZE
		jsr	fgets
		bcs	eof

		; TODO: vérifier si cmnd_label accepte des ' ' avant ':'
		; On a un label?
		ldx	#$00
		lda	line,x
		cmp	#':'
		bne	loop

		; Récupère l'adresse de la ligne suivant le ':label'
		jsr	ftell

		lda	#<line
		ldy	#>line
		; On saute le ':'
		inx
		jsr	submit
		jsr	cmnd_label
		bcs	error_label
		jsr	search_label
		bcs	loop

		; On a trouvé le label, inutile de continuer la recherche
		;jsr	end
		;jmp	cmnd_goto
		jsr	submit_close
		rts

	eof:
		lda	#$00
		sta	forward_label
		jsr	end
		; Si on a vérifier le label au fur et à mesure
		jmp	not_found
		; sinon
		;pla
		;pla
		;lda	#<submit_line
		;ldy	#>submit_line
		;jmp	cmnd_goto

	end:
		jsr	submit_close

		; Restaure la position dans le fichier
		ldx	#$03
	restore_fpos:
		lda	prev_fpos_save,x
		sta	fpos,x
		; Utile uniquement si fichier TEXTE
		lda	fpos_text_save
		sta	fpos_text,x
		dex
		bpl	restore_fpos

		; Utile uniquement si fichier TEXTE
		jsr	buffer_reset

		; Recharge la ligne...
		jsr	submit_reopen
		lda	#<line
		ldy	#>line
		ldx	#LINE_MAX_SIZE
		jsr	fgets
		; bcs	error
		jsr	submit_close
		lda	#<line
		ldy	#>line
		ldx	#$00
		jsr	submit

		; ...et son numéro
		lda	save_linenum
		sta	linenum
		lda	save_linenum+1
		sta	linenum+1

		; Restaure l'offset dans la ligne
		ldx	save_y

		rts

	error_label:
		sta	save_a
		jsr	end
		lda	save_a
		sec
		rts

	.proc store_label
			ldx	save_y
			ldy	#$00
		loop:
			lda	submit_line,x
			sta	save_label,y
			beq	end
			cmp	#' '
			beq	end
			inx
			iny
			cpy	#20
			bne	loop

		oom:
			; Label trop long
			sec
			lda	#$f3
			rts

		end:
			lda	#$00
			sta	save_label,y
			clc
			rts
	.endproc

	.proc search_label
			ldx	#$ff
		loop:
			inx
			lda	save_label,x
			sta	submit_line,x
			bne	loop

			ldx	#$00
			lda	#<labels
			ldy	#>labels

	.if ::CASE_SENSITIVE_LABELS
			sec
	.endif
			jsr	find_cmnd
			rts

	.endproc
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
.proc cmnd_if
		jsr	skip_spaces
		beq	error

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

	found:
		pla
		pla
		jsr	skip_spaces
		jmp	internal_command

	if_var:
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
		lda	errorlevel+1
		cmp	var2+1
		bne	test
		lda	errorlevel
		cmp	var2

		; IF ERRORLEVEL n xxxx
		; Exécute xxx si ERRORLEVEL >= n
		; À voir pour étendre la syntaxe en autorisant un comparateur (<, =, .>)
	test:
		;beq	equal
		;bcs	sup
		bcs	sup_equal

	inf:
		;print	inf_msg
		clc
		rts

	sup_equal:
	equal:
		; print	equal_msg
		; clc
		; rts

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

	;sup:
	;	print	sup_msg
	;	clc
	;	rts

	value_error:
		; pla
		ldx	save_x
		lda	#$fe
		sec
		rts

	no_value:
		;pla
		ldx	save_x
		lda	#$ff
		sec
		rts

	error:
		sec
		lda	#EINVAL
		rts

	;inf_msg:
	;	.asciiz "inf\r\n"

	;equal_msg:
	;	.asciiz "equal\r\n"

	;sup_msg:
	;	.asciiz "sup\r\n"
.endproc

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
.proc cmnd_label
		jsr	skip_spaces
		beq	error

		stx	save_x

		; Recherche si le label est déjà dans la table
		; /!\ Si on le trouve, il faut vérifier si l'offset est le même
		;     dans ce cas il s'agit d'un doublon et il faut indiquer une
		;     erreur.
		lda	#<labels
		ldy	#>labels

.if ::CASE_SENSITIVE_LABELS
		;Case sensitive
		;sinon il faut convertir le label en majuscules dans la table
		sec
.endif
		jsr	find_cmnd
		bcc	found

		; Nombre maximal de labels atteint?
		lda	label_num
		cmp	#MAX_LABELS
		bcs	ovfError

;		clc
;		ldy	#>submit_line
;		lda	#<submit_line
;		adc	save_x
;		bcc	save_label
;		iny

	save_label:
;		sta	ptr
;		sty	ptr+1
;		ldx	#$00
		ldy	label_ofs

	loop:
		lda	submit_line, x
		beq	saved
		cmp	#' '
		beq	saved

.if .not ::CASE_SENSITIVE_LABELS
		; Conversion minuscules / majuscules
		cmp	#'a'
		bcc	store
		cmp	#'z'+1
		bcs	store
		sbc	#'a'-'A'-1
	store:
.endif
		sta	labels, y

		inx
		iny
		cpy	#$80
		bne	loop

	ovfError:
		sec
		lda	#ENOMEM
		rts

	error:
		sec
		lda	#EINVAL
		rts

	saved:
		; Dernier caractère +$80
		dey
		lda	labels, y
		ora	#$80
		sta	labels, y

		; Marque la fin de la table
		iny
		lda	#$00
		sta	labels, y

		sty	label_ofs

		; Sauvegarde le numéro de la ligne suivante du label
		lda	label_num
		asl
		tax
		lda	linenum
		sta	label_line,x
		lda	linenum+1
		sta	label_line+1,x

		; Sauvegarde l'offset de la ligne suivant le label
		txa
		asl
		tax
		lda	fpos_text
		sta	label_offsets,x
		lda	fpos_text+1
		sta	label_offsets+1,x
		lda	fpos_text+2
		sta	label_offsets+2,x
		lda	fpos_text+3
		sta	label_offsets+3,x

		inc	label_num
	end:
		clc
		rts

	found:
		asl
		asl
		tax
		lda	fpos_text
		cmp	label_offsets,x
		bne	redefined
		lda	fpos_text+1
		cmp	label_offsets+1,x
		bne	redefined
		lda	fpos_text+2
		cmp	label_offsets+2,x
		bne	redefined
		lda	fpos_text+3
		cmp	label_offsets+3,x
		bne	redefined
		clc
		rts

	redefined:
		ldx	save_x
		lda	#EEXIST
		sec
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
.proc cmnd_pause
		jsr	skip_spaces
		beq	default

		jsr	string_delim

		.byte	$00, XWSTR0
		jmp	pause

	default:
		prints	"\x1bLPress any key to continue."

	pause:
		cgetc
		prints	"\r\x0e"
		clc
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
.proc cmnd_pwd
		print	path
		clc
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
.proc cmnd_rem
		clc
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
.proc cmnd_test
		jsr	skip_spaces
		beq	end

		; Oublie le retour vers internal_command
		pla
		pla

		; Relance une recherche avec la nouvelle commande
		jmp	internal_command

	end:
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
.proc cmnd_dump
		; Affiche le num&ro de ligne
		;lda	linenum+1
		;jsr	PrintHexByte
		;lda	linenum
		;jsr	PrintHexByte
		;crlf

		lda	label_num
		beq	end

		ldx	#$00
		stx	ptr
		stx	save_x

	again:
		; Affiche la ligne du label
		lda	labels,x
		beq	end
		lda	ptr
		asl
		tax
		lda	label_line+1,x
		jsr	PrintHexByte
		lda	label_line,x
		jsr	PrintHexByte
		cputc	':'

		ldx	save_x
	loop:
		lda	labels,x
		beq	end
		bmi	last
		cputc
		inx
		bne	loop
		beq	end

	last:
		and	#$7f
		cputc
		inx
		stx	save_x


		; Affiche l'offset du label
;		lda	ptr
;		asl
;		asl
;		tax
;		lda	label_offsets+1,x
;		tay
;		lda	label_offsets, x
;		ldx	#$03
;		.byte	$00, XDECIM

		crlf

		inc	ptr
		ldx	save_x
		bne	again

	end:
		prints	"\r\nTable size: "
		lda	save_x
		ldy	#$00
		ldx	#$02
		.byte	$00, XDECIM
		cputc	'/'

		lda	#LABEL_TABLE_SIZE
		ldy	#$00
		ldx	#$02
		.byte	$00, XDECIM

		crlf

		clc
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
.proc cmnd_type
		; Alias pour cat
		jsr	skip_spaces
		beq	end

		; Ici X=offset vers le premier caractère du paramètre
		sta	exec_address

		; Remplace 'type' par 'cat '
		dex
		lda	#' '
		sta	submit_line,x
		dex
		lda	#'t'
		sta	submit_line,x
		dex
		lda	#'a'
		sta	submit_line,x
		dex
		lda	#'c'
		sta	submit_line,x

		sec
		lda	exec_address
		sbc	#$04
		bcs	cat
		dey

	cat:
		; Indique qu'il n'y a pas de commandde interne TYPE
		; jmp	external_command
		sec
		lda	#ENOENT
		rts

	end:
		; Erreur pas de paramètre
		lda	#EINVAL
		sec
		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	X: offset sur le premier caractère suivant la commande
;
; Sortie:
;	AY: Adresse premier caractère non ' '
;	X: offset vers le premier caractère non ' '
;	Z: 1 si fin de chaine
;
; Variables:
;	Modifiées:
;		- exec_address
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc skip_spaces
		dex
	loop:
		inx
		lda	submit_line,x
		beq	end
		cmp	#' '
		beq	loop

		; Charge le caractère
		; inx
		lda	submit_line,x
		php
		; dex

		; Si on veut l'adresse de la chaine dans AY
		ldy	#>submit_line

		clc
		lda	#<submit_line
		sta	exec_address
		txa
		adc	exec_address
		bcc	ok
		iny

	ok:
		plp

	end:
		rts
.endproc


;----------------------------------------------------------------------
;
; Entrée:
;	AY: adresse des arguments (submit_line)
;	X: offset sur le premier caractère suivant la commande
;
; Sortie:
;	AY: adresse de la chaine
;	X: offset vers la fin de la chaine (pointe sur le '"' final)
;
; Variables:
;	Modifiées:
;		- submit_line (place un $00 à la place du '"' final
;		- exec_address
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc string_delim
		sta	exec_address
		; sty	exec_address+1

		lda	submit_line,x
		cmp	#'"'
		bne	end

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
		bne	end
		iny

	end:
		lda	exec_address
		rts
.endproc

;----------------------------------------------------------------------
;			Chaines statiques
;----------------------------------------------------------------------
.pushseg
	.segment "RODATA"
		cmnd_table:
			string80	"@"
			; string80	"CALL"
			string80	"CD"
			string80	"CHOICE"
			string80	"CLS"
			string80	"ECHO"
			; string80	"EXIST"
			string80	"EXIT"
			string80	"GOTO"
			string80	"IF"
			; string80	"MORE"
			string80	"PAUSE"
			string80	"PWD"
			string80	"REM"
			; string80	"TEST"
			string80	"TYPE"

			string80	"DUMP"
			string80	"ERRORLEVEL"
			.byte	$00

		cmnd_addr:
			.word	cmnd_at
			; .word	cmnd_call
			.word	cmnd_cd
			.word	cmnd_choice
			.word	cmnd_cls
			.word	cmnd_echo
			; .word	cmnd_exist
			.word	cmnd_exit
			.word	cmnd_goto
			.word	cmnd_if
			; .word	cmnd_more
			.word	cmnd_pause
			.word	cmnd_pwd
			.word	cmnd_rem
			; .word	cmnd_test
			.word	cmnd_type

			.word	cmnd_dump
			.word	cmnd_errorlevel

		internal_var_table:
			string80	"EXIST"
			string80	"ERRORLEVEL"
			.byte	$00
.popseg
