
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
.include "macros/SDK-ext.mac"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_version

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------

;----------------------------------------------------------------------
;				Page Zéro
;----------------------------------------------------------------------

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------

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
;	- prints
;----------------------------------------------------------------------
.proc cmnd_version
        prints  "submit version 1.0 - 2022.2\r\n"
        rts
.endproc

;----------------------------------------------------------------------
;			Chaines statiques
;----------------------------------------------------------------------