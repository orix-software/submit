;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"
.include "errno.inc"
.include "fcntl.inc"

XMAINARGS = $2C
XGETARGV = $2E

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

.import label_ofs, label_num, forward_label

; Pour compatibilité fichier TEXT
.import fpos_text

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export _main

; Pour fgets
.export fp

; Pour fseek, ftell
.export fpos

; Pour cmnd_goto
.export prev_fpos

.export _argv, _argc

.export filename
.export submit_path
.export path
.export errorlevel

;----------------------------------------------------------------------
;                       Segments vides
;----------------------------------------------------------------------
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
LINE_MAX_SIZE = 128

;----------------------------------------------------------------------
;				Page Zéro
;----------------------------------------------------------------------
.pushseg
	.segment "ZEROPAGE"
		unsigned short cwd
.popseg

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
		; Sauvegarde ligne de commande
		unsigned char cmdline[128]

		; Tableau des arguments de la ligne de commande
		;  1: _argc (en fait il ne faut qu'un octet et non un short)
		; +1: submit
		; +1: nom du fichier
		; +9: 9 paramètres
		;----
		; 12
		unsigned short args[12]

		unsigned short _argv
		unsigned char  _argc

		unsigned short errorlevel

		unsigned char save_x

		unsigned short fp
		unsigned char submit_path[128]
		unsigned short filename

		unsigned char path[128]

		; Tampon lecture du fichier
		unsigned char line[LINE_MAX_SIZE]

		; Pour fseek, ftell
		unsigned long fpos

		; Pout la recherche d'un label
		unsigned long prev_fpos

		unsigned char defaff_save
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
;       Modifiées:
;               -
;       Utilisées:
;               -
; Sous-routines:
;       -
;----------------------------------------------------------------------
.proc _main
;		malloc	128, cwd

		; Version du kernel:A=X=Y=0 -> version >= 2020.4
		;ldx	#$06
		;.byte	$00, XVARS
		;jsr	PrintRegs

		; Numéro de ligne du fichier batch
		lda	#$00
		sta	linenum
		sta	linenum+1

		; Initialise errorlevel = 0
		sta	errorlevel
		sta	errorlevel+1

		; Initialise l'offset ligne courante
		sta	prev_fpos
		sta	prev_fpos+1
		sta	prev_fpos+2
		sta	prev_fpos+3

		; Initialise l'offset ligne suivante
		sta	fpos
		sta	fpos+1
		sta	fpos+2
		sta	fpos+3

		; Initialise les pointeurs pour la table des labels
		sta	label_ofs
		sta	label_num
		lda	#$01
		sta	forward_label

		; Initialise DEFAFF
		lda	DEFAFF
		sta	defaff_save
		lda	#' '
		sta	DEFAFF

		; Sauvegarde l'adresse de path
		;lda	#<path
		;sta	file_pwd
		;lda	#>path
		;sta	file_pwd+1

		; initmainargs samble poser un problème avec EXEC
		; c'est à priori lié au malloc fait par inimainargs
;		initmainargs _argv
;		stx	_argc
;		dex
;		beq	end
; [
		; Sauvegarde la ligne de commande
		lda	#<BUFEDT
		ldy	#>BUFEDT
		sta	RES
		sty	RES+1

		ldy	#$00
	init:
		lda	(RES),y
		sta	cmdline,y
		beq	start
		iny
		bne	init

	start:
		lda	#<cmdline
		ldy	#>cmdline
		sta	RESB
		sty	RESB+1
;		malloc	20, _argv
;		eor	_argv+1
;		bne	getargs
;		print	oom_msg
;		rts

	getargs:
		lda	#<args
		ldy	#>args
		sta	_argv
		sty	_argv+1
		sta	RES
		sty	RES+1

		; /?\ la valeur de X n'est pas utilisée par _init_argv
		;     10 arguments maximum (+1 pour submit)
		ldx	#10+1
		jsr	_init_argv
		tax
		bne	get_args

		jsr	cmnd_version
		prints	"Filename missing\r\n"
		rts


	get_args:
		inx
		stx	_argc
; ]

		; Sauvegarde le cwd dans une variable
		getcwd	cwd
		ldy	#$ff
	path_loop:
		iny
		lda	(cwd),y
		sta	submit_path,y
		sta	path, y
		bne	path_loop

;		getmainarg #1, (_argv), filename
; [
		ldx	#$01
		jsr	_get_argv
		sta	filename
		sty	filename+1
; ]

;		fopen	(filename), O_RDONLY
;		sta	fp
;		stx	fp+1
;		eor	fp+1
;		beq	open_error
;		jsr	submit_reopen
;		cmp	#EOK
;		beq	loop

	loop:
		;jsr	StopOrCont
		clc
		bcc	cont

	end:
		fclose	(fp)
;		print	ret_msg
		; mfree	(_argv)
		rts

	cont:
		ldx	#$03
	save_fpos:
		lda	fpos_text,x
		sta	prev_fpos,x
		dex
		bpl	save_fpos

		jsr	submit_reopen
		bcs	open_error

		lda	#<line
		ldy	#>line
		ldx	#LINE_MAX_SIZE

		jsr	fgets
;		jsr	PrintRegs
		bcs	end

		jsr	submit_close
		chdir	path
;		print	line
;		crlf

		; Si ECHO ON
		;print	line
		; crlf

		; Saute les ' ' en début de ligne
		ldx	#$ff
	skip:
		inx
		lda	line,x
		beq	loop
		cmp	#' '
		beq	skip

		; Premier caractère: '#' ou ';' -> commentaire
		lda	line,x
		cmp	#'#'
		beq	loop
		cmp	#';'
		beq	loop

		lda	#<line
		ldy	#>line
		jsr	submit
		; Erreur?
		bcs	error

		; ligne vide?
		beq	loop

		; Commande interne?
		jsr	internal_command
		bcc	loop

		; Exit?
		cmp	#$e4
		beq	end

		cmp	#ENOENT
		bne	error

		; Commande externe
		jsr	external_command
		bcc	loop
		bcs	error

	open_error:
		; Le message d'erreur a déjà été affiché par submit_reopen
		;print	error_open_msg
		;print	(filename)
		;crlf
		mfree	(_argv)

		; Restaure DEFAFF
		lda	defaff_save
		sta	DEFAFF
		rts

	error:
		; Sauvegarde le code erreur et l'emplacement dans la ligne
		pha
		stx	save_x

		prints	"\r\nError line "
		lda	linenum+1
		jsr	PrintHexByte
		lda	linenum
		jsr	PrintHexByte

		cputc	':'
		pla
		cmp	#ENOENT
		bne	error_other
		prints	" unknown command"
		jmp	error_line

	error_other:
		ldy	#$00
		ldx	#$02
		.byte	$00, XDECIM
		;print	other_msg

	error_line:
		crlf
		print	submit_line
		crlf
		ldx	save_x
		beq	error_end

	error_loop:
		cputc	' '
		dex
		bne	error_loop

	error_end:
		cputc	'^'
		crlf

		; Restaure DEFAFF
		lda	defaff_save
		sta	DEFAFF
		rts

;	ret_msg:
;		.asciiz "\r\nRetour ok\r\n"

;	oom_msg:
;		.asciiz "\r\nOut of memory\r\n"

;	error_open_msg:
;		.asciiz "No such file or directory: "

;	other_msg:
;		.asciiz " other"
.endproc


