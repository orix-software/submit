;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"

;----------------------------------------------------------------------
;			includes SDK
;----------------------------------------------------------------------
.include "SDK.mac"

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------
;.include "macros/utils.mac"
;.include "macros/SDK-ext.mac"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.importzp ptr

.import save_a, save_y
.import submit_line
.import error_level

.import skip_spaces

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_choice

;----------------------------------------------------------------------
;			Chaines statiques
;----------------------------------------------------------------------
.pushseg
	.segment "RODATA"
		default_msg:
			.asciiz "YN"
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
;		ptr
;		submit_line
;		errorlevel
;	Utilisées:
;		default_msg
;		KBDCTC
; Sous-routines:
;	skip_spaces
;	string_delim
;	count_choices
;	XWSTR0
;	cputc
;	XVIDBU
;	crlf
;----------------------------------------------------------------------
.proc cmnd_choice
		; TODO: à transformer en commande externe

		; Liste de choix par défaut
		sta	save_a

		lda	#<default_msg
		sta	ptr
		lda	#>default_msg
		sta	ptr+1

		lda	#$00
		sta	save_y

	get_params:
		lda	save_a

		; Paramètres?
		jsr	skip_spaces
		beq	disp_choices

		sta	save_a

		lda	submit_line,x
		cmp	#'-'
		bne	disp_text

		; -n?
		lda	submit_line+1,x
		cmp	#'n'
		bne	param_c
		ror	save_y
		inx
		inx
		jmp	get_params

		; -c?
	param_c:
		cmp	#'c'
		bne	disp_text

		lda	submit_line+2,x
		beq	disp_text
		cmp	#' '
		beq	disp_text

		; Un seul inx parce que loop_choices commence par un inx
		inx
		; inx

		clc
		lda	save_a
		adc	#$02
		sta	ptr
		bcc	skip
		iny
	skip:
		sty	ptr+1

	loop_choices:
		inx
		lda	submit_line,x
		beq	disp_choices
		cmp	#' '
		beq	get_params

		; Si insensible à la casse
		; Conversion minuscules / majuscules
		cmp	#'a'
		bcc	store_choice
		cmp	#'z'+1
		bcs	store_choice
		sbc	#'a'-'A'-1

	store_choice:
		sta	submit_line,x
		bne	loop_choices

		; Ajuste AY
	ajuste:
		clc
		txa
		adc	#<submit_line
		sta	save_a
		bcc	spaces
		iny

	spaces:
		jsr	skip_spaces
		beq	disp_choices
		sta	save_a

	disp_text:
		lda	save_a
		jsr	string_delim
		.byte	$00, XWSTR0
		cputc	' '

	disp_choices:
		lda	save_y
		bpl	loop_start
		jsr	count_choices
		jmp	input

	loop_start:
		cputc	'['
		ldy	#$00

	disp_loop:
		lda	(ptr),y
		cputc
		iny
		lda	(ptr),y
		beq	end_choices
		cmp	#' '
		beq	end_choices
		cputc	','
		jmp	disp_loop

	end_choices:
		sty	save_x
		cputc	']'
		cputc	'?'


	input:
		; Vide le buffer clavier
                ldx     #$00
                .byte	$00, XVIDBU
		asl	KBDCTC

		; cursor	on

	loop:
		; Initialise errorlevel
		lda	#$00
		sta	errorlevel
		sta	errorlevel+1

		cgetc
		asl	KBDCTC
		bcs	break

		; Si insensible à la casse
		; Conversion minuscules / majuscules
		cmp	#'a'
		bcc	compare
		cmp	#'z'+1
		bcs	compare
		sbc	#'a'-'A'-1

	compare:
		ldy	save_x

	compare_loop:
		dey
		bmi	loop
		cmp	(ptr),y
		bne	compare_loop

	end:
		iny
		sty	errorlevel
		cputc

	break:
		; cursor	off
		crlf

		clc
		rts

	;----------------------------------------------------------------------
	;
	; Entrée:
	;	-
	; Sortie:
	;	-
	; Variables:
	;	Modifiées:
	;		save_x
	;	Utilisées:
	;		ptr
	; Sous-routines:
	;	-
	;----------------------------------------------------------------------
	.proc count_choices
			ldy	#$ff

		loop:
			iny
			lda	(ptr),y
			beq	end
			cmp	#' '
			bne	loop

		end:
			sty	save_x
			rts
	.endproc
.endproc

