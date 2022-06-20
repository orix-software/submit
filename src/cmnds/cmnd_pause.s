;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"

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
.import skip_spaces, string_delim

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_pause

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
.proc cmnd_pause
		jsr	skip_spaces
		beq	default

		jsr	string_delim

		.byte	$00, XWSTR0
		jmp	pause

	default:
		prints	"\x1bLPress any key to continue."

	pause:
		cgetc
		prints	"\r\x0e"
		clc
		rts
.endproc


