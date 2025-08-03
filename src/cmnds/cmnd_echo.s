;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes, loose_char_term

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
.include "macros/utils.mac"
.include "macros/SDK-ext.mac"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
; From submit.s
.import save_a, save_y, save_x
.import submit_line

; From internal_cmnd.s
.import string_delim
.import skip_spaces

; From fputs.s
.import fputs, fputc, fput_crlf

; From fseek.s
.import fseek_end

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_echo

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
LF = $0a
LTRIM_LITERAL = 1
CRLF = LF

;----------------------------------------------------------------------
;				Page Zéro
;----------------------------------------------------------------------
.pushseg
	.segment "ZEROPAGE"
		unsigned short str_ptr
.popseg

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
		unsigned char filename[64]
		unsigned char fmode
		unsigned short fp
		unsigned char save_char
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
;	C: 0-> Ok, 1-> Erreur
;
;	Si erreur A:
;		3: erreur ouverture du fichier	(EACCES)
;		7: nom de fichier trop long	(EINVAL)
;		8: erreur écriture fichier	(ENOSPC)
;		11: erreur suprresion fichier	(EIO)
;		255: erreur de syntaxe
;
; Variables:
;	Modifiées:
;		save_a
;		save_x
;		save_y
;		filename
;		fmode
;		save_char
;		str_ptr
;	Utilisées:
;		submit_line
; Sous-routines:
;	redir
;	echo_error
;	skip_spaces
;	string_delim
;	print
;	crlf
;----------------------------------------------------------------------
.proc cmnd_echo
		; Prendre en compte un paramètre ON|OFF
		; Prendre en compre une redirection vers un fichier?

		lda	#$00
		sta	filename
		sta	fmode
		sta	save_a

		; Pas de flag -n par défaut
		clc
		ror	save_y

		; Aucun paramètre -> crlf
		jsr	skip_spaces
		bne	get_param

		crlf
		; lda	#EOK
	end_empty:
		clc
		rts

	get_param:
		; AY: adresse de la chaine
		sta	str_ptr
		sty	str_ptr+1

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
		beq	end_empty

		; Poids faible adresse de la chaine
		sta	str_ptr
		sty	str_ptr+1

	_echo:
		; save_a contient le poids faible de l'adresse du tampon
		; lda	save_a			; AY: adresse de submit_line, X: offset
		; jsr	string_delim

	; [ string_delim
		lda	submit_line, x
		cmp	#'"'
		beq	string

		cmp	#"'"
		bne	literal

	string:
		sta	cmp_delim+1
		sta	save_char

		; Mise à jour pointeur vers le début de la chaine
		inc	str_ptr
		bne	str_loop
		inc	str_ptr+1

	str_loop:
		inx
		lda	submit_line, x
		beq	no_redir

	cmp_delim:
		cmp	#'"'
		bne	str_loop

		; Remplace le déliminteur de fin par un $00
		lda	#$00
		sta	submit_line, x

		; On conserve X en cas d'erreur
		stx	save_x
	; ]

		inx
		jsr	skip_spaces
		beq	no_redir

		lda	submit_line, x
		cmp	#'>'
		bne	no_redir		; /!\ ignore la suite si pas de '>' (linux permet plusieurs chaines)

	redir_found:
		inx
		lda	submit_line, x
		cmp	#'>'
		bne	get_fn0

		; '>>': mode append
		ror	fmode
		inx

	get_fn0:
		jsr	skip_spaces
		bne	get_fn

		; Erreur de syntaxe, fichier manquant
		ldy	#$ff
		jmp	echo_error

	get_fn:
		; Ici on doit avoir un nom de fichier
		ldy	#$00
	loop1:
		lda	submit_line, x
		sta	filename, y
		beq	do_redir
		inx
		iny
		cpy	#64
		bne	loop1

		; Erreur nom de fichier trop long
		ldy	#EINVAL
		jmp	echo_error

	do_redir:
		jmp	redir

		; Chaine sans délimiteurs, on cherche un '>'
	literal:
	.if ::LTRIM_LITERAL
		; Traitement cas "echo > fichier"
		stx	save_x
		cmp	#'>'
		beq	lit_empty
	.endif

		dex
	lit_loop:
		inx
		lda	submit_line, x
		beq	no_redir

		cmp	#'>'
		bne	lit_loop

		; On conserve X n cas d'erreur
		stx	save_x

		; supprime les espaces à droite
	lit_loop1:
	.if ::LTRIM_LITERAL
		dex
		lda	submit_line, x
		cmp	#' '
		beq	lit_loop1

		inx
	.endif
	lit_empty:
		lda	submit_line, x
		sta	save_char
		stx	save_a

		; marque la fin de la chaine
		lda	#$00
		sta	submit_line, x
		ldx	save_x
		bne	redir_found

	no_redir:
		print	(str_ptr)

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
;	filename: nom du fichier
;	fmode: mode d'ouverture
;	str_ptr: adresse de la chaine
;
; Sortie:
;	C: 0-> Ok, 1-> Erreur
;
;	Si erreur A:
;		3: erreur ouverture du fichier	(EACCES)
;		8: erreur écriture fichier	(ENOSPC)
;		11: erreur suprresion fichier	(EIO)
;
; Variables:
;	Modifiées:
;		fp
;		save_y
;	Utilisées:
;		str_ptr
; Sous-routines:
;	fputs
;	fput_crlf
;	echo_error
;----------------------------------------------------------------------
.proc redir
	;	bit	fmode
	;	bpl	truncate

	;	; Mode append
	;	fopen	filename, O_WRONLY
	;	sta	fp
	;	stx	fp+1
	;	eor	fp+1
	;	beq	create
	;	jsr	fseek_end
	;	jmp	_fputs

	; create:
	;	fopen	filename, O_CREAT
	;	jmp	suite

	; truncate:
	;	fopen	filename, O_TRUNC
	; suite:
	;	sta	fp
	;	stx	fp+1
	;	eor	fp+1
	;	beq	error
	; f_fputs

		fopen	filename, O_WRONLY
		sta	fp
		stx	fp+1
		eor	fp+1
		beq	create

		; Ici, le fichier existe déjà

		bit	fmode
		bpl	truncate

		; Mode append
		jsr	fseek_end
		jmp	_fputs

	truncate:
		fclose	(fp)
		unlink	filename
		ldy	#EACCES
		cmp	#$00
		bne	error

	create:
		fopen	filename, O_CREAT
		sta	fp
		stx	fp+1
		eor	fp+1
		beq	fopen_err

	_fputs:
		lda	str_ptr
		ldy	str_ptr+1
		ldx	fp
		jsr	fputs
		bne	fputs_err

		; CR/LF?
		bit	save_y
		bmi	redir_end

		ldx	fp
	.if ::CRLF = ::LF
		lda	#LF
		jsr	fputc
	.else
		jsr	fput_crlf
	.endif
		beq	redir_end

	fputs_err:
		fclose	(fp)

		ldy	#ENOSPC
		jmp	echo_error

	redir_end:
		fclose	(fp)
		clc
		rts

	fopen_err:
		ldy	#EIO
	error:
		jmp	echo_error
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	Y: code erreur
;
; Sortie:
;	A: code erreur
;	X: offset erreur
;	Y: code erreur
;	C: 1
;
; Variables:
;	Modifiées:
;		save_a
;		save_x
;		submit_line
;	Utilisées:
;		save_a
;		save_x
;		save_char
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc echo_error
		; Restore X (offset dans submit_line) et le caractère effacé
		ldx	save_a
		beq	error1

		; Cas d'une chaine sans délimiteur
		lda	save_char
		sta	submit_line, x
		ldx	save_x
		bne	error_end

	error1:
		; Cas d'une chaine avec délimiteur
		ldx	save_x
		lda	save_char
		sta	submit_line, x

	error_end:
		tya
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
.if 0
	.proc string_delim
			lda	submit_line, x
			cmp	#'"'
			beq	string

			cmp	#"'"
			bne	literal

		string:
			sta	cmp_delim+1

			; Mise à jour pointeur vers le début de la chaine
			inc	str_ptr
			bne	str_loop
			inc	str_ptr+1

		str_loop:
			inx
			lda	submit_line, x
			beq	no_redir

		cmp_delim:
			cmp	#'"'
			bne	str_loop

			; Remplace le déliminteur de fin par un $00
			lda	#$00
			sta	submit_line, x
	.endproc
.endif


