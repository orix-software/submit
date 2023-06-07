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

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------
.include "macros/SDK-ext.mac"
.include "include/submit.inc"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
;.import PrintHexByte

;.import fgets
;.import linenum
.import filename

;.importzp cwd
;.importzp file_pwd
.import submit_path

; Pour la gestion des variables
;.importzp var1, var2

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
;.export fpos

; Pour fopen, fclose
.import fp

;.export _argv, _argc
.export submit_line

.export submit
.export submit_close
.export submit_reopen

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
PARAM_PREFIX = '$'
CTRL_PREFIX = '^'

;----------------------------------------------------------------------
;				Page Zéro
;----------------------------------------------------------------------
.pushseg
	.segment "ZEROPAGE"
		;unsigned char active_bank

		unsigned short address
		unsigned short argn
.popseg

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"

		; Tampon lecture du fichier
		unsigned char submit_line[SUBMIT_LINE_MAX_SIZE]

		unsigned char save_x
.popseg

;----------------------------------------------------------------------
;			Programme principal
;----------------------------------------------------------------------
.segment "CODE"

;----------------------------------------------------------------------
;
; Entrée:
;	AY: adresse de la ligne
;	X : offset vers le premier caractère non ' '
;
; Sortie:
;	X: offset vers le premier caractère non ' '
;
; Variables:
;       Modifiées:
;		save_x
;               address
;		submit_line
;       Utilisées:
;               _argc
;		argn
; Sous-routines:
;       submit_variable
;----------------------------------------------------------------------
.proc submit
		clc
		sta	address
		txa
		adc	address
		sta	address
		bcc	store_msb

		iny
	store_msb:
		sty	address+1

;		lda	#<submit_line
;		ldy	#>submit_line

;		sta	ptr
;		sty	ptr+1

		ldx	#$00
		stx	save_x

	loop:
		ldy	#$00
		lda	(address),y
		bne	suite

		sta	submit_line,x
		; Si ECHO ON
		; print	submit_line
		; crlf

		ldx	#$ff
	skip:
		inx
		lda	submit_line,x
		beq	end

		cmp	#' '
		beq	skip

	end:
		lda	submit_line,x
		clc
		rts

	suite:
		; $<c>
		cmp	#PARAM_PREFIX
		bne	ctrl

		iny
		lda	(address),y
		beq	eof

		; $$ -> $
		cmp	#PARAM_PREFIX
		bne	parametre

		sta	submit_line,x
		inx
		jmp	add2

	parametre:
		jsr	submit_variable
		bcc	loop

		; $0 - $9 -> paramètres n
		; $<autre> -> <autre>
		;
		; /?\ renvoyer vers error ou add2 au lieu de incr?
		; /?\ prendre en compte des variables?
		cmp	#'0'
		bcc	incr

		cmp	#'9'+1
		bcs	incr
		; C=0
		sbc	#'0'-1-1

		cmp	_argc
		bcs	add2

		stx	save_x
		tax

;		getmainarg X, (_argv), argn
; [
		jsr	_get_argv
		sta	argn
		sty	argn+1
; ]
;		print	(argn)

		ldx	save_x
		ldy	#$00
	_strcat:
		lda	(argn),y
		sta	submit_line,x
		beq	add2
		inx
		iny
		bne	_strcat

	add2:
		inc	address
		bne	incr
		inc	address+1
		beq	error
	incr:
		inc	address
		bne	loop
		inc	address+1
		bne	loop

	error:
		lda	#$00
		sta	submit_line,x
		lda	#$e3
		sec
		rts

	ctrl:
		; ^<c>
		cmp	#CTRL_PREFIX
		bne	out

		iny
		lda	(address),y
		beq	eof

		; ^^ -> ^
		cmp	#CTRL_PREFIX
		bne	ctrl_char

	put_ctrl_char:
		sta	submit_line,x
		inx
		bne	add2

	ctrl_char:
		; ^A - ^[ -> chr(c)
		; autorise ^[ pour avoir [ESC], sinon remplacer '['  par 'Z'
		; ^<autre> -> <autre>
		;
		; /?\ renvoyer vers error ou add2 au lieu de incr?
		cmp	#'A'
		bcc	incr

		cmp	#'['+1
		bcs	incr

		; C=0
		sbc	#'A'-1-1
		bpl	put_ctrl_char

	out:
		sta	submit_line,x
		inx

		bne	incr
		beq	error

	eof:
		lda	#$e4
		sec
		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;
; Sortie:
;
; Variables:
;       Modifiées:
;               -
;       Utilisées:
;               fp
; Sous-routines:
;       ftell
;	fclose
;----------------------------------------------------------------------
.proc submit_close
		jsr	ftell
		fclose	(fp)
		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;
; Sortie:
;
; Variables:
;       Modifiées:
;               fp
;       Utilisées:
;               filename
;		submit_path
; Sous-routines:
;       chdir
;	fopen
;	fseek
;	print
;	crlf
;----------------------------------------------------------------------
.proc submit_reopen
		; TODO: sauvegarder le pwd actuel pour pouvoir le restaurer
		; après la réouverture du fichier au cas où on a exécuté un cd

		; On se replace dans le répertoire d'origine au lancement
		; de submit
		chdir	submit_path

		fopen	(filename), O_RDONLY
		sta	fp
		stx	fp+1
		eor	fp+1
		bne	seek

		prints	"No such file or directory: "
		print	(filename)
		crlf

		sec
		lda	#ENOENT
		rts

	seek:
		jsr	fseek

		clc
		lda	#EOK
		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;
; Sortie:
;
; Variables:
;       Modifiées:
;		save_a
;               save_x
;		save_y
;		entry
;		address
;		TR3-TR4
;		TR5-TR6
;       Utilisées:
;               submit_line
;		DEFAFF
; Sous-routines:
;       find_var
;	xbindx
;----------------------------------------------------------------------
.proc submit_variable
;		cmp	#'9'+1
;		bcs	get_var
;		cmp	#'0'
;		bcc	error
;
;		; Commence par un chiffre, on peut avoir $0...$9
;		; C=1
		cmp	#'A'
		bcs	get_var
		; Ne commence pas par une lettre -> retour
		sec
		rts

	get_var:
		; Sauvegarde X
		stx	save_x

		; Calcul de la position de la valeur dans submit_line
		; pour la conversion
		clc
		txa
		adc	#<submit_line
		sta	TR5
		lda	#>submit_line
		adc	#$00
		sta	TR5+1

		; copier le nom de la variable dans submit_line

		dey
	loop:
		iny
		beq	eos

		lda	(address),y
		sta	submit_line,x
		beq	eol

		cmp	#'0'
		bcc	eos

		cmp	#'9'+1
		bcc	ok

		cmp	#'A'
		bcc	eos

		cmp	#'Z'+1
		bcc	ok

		cmp	#'a'
		bcc	eos

		cmp	#'z'+1
		bcs	eos

	ok:
		inx
		bcc	loop

		; Chercher la variable dans la table

	eos:
		; Caractère non alphanumérique trouvé
		; Est-ce un caractère de séparation?
		; /?\ Faut-il supprimer le test et considérer tout caractère
		;     non alphanumérique comme séparateur?
		; cmp	#' '
		; bne	bad_varname
		lda	#$00
		sta	submit_line,x

	eol:
		; Fin de ligne atteinte

		sty	save_y
		ldx	save_x

.if 0
		lda	#<internal_var_table
		ldy	#>internal_var_table
		clc
		jsr	find_cmnd
		bcs	not_found

		; pseudo variable EXIST = 0
		beq	not_found

	found:
		; Récupère la valeur de la variable
		; On arrive ici avec C=0
		sbc	#$00
		asl
		tax
		lda	vartab,x
		ldy	vartab+1,x
.else
		clc
		jsr	find_var
		bcs	not_found

		; pseudo variable EXIST = 0
		beq	not_found

	found:
		; Récupère la valeur de la variable
		lda	entry+st_entry::data_ptr
		ldy	entry+st_entry::data_ptr+1
		ldx	entry+st_entry::type
		cpx	#'C'
		bne	numeric

		sta	TR3
		sty	TR3+1
		ldy	entry+st_entry::len
	loop1:
		lda	(TR3),y
		sta	(TR5),y
		dey
		bpl	loop1

		lda	entry+st_entry::len
		jmp	adjust_x

	numeric:
.endif
		; Sauvegarde DEFAFF
		ldx	DEFAFF
		stx	save_a

		; conversion binaire -> ASCII
		; TR5 est déjà chargé avec la bonne adresse
		ldx	#$00
		stx	DEFAFF
		ldx	#$03
		;.byte	$00, XBINDX
		jsr	xbindx

		; Restaure DEFAFF
		lda	save_a
		sta	DEFAFF

		; Ajuste X
		; si XBINDX
		; lda	#$05
		; si xbindx
		; [
		iny
		tya
		; ]
	adjust_x:
		clc
		adc	save_x
		tax

		; Ajuste address
		lda	save_y
		clc
		adc	address
		sta	address
		lda	address+1
		adc	#$00
		sta	address+1
		; en principe on ne peut pas avoir de débordement, donc ici C=0
		; clc
		rts

	not_found:
		; Variable non trouvée, on remplace par ''
		; Restaure X
		ldx	save_x
		; On se replace sur le caractère suivant la variable
		ldy	save_y
		;lda	#' '
		;sta	submit_line,x
		;clc
		;rts

	bad_varname:
		; On a déjà copié la chaîne dans submit_line
		; -> on continue
		; Ajustement de address
		clc
		tya
		adc	address
		sta	address
		lda	address+1
		adc	#$00
		sta	address+1

		; en principe on ne peut pas avoir de débordement, donc ici C=0
		; clc
		rts
.endproc

;----------------------------------------------------------------------
;			Chaines statiques
;----------------------------------------------------------------------
