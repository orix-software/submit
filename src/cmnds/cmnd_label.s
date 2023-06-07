;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"
.include "errno.inc"

;----------------------------------------------------------------------
;			includes SDK
;----------------------------------------------------------------------
.include "SDK.mac"
.include "types.mac"

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

.import skip_spaces, find_cmnd

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_label
.export cmnd_dump

.export forward_label, label_num, label_line
.export label_offsets, labels
.export label_ofs

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
CASE_SENSITIVE_LABELS .set 0
MAX_LABELS = 25
LABEL_TABLE_SIZE = 128

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
		; Offset dans la table labels
		unsigned char label_ofs
		; Table des labels
		unsigned char labels[LABEL_TABLE_SIZE]

		unsigned char label_num
		unsigned long label_offsets[MAX_LABELS]
		unsigned short label_line[MAX_LABELS]

		unsigned char forward_label
.popseg

;----------------------------------------------------------------------
;			Programme principal
;----------------------------------------------------------------------
.segment "CODE"

;----------------------------------------------------------------------
;
; Entrée:
;	X: offset sur le premier caractère suivant la commande
; Sortie:
;
; Variables:
;	Modifiées:
;		save_x
;		labels
;		label_num
;		label_ofs
;		label_line
;		label_offsets
;	Utilisées:
;		submit_line
;		linenum
;		fpos_text
; Sous-routines:
;	skip_spaces
;	find_cmnd
;----------------------------------------------------------------------
.proc cmnd_label
		jsr	skip_spaces
		beq	error

		stx	save_x

		; Recherche si le label est déjà dans la table
		; /!\ Si on le trouve, il faut vérifier si l'offset est le même
		;     dans ce cas il s'agit d'un doublon et il faut indiquer une
		;     erreur.
		lda	#<labels
		ldy	#>labels

.if ::CASE_SENSITIVE_LABELS
		;Case sensitive
		;sinon il faut convertir le label en majuscules dans la table
		sec
.endif
		jsr	find_cmnd
		bcc	found

		; Nombre maximal de labels atteint?
		lda	label_num
		cmp	#MAX_LABELS
		bcs	ovfError

;		clc
;		ldy	#>submit_line
;		lda	#<submit_line
;		adc	save_x
;		bcc	save_label
;		iny

	save_label:
;		sta	ptr
;		sty	ptr+1
;		ldx	#$00
		ldy	label_ofs

	loop:
		lda	submit_line, x
		beq	saved
		cmp	#' '
		beq	saved

.if .not ::CASE_SENSITIVE_LABELS
		; Conversion minuscules / majuscules
		cmp	#'a'
		bcc	store
		cmp	#'z'+1
		bcs	store
		sbc	#'a'-'A'-1
	store:
.endif
		sta	labels, y

		inx
		iny
		cpy	#$80
		bne	loop

	ovfError:
		sec
		lda	#ENOMEM
		rts

	error:
		sec
		lda	#EINVAL
		rts

	saved:
		; Dernier caractère +$80
		dey
		lda	labels, y
		ora	#$80
		sta	labels, y

		; Marque la fin de la table
		iny
		lda	#$00
		sta	labels, y

		sty	label_ofs

		; Sauvegarde le numéro de la ligne suivante du label
		lda	label_num
		asl
		tax
		lda	linenum
		sta	label_line,x
		lda	linenum+1
		sta	label_line+1,x

		; Sauvegarde l'offset de la ligne suivant le label
		txa
		asl
		tax
		lda	fpos_text
		sta	label_offsets,x
		lda	fpos_text+1
		sta	label_offsets+1,x
		lda	fpos_text+2
		sta	label_offsets+2,x
		lda	fpos_text+3
		sta	label_offsets+3,x

		inc	label_num
	end:
		clc
		rts

	found:
		asl
		asl
		tax
		lda	fpos_text
		cmp	label_offsets,x
		bne	redefined
		lda	fpos_text+1
		cmp	label_offsets+1,x
		bne	redefined
		lda	fpos_text+2
		cmp	label_offsets+2,x
		bne	redefined
		lda	fpos_text+3
		cmp	label_offsets+3,x
		bne	redefined
		clc
		rts

	redefined:
		ldx	save_x
		lda	#EEXIST
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
;		save_x
;		ptr
;	Utilisées:
;		label_num
;		labels
;		label_line
; Sous-routines:
;	PrintHexByte
;	cputc
;	crlf
;	prints
;	XDECIM
;----------------------------------------------------------------------
.proc cmnd_dump
		; Affiche le num&ro de ligne
		;lda	linenum+1
		;jsr	PrintHexByte
		;lda	linenum
		;jsr	PrintHexByte
		;crlf

		lda	label_num
		beq	end

		ldx	#$00
		stx	ptr
		stx	save_x

	again:
		; Affiche la ligne du label
		lda	labels,x
		beq	end
		lda	ptr
		asl
		tax
		lda	label_line+1,x
		jsr	PrintHexByte
		lda	label_line,x
		jsr	PrintHexByte
		cputc	':'

		ldx	save_x
	loop:
		lda	labels,x
		beq	end
		bmi	last
		cputc
		inx
		bne	loop
		beq	end

	last:
		and	#$7f
		cputc
		inx
		stx	save_x


		; Affiche l'offset du label
;		lda	ptr
;		asl
;		asl
;		tax
;		lda	label_offsets+1,x
;		tay
;		lda	label_offsets, x
;		ldx	#$03
;		.byte	$00, XDECIM

		crlf

		inc	ptr
		ldx	save_x
		bne	again

	end:
		prints	"\r\nTable size: "
		lda	save_x
		ldy	#$00
		ldx	#$02
		.byte	$00, XDECIM
		cputc	'/'

		lda	#LABEL_TABLE_SIZE
		ldy	#$00
		ldx	#$02
		.byte	$00, XDECIM

		crlf

		clc
		rts

.endproc

