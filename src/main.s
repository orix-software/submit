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
; .include "keyboard.inc"

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------
.include "include/submit.inc"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import PrintHexByte

.import fgets
.import linenum

.import label_ofs, label_num, forward_label

; Pointeur de pile CALL/RETURN
.import stack_ptr

; Pour compatibilité fichier TEXT
.import fpos_text

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export _main

; Pour fgets
.export fp

; Pour cmnd_chain
.export cmdline

; Pour fseek, ftell
.export fpos

; Pour cmnd_goto
.export prev_fpos

.export _argv, _argc

.export filename
.export submit_path
.export path
;.export path_len
.export errorlevel, key

.export entry

.export vars_index
.export vars_data_index

;----------------------------------------------------------------------
;                       Segments vides
;----------------------------------------------------------------------
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
;LINE_MAX_SIZE = 128

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

		; Table des variables
		; [
		; unsigned char base[VARS_MAX*ST_ENTRYLEN+1]
		base:
		.byte	"EXIST",0,0,0,0,0,0
		.byte	'N'
		.byte	0
		.word	$0000
		;
		.byte	"ERRORLEVEL",0
		.byte	'N'
		.byte	0
		errorlevel:
		.word	$0000
		;
		.byte	"KEY",0,0,0,0,0,0,0,0
		.byte	'N'
		.byte	0
		key:
		.word	$0000
		;
		;.byte	"PATH",0,0,0,0,0,0,0
		;.byte	'C'
		;path_len:
		;.byte	0
		;.word	path
		;
		.res	256-(*-base), 0

                unsigned char entry[ENTRY_LEN]

		; Nombre de variables (index de la prochaine variable)
		unsigned char vars_index

		; Tableau des chaines
		unsigned char vars_datas[VARS_DATALEN*VARS_MAX]
		; Pointeur vers la prochaine chaine
		unsigned short vars_data_index

		; unsigned short errorlevel
		; unsigned short key
		; vartab := errorlevel
		; ]

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
;       check_kernel_version
;	cmnd_version
;	init_tables
;	submit_reopen
;	submit_close
;	submit
;	internal_command
;	external_command
;	error_line
;	print
;	cputc
;	getcwd
;	chdir
;	_get_argv
;	fclose
;	fgets
;	mfree
; 	PrintHexByte
;	XDECIM
;	crlf
;----------------------------------------------------------------------
.proc _main
;		malloc	128, cwd

		jsr	check_kernel_version
		bcc	start

		jsr	cmnd_version
		prints	"Kernel version mismatch (need >=2022.4)\r\n"
		lda	#EUNKNOWN
		rts

	start:
		; initmainargs semble poser un problème avec EXEC
		; c'est à priori lié au malloc fait par inimainargs
;		initmainargs _argv
;		stx	_argc
;		dex
;		beq	end
; [
		; Sauvegarde la ligne de commande
;		lda	#<BUFEDT
;		ldy	#>BUFEDT
;		lda	#$01
		initmainargs ,,1
		sta	RES
		sty	RES+1

		ldy	#$00
	cmdline_loop:
		lda	(RES),y
		sta	cmdline,y
		beq	@skip
		iny
		bne	cmdline_loop

		mfree	(RES)
	@skip:

		jsr	init_tables

	try_again:
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

		; Voir pour un autre code erreur?
		lda	#EINVAL
		ldx	#$00
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

		; sty	path_len

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
;		.byte	$00, XRD0
;		cmp	#KEY_CTRL_C
;		bne	cont
		asl	KBDCTC
		bcc	cont
;		lda	KBDCTC
;		bpl	cont

;		clc
;		bcc	cont

	end:
		lda	#EOK
		sta	errorlevel
		lda	#$00
		sta	errorlevel+1
		fclose	(fp)

	exit:
		; TODO: vérifier que la pile des CALLS est bien vide
;		print	ret_msg
		; mfree	(_argv)
		lda	errorlevel
		ldx	errorlevel+1
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

		cmp	#EAGAIN
		bne	@suite
		jmp	try_again

	@suite:
		; Exit?
		cmp	#$e4
		beq	exit

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

		lda	#ENOENT
		ldx	#$00
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
		pha
		cmp	#ENOENT
		bne	error_noexec
		prints	" unknown command"
		jmp	error_line

	error_noexec:
		cmp	#ENOEXEC
		bne	error_other
		prints	" exec format error"
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
		; jsr	cmnd_dump
		; Restaure DEFAFF
		lda	defaff_save
		sta	DEFAFF

		; Code erreur
		pla
		ldx	#$00
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

;----------------------------------------------------------------------
;
; Entrée:
;	-
; Sortie:
;	A,Y: modifiés
;	X: inchangé
;
; Variables:
;       Modifiées:
;               linenum
;		stack_ptr
;		errorlevel
;		prev_fpos
;		fpos
;		label_ofs
;		label_num
;		defaff_save
;		base
;		tabase
;		entlen
;		keylen
;		keydup
;		vars_index
;		vars_data_index
;		cmdline
;		DEFAFF
;		RES
;       Utilisées:
;		vars_datas
;		BUFEDT
; Sous-routines:
;       -
;----------------------------------------------------------------------
.proc init_tables
		; Numéro de ligne du fichier batch
		lda	#$00
		sta	linenum
		sta	linenum+1

		; Initialise stack_ptr = 0
		sta	stack_ptr

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

		; Initialise la table des variables
		lda	#<base
		ldy	#>base
		sta	tabase
		sty	tabase+1

		lda	#ENTRY_LEN
		sta	entlen

		lda	#$00
		sta	base+VARS_MAX*ST_ENTRYLEN

		; Longueur de la clé
		lda	#ident_len
		sta	keylen

		; Autorise l'écrasement d'une variable
		lda	#$ff
		sta	keydup

		; Nombre de variables dans la table
		lda	#$03
		sta	vars_index

		; Pointeur vers la table des données
		lda	#<vars_datas
		ldy	#>vars_datas
		sta	vars_data_index
		sty	vars_data_index+1

		; Sauvegarde l'adresse de path
		;lda	#<path
		;sta	file_pwd
		;lda	#>path
		;sta	file_pwd+1

.if 0
		; initmainargs semble poser un problème avec EXEC
		; c'est à priori lié au malloc fait par inimainargs
;		initmainargs _argv
;		stx	_argc
;		dex
;		beq	end
; [
		; Sauvegarde la ligne de commande
		lda	#<BUFEDT
		ldy	#>BUFEDT
;		lda	#$01
;		initmainargs
		sta	RES
		sty	RES+1

		ldy	#$00
	init:
		lda	(RES),y
		sta	cmdline,y
		beq	end
		iny
		bne	init

;		mfree	(RES)
.endif
	end:
		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	-
; Sortie:
;	C : 0-> version kernel compatible, 1-> version kernel incompatible
;	AY: Kernel version
;	X : modifié
;
; Variables:
;       Modifiées:
;               -
;       Utilisées:
;               -
; Sous-routines:
;       XVARS
;----------------------------------------------------------------------
.proc check_kernel_version
		; Version du kernel:A=X=Y=0 -> version >= 2020.4
		;ldx	#$06
		;.byte	$00, XVARS
		;jsr	PrintRegs

		ldx	#$03
		.byte $00, XVARS

		cpx	#$06
		beq	prior_2020_4

		cmp	#$01
		bcc	prior_2022_4
		clc
		rts

	prior_2022_4:
		sec
	prior_2020_4:
		rts
.endproc
