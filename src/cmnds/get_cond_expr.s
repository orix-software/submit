.feature string_escapes

;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
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
.include "submit.inc"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
; From sopt.s
.import spar1
	spar := spar1

; From submit.s
.import submit_line

; From internal_cmnd.s
.importzp ptr
.importzp var1, var2
.import save_a, save_x, save_y
.import string_delim
.import skip_spaces
.import find_var

; From main.s
.import entry

; From scan.s
;.import push_if
;.import pop_else

; From cmnd_exist.s
.import cmnd_exist

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export get_cond_expr

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
		; <: 60 -> 1 => b6
		; =: 61 -> 2 => b7
		; >: 62 -> 3 => b7+b6
		unsigned char cmp_op
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
;		save_a
;		save_x
;		save_y
;		var1
;		var2
;		ptr
;		cmp_op
;	Utilisées:
;		submit_line
;		entry
; Sous-routines:
;	skip_spaces
;	if_string
;	find_var
;	cmnd_exist
;	internal_command
;	spar
;----------------------------------------------------------------------
.proc get_cond_expr
;		jsr	push_if
;		bcs	error

		jsr	skip_spaces
		beq	error

		; if "string1" = "string2"?
		sta	save_a
		lda	submit_line,x
		cmp	#'"'
		bne	if_value
		jsr	if_string
		bcs	error
		beq	found
		; Équivalent à bne false
		; le clc est inutile ici
		; clc
		lda	#$00
		rts
;		jmp	pop_else

	if_value:
		; Initialise la valeur de test par défaut
		lda	#$00
		sta	var2
		sta	var2+1

		; Sauvegarde X en cas d'erreur
		stx	save_x
		; Recherche la variable
		jsr	find_var
		bcs	error_x

		; A: indice de la variable interne
		; (EXIST = pseudo variable 0)
		;pha
		cmp	#$00
		bne	if_var

		; if exist <file> <instruction>
	if_exist:
		jsr	cmnd_exist
		bcs	error
		lda	var1
		beq	found
		; [ inverse le code de retour de exist
		lda	#$00
		; ]
		clc
		rts

	error_x:
		; Restaure X, sinon on indique une erreur à la fin du nom
		; de la variable et non au début
		ldx	save_x

	error:
		sec
		lda	#EINVAL
		rts

	no_value:
		;pla
		ldx	save_x
		lda	#$ff
		sec
		rts

	found:
;		pla
;		pla
;		jsr	skip_spaces
;		jmp	internal_command
		; [ inverse le code de retour de exist / if_string
		lda	#$ff
		;
		clc
		rts

	if_var:
		; Récupère sa valeur
		lda	entry+st_entry::data_ptr
		ldy	entry+st_entry::data_ptr+1
		sta	var1
		sty	var1+1

	; À partir d'ici, le reste est identique

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

		; Ajout comparateur
		sty	ptr
		sta	ptr+1

		; <: 60 -> 1	-> 3C 0011 11 00
		; =: 61 -> 2	-> 3D 0011 11 01
		; >: 62 -> 4	-> 3E 0011 11 10
		; Par défaut: >=
		lda	#($02 | $04)
		sta	cmp_op

		ldy	#$00
		lda	(ptr),y

		ldx	#($01|$04)
		cmp	#'#'
		beq	ok

		cmp	#'0'
		bcc	error

		cmp	#'9'+1
		bcc	num

		cmp	#'>'+1
		bcs	error

		ldx	#$01
		cmp	#'<'
		bcc	error

		beq	ok

		ldx	#$02
		cmp	#'='
		beq	ok

		ldx	#$04
		cmp	#'>'
		bne	error

	ok:
		stx	cmp_op
		inc	ptr
		bne	num
		inc	ptr+1

	num:
		ldy	ptr
		lda	ptr+1
		; Fin ajout


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
		lda	var1+1
		cmp	var2+1
		bne	test
		lda	var1
		cmp	var2

		; IF ERRORLEVEL n xxxx
		; Exécute xxx si ERRORLEVEL >= n
		; À voir pour étendre la syntaxe en autorisant un comparateur (<, =, .>)
	test:
		php
		lda	cmp_op
		plp
		beq	eq
		bcs	gt

	lt:
		and	#$01
		bne	true

	false:
		clc
		rts
;		jmp	pop_else

	sup_equal:
	eq:
		and	#$02
		beq	false
		bne	true

	gt:
		and	#$04
		beq	false

	true:
		; Recalcule l'offset par rapport à submit_line
		; nécessaire pour IIF
		; [
		sec
		lda	save_y
		sbc	#<submit_line
		tax
		; ]
;
;		; Oublie le retour vers internal_command
;		pla
;		pla
;
;		; Relance une recherche avec la nouvelle commande
;		jmp	internal_command
		; [ nécessaire à cause du recalcul de l'offser
		lda	#$ff
		; ]
		clc
		rts

	value_error:
		; pla
		ldx	save_x
		lda	#$fe
		sec
		rts
.endproc

;----------------------------------------------------------------------
; TODO: ajouter test '#'
;
; Entrée:
;	X: offset sur le premier "
;
; Sortie:
;	C: 1-> erreur de syntaxe
;	Z: 1-> string1 = string2
;	Z: 0-> string1 != string2
;
; Variables:
;	Modifiées:
;		save_a
;		save_x
;		var1
;		var2
;
;	Utilisées:
;		- submit_line
; Sous-routines:
;	- string_delim
;	- skip_spaces
;----------------------------------------------------------------------
.proc if_string
		; Pointeur vers le début de la chaîne (après le ")
		stx	save_x
		inc	save_x

		lda	save_a
		jsr	string_delim
		; AY = Adresse de la chaine terminée par un \0
		; X  = Offset vers le \0
		sta	var1
		sty	var1+1

		; Remet le '"' à la fin de la chaîne (pour affichage de la ligne
		; en cas d'erreur)
		lda	#'"'
		sta	submit_line,x

		; Calcul de la longueur de la chaine
		sec
		txa
		sbc	save_x
		sta	var2+1

		; Fin de ligne?
		inx
		jsr	skip_spaces
		beq	error

		; '='?
		sta	save_a
		lda	submit_line,x
		ldy	#$02
		cmp	#'='
		beq	ok

		ldy	#($01|$04)
		cmp	#'#'
		bne	error

	ok:
		sty	cmp_op
		; "string2"
		inx
		lda	save_a
		jsr	skip_spaces
		beq	error

		sta	save_a
		lda	submit_line,x
		cmp	#'"'
		bne	error
		; Pointeur vers le début de la chaîne (après le ")
		stx	save_x
		inc	save_x

		lda	save_a
		jsr	string_delim
		; Sauvegarde poids faible de string2
		sta	var2

		; Remet le '"' à la fin de la chaîne (pour affichage de la ligne
		; en cas d'erreur)
		lda	#'"'
		sta	submit_line,x

		; Ajuste X pour pointer après string2
		inx
		; Calcul de la longueur de la chaine
		; (faire clc et non sec à cause du inx juste au dessus)
		;sec
		clc
		txa
		sbc	save_x
		; Même longueur que string1?
		cmp	var2+1
		bne	string_neq

	string_cmp:
		; Sauvegarde poids fort de string2
		sty	var2+1

		; Sauvegarde la longueur des chaines
		tay

;		; Ajuste X pour pointer après string2
;		inx

	string_loop:
		dey
		bmi	string_eq
		lda	(var1),y
		cmp	(var2),y
		beq	string_loop

	string_neq:
		; Si on arrive ici -> Z=0
		; Inversion si pas '='
		lda	cmp_op
		and	#$02			; =
		clc
		rts

	string_eq:
		; On peut arriver ici via le bmi string_eq
		; donc on force Z=1
;		iny
		; Inversion si '#'
		lda	cmp_op
		and	#($01|$04)		; #
		clc
		rts

	error:
		sec
		rts
.endproc

