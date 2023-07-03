.ifndef CMNDS_INC
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
				string80	"IF"
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
				.word	cmnd_if
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

			internal_var_table:
				string80	"EXIST"
				string80	"ERRORLEVEL"
				string80	"KEY"
				.byte	$00
	.popseg

		CMNDS_INC = 1
.endif
