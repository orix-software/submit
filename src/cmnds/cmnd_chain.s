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
; From cmnd_label.s
.import forward_label, label_num
.import label_ofs
.import labels

; From fgets.s
.import fpos_text
.import linenum
.import buffer_reset

; From main.s
.import fpos
.import prev_fpos
.import cmdline
.import errorlevel

; From internal_cmnd.s
.import save_x
.import skip_spaces

; From cmnd_call
.import stack_ptr

; From submit.s
.import submit_line

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_chain

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "ZEROPAGE"
		unsigned short ptr

	.segment "DATA"
		dummy: .byte "xx "
		unsigned char filename[64]
		unsigned short fp
.popseg

;----------------------------------------------------------------------
;			Chaines statiques
;----------------------------------------------------------------------
.pushseg
	.segment "RODATA"
		with:
			string80	"WITH"
			.byte	$00
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
.proc cmnd_chain
		jsr	skip_spaces
		bne	cont

	no_filename:
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

		ldx	save_x
		lda	#$e2
		sec
		rts

	cont:
		stx	save_x
		beq	no_filename

		ldy	#$00
	loop:
		lda	submit_line,x
		sta	filename,y

		beq	chain
		; TODO: Vérifier la validité des caractères
		cmp	#' '
		beq	chain

		inx
		iny
		cpy	#64
		bne	loop

	oom:
		; Label trop long
		sec
		lda	#$f3
		rts

	chain:
		lda	#$00
		sta	filename,y

		fopen	filename, O_RDONLY
		sta	fp
		stx	fp+1
		eor	fp+1
		beq	error_open

		fclose	(fp)

		; Mise à jour de cmdline
		ldy	#$ff
	cmdline_loop:
		iny
		lda	filename-3,y
		sta	cmdline,y
		bne	cmdline_loop

; [ WITH param1 param2...
;		ldx	save_x
;		; jsr	skip_spaces
;
;		lda	#<with
;		ldy	#>with
;		clc
;		jsr	find_cmnd
;		bcs	no_with
;
;		; Ajout des paramètres dans cmdline
;		; ...
; ]

	no_with:
		jsr	reset

;		ldy	_argc
;		lda	#$00
;	argv_loop:
;		sta	_argv,y
;		dey
;		bne	argv_loop

		ldx	save_x

		; Indique une erreur "Try again" pour forcer une relecture
		; des paramètres du script
		lda	#EAGAIN
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
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc reset
		jsr	buffer_reset

		; Numéro de ligne du fichier batch
		lda	#$00
		sta	linenum
		sta	linenum+1

		; Initialise stack_ptr = 0
		sta	stack_ptr

		ldy	#$03
	loop:
		; Initialise l'offset ligne courante
		sta	prev_fpos,y

		; Initialise l'offset ligne suivante
		sta	fpos,y

		sta	fpos_text,y

		dey
		bpl	loop

		; Initialise les pointeurs pour la table des labels
		lda	#$00
		sta	label_ofs
		sta	label_num
		sta	labels
		lda	#$01
		sta	forward_label

		clc

		rts
.endproc

