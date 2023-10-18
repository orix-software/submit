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
;.include "macros/SDK-ext.mac"
.include "../include/submit.inc"

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
.import push
.import pop

; From fgets
.import buffer_reset

.importzp object

.import vars_index
.import vars_data_index

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
; Pour submit_reopen / submit_close dans fgets
.export f_restore

.export cmnd_restore
.export cmnd_save
.export init_entry

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "ZEROPAGE"
		unsigned short ptr

	.segment "DATA"
		unsigned char filename[64]
		unsigned short fp
		unsigned short line_len
		unsigned char num_buffer[10]
		unsigned char ident_buffer[ident_len+1]

		; Flag pour empecher submit_reopen / submit_close
		; de ré-ouvrir le script pendant la lecture avec fgets
		unsigned char f_restore
.popseg

;----------------------------------------------------------------------
;			Chaines statiques
;----------------------------------------------------------------------
.pushseg
	.segment "RODATA"
		from:
			string80	"FROM"
			.byte	$00

		to:
			string80	"TO"
			.byte	$00

		equal_str:
			.byte	" = "
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
;		save_x
;		errorlevel
;		filename
;		fp
;		line
;		entry
;		vars_index
;		vars_data_index
;		ptr
;	Utilisées:
;		from
;		submit_line
;		keylen
; Sous-routines:
;	skip_spaces
;	_skip_spaces
;	find_cmnd
;	push
;	buffer_reset
;	init_entry
;	fopen
;	fgets
;	fclose
;----------------------------------------------------------------------
.proc cmnd_restore
		jsr	skip_spaces
		bne	cont

	no_filename:
	no_from:
	error:
		; Erreur de syntaxe
		lda	#$ff
		sec
		rts

	error_open:
		; À voir si on se contente de modifier ERRORLEVEL
		; ou si il faut remonter une erreur au niveau de submit
		; Modifier aussi la variable EXIST?

		; Erreur ouverture de fichier
		; Set ERRORLEVEL = 1
		lda	#$01
		sta	errorlevel
		lda	#$00
		sta	errorlevel+1
		clc

		;ldx	save_x
		;lda	#$fe
		;sec
		rts

	error_push:
		rts

	cont:
		lda	#<from
		ldy	#>from
		clc
		jsr	find_cmnd
		bcs	no_from

		jsr	skip_spaces
		stx	save_x
		beq	no_filename

		ldy	#$00
	loop:
		lda	submit_line,x
		sta	filename,y

		beq	restore
		; TODO: Vérifier la validité des caractères
		cmp	#' '
		beq	restore

		inx
		iny
		cpy	#64
		bne	loop

	oom:
		; Label trop long
		sec
		lda	#$f3
		rts

	restore:
		lda	#$00
		sta	filename,y

		jsr	push
		bcs	error_push

		fopen	filename, O_RDONLY
		sta	fp
		stx	fp+1
		eor	fp+1
		beq	error_open

		; indique cmnd_restore en cours pour submit_reopen dans fgets
		; (f_restore non nul)
		sta	f_restore

		; Initilaise les pointeurs de lecture
		jsr	buffer_reset

	getline:
		lda	#<line
		ldy	#>line
		ldx	LINE_MAX_SIZE
		jsr	fgets

		; Fin de fichier?
		bcs	eof

		; Ligne vide?
		beq	getline

	get_variable:
		ldx	#$ff
		jsr	_skip_spaces

		; Commentaire?
		cmp	#';'
		beq	getline

		cmp	#'#'
		beq	getline

		; Après init_entry A=0, Y=$ff
		jsr	init_entry
		tay

		dex
	loop2:
		inx
		lda	line,x
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
		; Code suivant inutile, entry a été initialisé à 0
		;pha
		;lda	#$00
		;sta	entry+st_entry::name,y
		;pla

		cmp	#' '
		bne	equal

		jsr	_skip_spaces

	equal:
		cmp	#'='
		bne	error2

		jsr	_skip_spaces

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
		lda	line,x
		sta	(ptr),y
		beq	eov
		cpy	#VARS_DATALEN
		beq	error5
		inx
		iny
		jmp	loop3

	eof:
		fclose	(fp)
		jsr	pop
		lda	#$00
		; Set ERRORLEVEL = 0
		sta	errorlevel
		sta	errorlevel+1
		; Signale la fin de cmnd_restore pour submit_reopen dans fgets
		sta	f_restore
		rts

	error2:
		; Debug
;		stx	save_a
;		print	line
;		crlf
;		ldx	save_a
;	loop3:
;		cputc	' '
;		dex
;		bne	loop3
;		cputc	'^'
;		crlf

		; Set ERRORLEVEL = 2 (caractère '=' non trouvé ou
		; caractère incorrecte dans le nom de la variable)
		lda	#$02
		bne	set_errorlevel

	error3:
		; Set ERRORLEVEL = 3 (nom de variable trop long)
		lda	#$03
		bne	set_errorlevel

	eov:
		sty	entry+st_entry::len
		; On vérifie qu'on n'essaye pas d'écraser une variable système
		jsr	var_search
		bne	add_var

		; 3 = nombre de variables réservées
		cmp	#$03
		bcc	error3

	add_var:
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
		jmp	getline

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
		; Signale la fin de cmnd_restore pour submit_reopend ans fgets
		sta	f_restore

		fclose	(fp)

		jsr	pop
		ldx	save_x
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
;		save_x
;		errorlevel
;		filename
;		fp
;	Utilisées:
;		to
;		save_entry
; Sous-routines:
;	skip_spaces
;	find_cmnd
;	var_set_callback
;	var_list
;	fopen
;	fclose
;----------------------------------------------------------------------
.proc cmnd_save
	; identique à cmnd_restore
	; [
		jsr	skip_spaces
		bne	cont

	no_filename:
	no_to:
	error:
		; Erreur de syntaxe
		lda	#$ff
		sec
		rts

	error_open:
		; À voir si on se contente de modifier ERRORLEVEL
		; ou si il faut remonter une erreur au niveau de submit
		; Modifier aussi la variable EXIST?

		; Erreur ouverture de fichier
		; Set ERRORLEVEL = 1
		lda	#$01
		sta	errorlevel
		lda	#$00
		sta	errorlevel+1
		clc

		;ldx	save_x
		;lda	#$fe
		;sec
		rts

	error_push:
		rts

	cont:
		lda	#<to
		ldy	#>to
		clc
		jsr	find_cmnd
		bcs	no_to

		jsr	skip_spaces
		stx	save_x
		beq	no_filename

		ldy	#$00
	loop:
		lda	submit_line,x
		sta	filename,y

		beq	save
		; TODO: Vérifier la validité des caractères
		cmp	#' '
		beq	save

		inx
		iny
		cpy	#64
		bne	loop

	oom:
		; Label trop long
		sec
		lda	#$f3
		rts

	save:
		lda	#$00
		sta	filename,y

	; ]
		fopen	filename, O_WRONLY | O_CREAT
		sta	fp
		stx	fp+1
		eor	fp+1
		beq	error_open

		lda	#<save_entry
		ldy	#>save_entry
		jsr	var_set_callback

		jsr	var_list

		php
		fclose	(fp)
		ldx	save_x

		plp
		bne	error_write

		clc
		rts

	error_write:
		sec
		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	A: index de la variable
;	object: pointeur vers la variable
;
; Sortie:
;	-
;
; Variables:
;	Modifiées:
;		line_len
;		ident_buffer
;		ptr
;		TR5-TR6
;		num_buffer
;	Utilisées:
;		object
;		fp
;		equal_str
;		DEFAFF
;		TR4
; Sous-routines:
;	fwrite
;	xbindx
;----------------------------------------------------------------------
.proc save_entry
		; On saute les variables système
		cmp	#$03
		bcs	save
		rts

	save:
		; Calcul de la longueur du nom
		; et conversion en minuscules
		ldy	#$00
		sty	line_len+1
	loop:
		lda	(object),y
		sta	ident_buffer,y
		beq	write_name
		cmp	#'A'
		bcc	next
		cmp	#'Z'+1
		bcs	next
		ora	#'a'-'A'
		sta	ident_buffer,y
	next:
		iny
		bne	loop

	write_name:
		sty	line_len

		; Ecris le nom de la variable
		;fwrite	(object), (line_len), 1, fp
		fwrite	ident_buffer, (line_len), 1, fp
		cmp	line_len
		bne	to_err_write
		cpx	line_len+1
		bne	to_err_write

		; Ecris " = "
		fwrite	equal_str, 3, 1, fp
		cmp	#$03
		bne	to_err_write

		; Récupère la valeur
		ldy	#st_entry::data_ptr
		lda	(object),y
		sta	ptr
		iny
		lda	(object),y
		sta	ptr+1

		ldy	#st_entry::type
		lda	(object),y
		cmp	#'C'
		bne	numeric

		ldy	#st_entry::len
		lda	(object),y
		beq	end
		sta	line_len
		lda	#$00
		sta	line_len+1

		; Ecris la valeur
		fwrite	(ptr), (line_len), 1, fp
		cmp	line_len
		bne	err_write
		cpx	line_len+1
	to_err_write:
		bne	err_write

	eol:
		; Fin de ligne
		lda	#$0a
		sta	ptr
		fwrite	ptr, 1, 1, fp
		cmp	#$01
		bne	err_write

	end:
		rts

	numeric:
		; Pas de justification des nombres
		; /!\ ne fonctionne pas avec XBINDX qui va mettre des \00
		lda	DEFAFF
		sta	line_len
		lda	#$00
		sta	DEFAFF

		; Conversion en ASCII
		lda	#<num_buffer
		ldy	#>num_buffer
		sta	TR5
		sty	TR5+1
		lda	ptr
		ldy	ptr+1
		ldx	#$03
		jsr	xbindx

		; Nombre de caractères du nombre dans TR4 (ou Y+1)
		lda	TR4
		sta	line_len
		lda	#$00
		sta	line_len+1

		; Ecris la valeur
		fwrite	num_buffer, (line_len), 1, fp

		; Restaure le caractère de justification
		ldx	line_len
		stx	DEFAFF

		cmp	TR4
		beq	eol

	err_write:
		; Oublie l'adresse de retour vers var_list
		pla
		pla

		; Indique une erreur
		lda	#$ff
		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	X: offset sur le premier caractère suivant la commande
;
; Sortie:
;	X: offset vers le caractère suivant ' '
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		line
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc _skip_spaces
	loop:
		inx
		lda	line,x
		cmp	#' '
		beq	loop

		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	X: offset sur le premier caractère suivant la commande
;
; Sortie:
;	A: 0
;	Y: $ff
;	X: inchangé
;
; Variables:
;	Modifiées:
;		entry
;		object
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc init_entry
		; Initialise object
		lda	#<entry
		ldy	#>entry
		sta	object
		sty	object+1

		; Initialise entry
		lda	#$00
		ldy	#ENTRY_LEN-1
	loop:
		sta	entry,y
		dey
		bpl	loop

		rts
.endproc
