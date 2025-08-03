.ifndef CMNDS_INC
	;----------------------------------------------------------------------
	;				imports
	;----------------------------------------------------------------------
	.import	cmnd_at
	; .import	cmnd_call
	.import	cmnd_cd
	.import	cmnd_choice
	.import	cmnd_cls
	.import	cmnd_echo
	; .import	cmnd_exist
	.import	cmnd_exit
	.import	cmnd_goto
	.import cmnd_iif
	.import	cmnd_if
	.import	cmnd_else
	.import	cmnd_endif
	; .import	cmnd_more
	.import	cmnd_pause
	.import	cmnd_pwd
	.import	cmnd_rem
	; .import	cmnd_test
	.import	cmnd_type

	.import	cmnd_getkey

	.import	cmnd_call
	.import	cmnd_return
	.import	cmnd_chain

	.import	cmnd_text

	.import	cmnd_restore
	.import	cmnd_save

	.import	cmnd_input

	.import	cmnd_dump
	; Routine dans internal_cmnd.s
	; .import	cmnd_errorlevel

	.import	cmnd_on

	.import	cmnd_exec

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
				string80	"IIF"
				string80	"IF"
				string80	"ELSE"
				string80	"ENDIF"
				; string80	"MORE"
				string80	"PAUSE"
				string80	"PWD"
				string80	"REM"
				; string80	"TEST"
				string80	"TYPE"

				string80	"GETKEY"

				string80	"CALL"
				string80	"RETURN"
				string80	"CHAIN"

				string80	"TEXT"

				string80	"RESTORE"
				string80	"SAVE"

				string80	"INPUT"

				string80	"DUMP"
				string80	"ERRORLEVEL"

				string80	"ON"

				string80	"EXEC"
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
				.word	cmnd_iif
				.word	cmnd_if
				.word	cmnd_else
				.word	cmnd_endif
				; .word	cmnd_more
				.word	cmnd_pause
				.word	cmnd_pwd
				.word	cmnd_rem
				; .word	cmnd_test
				.word	cmnd_type

				.word	cmnd_getkey

				.word	cmnd_call
				.word	cmnd_return
				.word	cmnd_chain

				.word	cmnd_text

				.word	cmnd_restore
				.word	cmnd_save

				.word	cmnd_input

				.word	cmnd_dump
				.word	cmnd_errorlevel

				.word	cmnd_on

				.word	cmnd_exec

			internal_var_table:
				string80	"EXIST"
				string80	"ERRORLEVEL"
				string80	"KEY"
				.byte	$00
	.popseg

		CMNDS_INC = 1
.endif
