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

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import PrintHexByte

.import fgets
.import linenum
.import filename

;.importzp cwd
;.importzp file_pwd
.import submit_path

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
;.export fpos

; Pour fgets
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
SUBMIT_LINE_MAX_SIZE = 200

;----------------------------------------------------------------------
;				Page Zéro
;----------------------------------------------------------------------
.pushseg
	.segment "ZEROPAGE"
		unsigned char active_bank

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
;               -
;       Utilisées:
;               -
; Sous-routines:
;       -
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
;               -
; Sous-routines:
;       -
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
;               -
;       Utilisées:
;               -
; Sous-routines:
;       -
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
;			Chaines statiques
;----------------------------------------------------------------------
