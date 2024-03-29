
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
VERSION = $20233013
.define PROGNAME "submit"

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
		.out .sprintf("%s version: %x.%x - %x.%x", PROGNAME, ::VERSION >> 16, (::VERSION & $f000)>>12 , (::VERSION & $ff0)>>4, (::VERSION & $0f))

;	        prints  "submit version 1.0 - 2022.2\r\n"
		prints  .sprintf("%s version %x.%x - %x.%x\r\n", PROGNAME, (::VERSION & $ff0)>>4, (::VERSION & $0f), ::VERSION >> 16, (::VERSION & $f000)>>12)
		rts
.endproc

;----------------------------------------------------------------------
;			Chaines statiques
;----------------------------------------------------------------------
