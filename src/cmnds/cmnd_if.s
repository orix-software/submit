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

XOPENDIR = $2f

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.importzp var1, var2
.import save_a, save_x, save_y
.importzp ptr

.import fp

.import submit_line, line
.import internal_var_table
.import vartab

.import skip_spaces
.import internal_command

.import spar1
	spar := spar1

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_if

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
;		-
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc cmnd_if
		jsr	skip_spaces
		beq	error

		; Initialise la valeur de test par défaut
		lda	#$00
		sta	var2
		sta	var2+1

		lda	#<internal_var_table
		ldy	#>internal_var_table
		clc
		jsr	find_cmnd
		bcs	error

		; A: indice de la variable interne
		;pha
		bne	if_var

		; if exist <file> <instruction>
	if_exist:
		jsr	cmnd_exist
		bcs	error
		lda	var1
		beq	found
		clc
		rts

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
		pla
		pla
		jsr	skip_spaces
		jmp	internal_command

	if_var:
		; Récupère la valeur de la variable
		; On arrive ici avec C=0
		sbc	#$00
		asl
		tay
		lda	vartab,y
		sta	var1
		lda	vartab+1,y
		sta	var1+1

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
		sec
		lda	save_y
		sbc	#<submit_line
		tax

		; Oublie le retour vers internal_command
		pla
		pla

		; Relance une recherche avec la nouvelle commande
		jmp	internal_command

	value_error:
		; pla
		ldx	save_x
		lda	#$fe
		sec
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
.proc cmnd_exist
		jsr	skip_spaces
		beq	error

		stx	save_x
		sta	save_a
		sty	save_y

		; Copie le nom du fichier dans le tampon line
		ldy	#$ff
		dex
	loop:
		inx
		iny
		lda	submit_line,x
		sta	line, y
		beq	open
		cmp	#' '
		bne	loop

		lda	#$00
		sta	line,y

	open:
		sty	save_y
		stx	save_x
		lda	#<line
		ldy	#>line

		jsr	is_dir
		beq	is_file
		lda	#$00
		php
		beq	set_error

	is_file:
		; Supprime le "/*" placé à la fin du nom de fichier par opendir
		; (remet le $00 à sa place)
		ldy	save_y
		lda	#$00
		sta	line,y

		fopen	line, O_RDONLY
		sta	fp
		stx	fp+1
		eor	fp+1
		php

		fclose	(fp)
		; errorlevel: 0-> existe, 1 -> inexistant
		; MSDOS: "if exist xxxx" exist ne modifie par errorlevel

	set_error:
		lda	#$00
		tay
		sta	var1+1
		plp
		bne	end
		iny
	end:
		sty	var1

		; Ajuste AY
		ldx	save_x
		clc
		ldy	#>submit_line
		lda	#<submit_line
		adc	save_x
		bcc	_exit
		iny
	_exit:
		clc
		rts

	error:
		lda	#EINVAL
		sec
		rts

	.proc is_dir
			; Sortie:
			;	Z=0: si c'est un répertoire
			;	Z=1: si le répertoire n'existe pas (mais on peut
			;	     avoir un fichier)

			; opendir()
			;lda	exec_address
			;ldy	exec_address+1
			ldx	#$00
			.byte	$00, XOPENDIR

			cmp	#$ff
			bne	end
			cpx	#$ff

		end:
			; jsr	PrintRegs

			; Sauvegarde le résultat du test
			php
			; closedir()
			ldx	#$02
			.byte	$00, XOPENDIR

			plp
			rts
	.endproc
.endproc

