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
.import forward_label, label_num, label_line
.import label_offsets, labels
.import line

.import skip_spaces, find_cmnd

.import cmnd_label

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_goto

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
CASE_SENSITIVE_LABELS .set 0
; de main.s
LINE_MAX_SIZE = 128

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
		unsigned long prev_fpos_save
		unsigned long fpos_text_save

		unsigned char save_label[20]
		unsigned char save_linenum[2]
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
.proc cmnd_goto
		jsr	skip_spaces
		beq	error

		stx	save_y

		; Table des labels vide?
		lda	label_num
		beq	not_found

		; Cherche dans la table des labels
		lda	#<labels
		ldy	#>labels
.if ::CASE_SENSITIVE_LABELS
		sec
.endif
		jsr	find_cmnd
		bcs	not_found

		; Récupère le numéro de la ligne
		asl
		tax
		lda	label_line,x
		sta	linenum
		lda	label_line+1,x
		sta	linenum+1,x
		txa

		; Récupère l'offset du label
		asl
		tax
		lda	label_offsets,x
		sta	fpos
		sta	fpos_text
		lda	label_offsets+1,x
		sta	fpos+1
		sta	fpos_text+1
		lda	label_offsets+2,x
		sta	fpos+2
		sta	fpos_text+2
		lda	label_offsets+3,x
		sta	fpos+3
		sta	fpos_text+3

		; Utile uniquement si fichier TEXTE
		jsr	buffer_reset

		clc
		rts

	not_found:
		; On a déjà parcouru tout le fichier?
		lda	forward_label
		bne	find_label
		sec
		lda	#ERANGE
		rts

	error:
		sec
		lda	#EINVAL
		rts

	find_label:
		; Sauvegarde la position dans le fichier
		ldx	#$03
	save_fpos:
		lda	prev_fpos,x
		sta	prev_fpos_save,x
		; Utile uniquement si fichier TEXTE
		lda	fpos_text
		sta	fpos_text_save,x
		dex
		bpl	save_fpos

		; Sauvegarde le numéro de ligne
		lda	linenum
		sta	save_linenum
		lda	linenum+1
		sta	save_linenum+1

		jsr	submit_reopen

		; Sauvegarde le label à trouver
		jsr	store_label
		bcc	loop
		rts

		; Lecture du fichier jusqu'à la fin ou jusqu'à ce qu'on trouve
		; le label
	loop:
		lda	#<line
		ldy	#>line
		ldx	#LINE_MAX_SIZE
		jsr	fgets
		bcs	eof

		; TODO: vérifier si cmnd_label accepte des ' ' avant ':'
		; On a un label?
		ldx	#$00
		lda	line,x
		cmp	#':'
		bne	loop

		; Récupère l'adresse de la ligne suivant le ':label'
		jsr	ftell

		lda	#<line
		ldy	#>line
		; On saute le ':'
		inx
		jsr	submit
		jsr	cmnd_label
		bcs	error_label
		jsr	search_label
		bcs	loop

		; On a trouvé le label, inutile de continuer la recherche
		;jsr	end
		;jmp	cmnd_goto
		jsr	submit_close
		rts

	eof:
		lda	#$00
		sta	forward_label
		jsr	end
		; Si on a vérifier le label au fur et à mesure
		jmp	not_found
		; sinon
		;pla
		;pla
		;lda	#<submit_line
		;ldy	#>submit_line
		;jmp	cmnd_goto

	end:
		jsr	submit_close

		; Restaure la position dans le fichier
		ldx	#$03
	restore_fpos:
		lda	prev_fpos_save,x
		sta	fpos,x
		; Utile uniquement si fichier TEXTE
		lda	fpos_text_save
		sta	fpos_text,x
		dex
		bpl	restore_fpos

		; Utile uniquement si fichier TEXTE
		jsr	buffer_reset

		; Recharge la ligne...
		jsr	submit_reopen
		lda	#<line
		ldy	#>line
		ldx	#LINE_MAX_SIZE
		jsr	fgets
		; bcs	error
		jsr	submit_close
		lda	#<line
		ldy	#>line
		ldx	#$00
		jsr	submit

		; ...et son numéro
		lda	save_linenum
		sta	linenum
		lda	save_linenum+1
		sta	linenum+1

		; Restaure l'offset dans la ligne
		ldx	save_y

		rts

	error_label:
		sta	save_a
		jsr	end
		lda	save_a
		sec
		rts

	.proc store_label
			ldx	save_y
			ldy	#$00
		loop:
			lda	submit_line,x
			sta	save_label,y
			beq	end
			cmp	#' '
			beq	end
			inx
			iny
			cpy	#20
			bne	loop

		oom:
			; Label trop long
			sec
			lda	#$f3
			rts

		end:
			lda	#$00
			sta	save_label,y
			clc
			rts
	.endproc

	.proc search_label
			ldx	#$ff
		loop:
			inx
			lda	save_label,x
			sta	submit_line,x
			bne	loop

			ldx	#$00
			lda	#<labels
			ldy	#>labels

	.if ::CASE_SENSITIVE_LABELS
			sec
	.endif
			jsr	find_cmnd
			rts

	.endproc
.endproc


