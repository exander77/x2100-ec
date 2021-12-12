.global _start
_start:
.org 0x10000
.byte 0

# Standard variables from the EC.
.org 0x10024 - 2
next_bat_query_ptr:

.org 0x10058 - 2
bat_query_ptr_idx2:

.org 0x10059 - 2
smbus_waiting_completion:

.org 0x10076 - 2
smb_buf_cmds:

.org 0x10164 - 2
bat_query_opc0_smbus_id:

.org 0x10165 - 2
bat_query_opc0_i2c_addr:

.org 0x10834 - 2
smb_bufs:

# Variables defined by me.
.org 0x10c00 - 2
jmp_buf:

.org 0x10c04 - 2
didexec:

.org 0x20ffa - 2
ec_cmd_81_patch_cmp_fb_src:
	BR ec_cmd_81_patch_cmp_fb@m

.org 0x21022 - 2
ec_cmd_81_handle_fb:

.org 0x21034 - 2
ec_cmd_81_ret:

.org 0x2d000 - 2
ec_cmd_81_patch_cmp_fb:
	CMPW $0xfb, r2
	BEQ ec_cmd_81_handle_fb
	CMPW $0xfc, r2
	BEQ ec_cmd_81_handle_fc
	BR ec_cmd_81_ret
ec_cmd_81_handle_fc:
	CMPW $0x00, r3
	BEQ ec_cmd_81_handle_fc_00
	CMPW $0x01, r3
	BEQ ec_cmd_81_handle_fc_01
	BR ec_cmd_81_ret
ec_cmd_81_handle_fc_00:
	MOVD $jmp_buf@m, (r1, r0)
	LOADD *0x0(r1, r0), (r1, r0)
	JAL (r1, r0)
	BR ec_cmd_81_ret
ec_cmd_81_handle_fc_01:
	MOVD $patchloader_buf@m, (r1, r0)
1:
	LOADD *0x0(r1, r0), (r3, r2)
	ADDD $0x4, (r1, r0)
	LOADB *0x0(r1, r0), r4
	CMPW $0x00, r4
	BEQ 3f
	ADDD $0x1, (r1, r0)
2:
	LOADB *0x0(r1, r0), r5
	STORB r5, *0x0(r3, r2)
	ADDD $1, (r1, r0) # src
	ADDD $1, (r3, r2) # dest
	ADDB $-1, r4 # bytes to go
	CMPB $0x00, r4
	BEQ 1b # outer loop
	BR 2b
3:
	BR ec_cmd_81_ret

safetarget:
	MOVD $didexec@m, (r3, r2)
	LOADB *0x0(r3, r2), r0
	ADDB $1, r0
	STORB r0, *0x0(r3, r2)
	JUMP (ra)

# Variable from me.
.org 0x2e000 - 2
patchloader_buf:
	.byte 0, 0, 0, 0, 0
# Patchbuffer format: 4byte address, 1b length, [length] bytes, then a zero
# length to terminate
