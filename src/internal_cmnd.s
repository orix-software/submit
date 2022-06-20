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
.include "macros/utils.mac"
.include "macros/SDK-ext.mac"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import submit_line
.import errorlevel

.import spar1
	spar := spar1

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export internal_command

; Pour les commandes
.exportzp var1, var2, ptr
.export save_a, save_x, save_y
.export exec_address
.export line
.export internal_var_table

.export skip_spaces, string_delim, find_cmnd

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
CASE_SENSITIVE_LABELS .set 0
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

		; Tampon lecture du fichier (on pourrait utiliser line[] de main.s
		; Utilisé par GOTO, et IF (EXIST)
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
;.proc cmnd_test
;		jsr	skip_spaces
;		beq	end
;
;		; Oublie le retour vers internal_command
;		pla
;		pla
;
;		; Relance une recherche avec la nouvelle commande
;		jmp	internal_command
;
;	end:
;		rts
;.endproc

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

			string80	"GETKEY"

			string80	"CALL"
			string80	"RETURN"

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

			.word	cmnd_getkey

			.word	cmnd_call
			.word	cmnd_return

			.word	cmnd_dump
			.word	cmnd_errorlevel

		internal_var_table:
			string80	"EXIST"
			string80	"ERRORLEVEL"
			.byte	$00
.popseg
