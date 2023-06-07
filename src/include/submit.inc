.ifndef SUBMIT_INC
	ident_len = 10

	typedef .struct st_entry
		unsigned char name[10+1]
		unsigned char type		; 'C', 'N'
		unsigned char len
		unsigned short data_ptr
		.ifdef USE_LINKEDLIST
			unsigned short _next_ptr
			unsigned char _occupied
		.endif
	.endstruct

	ST_ENTRYLEN = .sizeof(st_entry)

	.ifdef USE_LINKEDLIST
		ENTRY_LEN = ST_ENTRYLEN - 3
	.else
		ENTRY_LEN = ST_ENTRYLEN
	.endif

	VARS_MAX = 256/ST_ENTRYLEN
	VARS_DATALEN = 32

	.out .sprintf("256/ST_ENTRYLEN = %d", VARS_MAX)

	FILENAME_LEN = 30

	; Pour find_cmnd
	CASE_SENSITIVE_LABELS .set 0
	; de main.s
	LINE_MAX_SIZE = 128

	SUBMIT_LINE_MAX_SIZE = 200

	SUBMIT_INC = 1
.endif
