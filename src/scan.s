;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes, loose_char_term

.include "telestrat.inc"
.include "errno.inc"

.macpack longbranch
;----------------------------------------------------------------------
;			includes SDK
;----------------------------------------------------------------------
.include "SDK.mac"
.include "types.mac"

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------
.include "macros/SDK-ext.mac"
.include "macros/utils.mac"
.include "submit.inc"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
; From fgets.s
.import fpos_text
.import linenum
.import fgets
.import buffer_reset

; From submit.s
.import submit_line

; From main.s
.import stack_ptr
.import fpos
.import prev_fpos

; From cmnd_label
.import forward_label
.import cmnd_label

; From debug.s
.import StopOrCont
.import PrintHexByte

; From internal_cmnd.s
.import find_cmnd
.import skip_spaces

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export scan

.export push_if
.export pop_else
.export pop_endif

.export flow_stack

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
typedef .struct if_item
	unsigned short if_line
	unsigned short else_line
	unsigned long else_offset
	unsigned short endif_line
	unsigned long endif_offset
.endstruct

.define IF_MAX 10

;----------------------------------------------------------------------
;				Page Zéro
;----------------------------------------------------------------------
.pushseg
	.segment "ZEROPAGE"

.popseg

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "RODATA"
		scan_tbl:
			string80	"IF"
			string80	"ELSE"
			string80	"ENDIF"
;			string80	"WHILE"		; "DO WHILE"
;			string80	"WEND"		; "LOOP"
;			string80	"REPEAT"	; "DO"
;			string80	"UNTIL"		; "LOOP WHILE"
			string80	"TEXT"
			string80	"ENDTEXT"
			.byte		$00

		TOKEN_IF = 0
		TOKEN_ELSE = 1
		TOKEN_ENDIF = 2
		TOKEN_TEXT = 3
		TOKEN_ENDTEXT = 4

	.segment "DATA"
		; Table des blocs
		unsigned char if_table[IF_MAX * .sizeof(if_item)]
		unsigned char if_ptr

		; Pile pour les if imbriqués
		unsigned char flow_stack
		unsigned char if_stack[IF_MAX]

		; Pour la vérification de la syntaxe
		unsigned char if_stack_syntax[IF_MAX]

.out .sprintf("if_table size : %d", .sizeof(if_table))
.out .sprintf("if stack depth: %d", IF_MAX)


.popseg

;----------------------------------------------------------------------
;			Programme principal
;----------------------------------------------------------------------
.segment "CODE"

;----------------------------------------------------------------------
;
; Entrée:
;	AY: Adresse du tampon
;	X : Taille du tampon
;
; Sortie:
;	A  : 0 ou code erreur
;	X  : Modifié
;	Y  : 0
;	C=0: Ok
;	C=1: Erreur
;
; Variables:
;       Modifiées:
;               address
;		max_line_size
;       Utilisées:
;               -
; Sous-routines:
;       fgetc
;----------------------------------------------------------------------
.proc scan
		lda	#($100-.sizeof(if_item))
		sta	if_ptr

		lda	#$00
		sta	flow_stack
;		sta	if_flag

		sta	if_stack
		sta	if_stack_syntax

		sta	linenum+1
		sta	linenum

	.if ::VERBOSE_LEVEL > 0
			crlf
		loop:
			cputc	$0d
			jsr	print_linenum
	;		cputc	':'
	.else
		loop:
	.endif

                lda     #<submit_line
                ldy     #>submit_line
                ldx     #LINE_MAX_SIZE

		jsr	fgets
		jcs	end

	.if ::VERBOSE_LEVEL > 0
	;		print	submit_line
			jsr	StopOrCont
			jcs	end
	.endif

		ldx	#$00
		; /?\ il faudrait déporter le skip_sppces juste avant la recherche
		;     des tokens (':', '#' et ';' sont supposés être en début de
		;     ligne.
		; [
		jsr	skip_spaces
		; ]
		lda	submit_line,x
		; Ligne vide?
		beq	loop

		; Label?
		cmp	#':'
		bne	remark

		inx
		jsr	cmnd_label
		bcc	loop
		jmp	error_label

	remark:
		; Si commentaire, on passe à la ligne suivante
		cmp	#'#'
		beq	loop
		cmp	#';'
		beq	loop

		; Les instructions peuvent être indentées
		; [
		; jsr	skip_spaces
		; beq	loop
		; ]

		; Case insensitive
		clc
                lda     #<scan_tbl
                ldy     #>scan_tbl
		jsr	find_cmnd
		bcs	loop

		; Ici A: n° du token
		cmp	#TOKEN_TEXT
		bne	if
		jsr	skip_text
		bcc	loop
		; Fin de fichuer atteinte et pas de ENDTEXT trouvé
		;jcs	end
		jmp	error

	if:
		cmp	#TOKEN_IF
		bne	else

		inc	flow_stack
		ldy	flow_stack
		cpy	#IF_MAX
		jeq	error_overflow

		; Mise à jour de la table
		; ldy	flow_stack
		lda	#$00
		sta	if_stack_syntax,y

		; Calcul adresse pointeur dans la table
		clc
		lda	if_ptr
		adc	#.sizeof(if_item)
		sta	if_ptr

		; Conserve le pointeur dans la pile
		sta	if_stack,y

		; On ne conserve que le numéro de ligne pour servir de clé
		tay
		lda	linenum
		sta	if_table,y
		lda	linenum+1
		sta	if_table+1,y

;		lda	#$ff
;		sta	if_flag
		jmp	loop

	else:
		cmp	#TOKEN_ELSE
		bne	endif

		; Underflow
		ldy	flow_stack
		beq	error_unexpected_else

		lda	if_stack_syntax,y
		bne	error_unexpected_else
		lda	#$01
		sta	if_stack_syntax,y

		; Mise à jour de la table
		lda	#if_item::else_line
		jsr	update_table
		jmp	loop

	endif:
		cmp	#TOKEN_ENDIF
		jne	loop

		; Underflow
		ldy	flow_stack
		beq	error_unexpected_endif

		lda	if_stack_syntax,y
		cmp	#$02
		bcs	error_unexpected_endif

;		lda	if_flag
;		beq	error_no_if

		lda	#$02
		sta	if_stack_syntax,y

		; Mise à jour de la table
		lda	#if_item::endif_line
		jsr	update_table

		dec	flow_stack
;		lda	#$00
;		sta	if_flag
		jmp	loop



	error_label:
		crlf
		prints	"\rlabel table full"
		jmp	exit_err

	error_overflow:
		prints	"\rtoo many IF/ENDIF line "
		jmp	exit_err

	error_unexpected_else:
;		crlf
;		jsr	print_linenumber
;		cputc	':'
;		print	submit_line
;		crlf
		prints	"\runexpected else line "
		jmp	exit_err

	error_unexpected_endif:
		prints	"\runexpected endif line "

	exit_err:
		jsr	print_linenum

	error:
		crlf
		sec
		lda	#EINVAL
		rts

	end:
	.if ::VERBOSE_LEVEL > 0
		crlf
	.endif
		; Vérifie si tous les IF ont un ENDIF
		lda	flow_stack
		beq	exit_ok

		; Récupère la ligne du if incomplet
		tay
		lda	if_stack,y
		tay
		lda	if_table,y
		sta	linenum
		lda	if_table+1,y
		sta	linenum+1
		jsr	print_linenum
		prints	": IF without ENDIF\r\n"
		dec	flow_stack
		bne	end
		beq	error

	exit_ok:
;	.if ::VERBOSE_LEVEL > 1
;		crlf
;		crlf
;		jsr	cmnd_dump
;	.endif

		; [ repris de cmd_chain.s/reset
		jsr	buffer_reset

		; Numéro de ligne du fichier batch
		lda	#$00
		sta	linenum
		sta	linenum+1

		; Initialise le pointeur de la pile
		sta	flow_stack

		; Initialise stack_ptr = 0
		sta	stack_ptr

		ldy	#$03
	reset_loop:
		; Initialise l'offset ligne courante
		sta	prev_fpos,y

		; Initialise l'offset ligne suivante
		sta	fpos,y

		sta	fpos_text,y

		dey
		bpl	reset_loop
		; ]
		; Indique qu'on a truvé tous les labels
		lda	#$00
		sta	forward_label

;	error:
		clc
		rts

	if_flag:
		.byte	$00
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
.proc update_table
		clc
		ldy	flow_stack
		adc	if_stack,y
		tay

		; Sauvegarde le numéro de la ligne
		; (utile uniquement pour les messages d'erreurs)
;		php
;		sed
		lda	linenum
;		adc	#$01
		sta	if_table,y
		lda	linenum+1
;		adc	#$00
		sta	if_table+1,y
;		plp

		; Sauvegarde l'offset de la ligne suivante
		lda	fpos_text
		sta	if_table+2,y
		lda	fpos_text+1
		sta	if_table+3,y
		lda	fpos_text+2
		sta	if_table+4,y
		lda	fpos_text+3
		sta	if_table+5,y

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
; /!\ Ne remonte pas d'erreur dans le cas suivant (il manque un ENDTEXT)
; TEXT
;	...
; TEXT
;	...
; ENDTEXT
;----------------------------------------------------------------------
.proc skip_text
	loop:
                lda     #<submit_line
                ldy     #>submit_line
                ldx     #LINE_MAX_SIZE
		jsr	fgets
		bcs	eof

		; Saute les espaces en début de ligne
		ldx	#$00
		jsr	skip_spaces
		lda	submit_line,x
		; Ligne vide?
		beq	loop

		; Case insensitive
		clc
                lda     #<scan_tbl
                ldy     #>scan_tbl
		jsr	find_cmnd
		bcs	loop

		; Ici A: n° du token
		cmp	#TOKEN_ENDTEXT
		bne	loop

	end:
		clc

	eof:
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
.proc print_linenum
		lda	linenum+1
		jsr	PrintHexByte
		lda	linenum
		jsr	PrintHexByte
		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;
; Sortie:
;	A,Y: Modifiés
;	X  : Inchangé
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc push_if
		; TODO: Vérifier que la ligne n'est pas déjà au sommet
		; de la pile (cas des boucles)?
.if 1
		ldy	flow_stack
		beq	loop

		lda	if_stack,y
		tay

		lda	if_table+if_item::if_line,y
		cmp	linenum
		bne	push

		lda	if_table+if_item::if_line+1,y
		cmp	linenum+1
		beq	end
.endif
		; linenum = n° de ligne à trouver dans la table
	push:
		ldy	#$00
		; ldx	#$00

	loop:
		cpy	if_ptr
		beq	@ok
		bcs	err_notfound

	@ok:
		lda	if_table,y
		cmp	linenum
		bne	next
		lda	if_table+1,y
		cmp	linenum+1
		beq	found
	next:
		clc
		tya
		adc	#.sizeof(if_item)
		tay
		; inx
		bne	loop

	err_notfound:
		sec
		lda	#ENOENT
		rts

	found:
		; Y = offset dans la table
		inc	flow_stack
		tya
		ldy	flow_stack
		cpy	#IF_MAX
		bcs	err_ovf

		sta	if_stack,y

	end:
		clc
		lda	#EOK
		rts

	err_ovf:
		lda	#ENOMEM
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
.proc pop_else
		ldy	flow_stack
		beq	err_empty

		lda	if_stack,y
		tay

		; Numéro de ligne du bloc else
		lda	if_table+if_item::else_line,y
		sta	linenum
		lda	if_table+if_item::else_line+1,y
		sta	linenum+1
		; Si numéro de ligne == 0 alors il n'y a pas de else => endif
		ora	linenum
		beq	pop_endif

		; Offset du bloc else
		lda	if_table+if_item::else_offset,y
		sta	fpos
		sta	fpos_text
		lda	if_table+if_item::else_offset+1,y
		sta	fpos+1
		sta	fpos_text+1
		lda	if_table+if_item::else_offset+2,y
		sta	fpos+2
		sta	fpos_text+2
		lda	if_table+if_item::else_offset+3,y
		sta	fpos+3
		sta	fpos_text+3

		jsr	buffer_reset
		clc
		rts

	err_empty:
		sec
		lda	#ERANGE
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
.proc pop_endif
		ldy	flow_stack
		beq	err_empty

		lda	if_stack,y
		tay

		; Numéro de ligne du bloc else
		lda	if_table+if_item::endif_line,y
		sta	linenum
		lda	if_table+if_item::endif_line+1,y
		sta	linenum+1

		; Offset du bloc else
		lda	if_table+if_item::endif_offset,y
		sta	fpos
		sta	fpos_text
		lda	if_table+if_item::endif_offset+1,y
		sta	fpos+1
		sta	fpos_text+1
		lda	if_table+if_item::endif_offset+2,y
		sta	fpos+2
		sta	fpos_text+2
		lda	if_table+if_item::endif_offset+3,y
		sta	fpos+3
		sta	fpos_text+3

		dec	flow_stack

		jsr	buffer_reset
		clc
		rts

	err_empty:
		sec
		lda	#ERANGE
		rts
.endproc

