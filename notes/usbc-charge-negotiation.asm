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
.org 0x10b02 - 2
smbus_i2c_response_buf:

.org 0x10b12 - 2
smbus_opc80_done:

.org 0x21558 - 2
smb_get_rxdata_ptr:

.org 0x2380c - 2
set_bat_query_ptr:

# Patch SMBusRoutine to support a new opcode, 0x80, which does a 16-byte
# read.
.org 0x238f6 - 2
SMBusRoutine_patch_issuecmd_from:
# was: BR SMBusRoutine_patch_ret
	BR SMBusRoutine_patch_issuecmd@m

.org 0x23a9c - 2
SMBusRoutine_patch_checkcmd_from:
# was: CMPW $0x3, 2; BReq *0x23ab2:s; BR *0x23b0a:s
	BR SMBusRoutine_patch_checkcmd@m

.org 0x23ab2 - 2
SMBusRoutine_checkcmd_opc03:

.org 0x23b0a - 2
SMBusRoutine_patch_checkcmd_ret:

.org 0x23b1e - 2
SMBusRoutine_patch_ret:

.org 0x2535a - 2
smb_trans:


.org 0x2c9a0 - 2
# Add a custom opcode, 0x80, which does a 16-byte read
SMBusRoutine_patch_issuecmd:
	CMPW $0x80, r0
	BEQ SMBusRoutine_patch_opc_80
	BR SMBusRoutine_patch_ret@l

SMBusRoutine_patch_opc_80:
	# basically, set up a smb_query_read, but very long.  we use opc0's
	# smbus ID, opc0's i2c addr, the bat_fun from this query, and we
	# don't stash the dest (we'll look at it later in the return...
	# eventually).
	LOADD *next_bat_query_ptr, (r1,r0)
	LOADB *bat_query_ptr_idx2, r2
	MOVZB r2, r2
	MOVZW r2, (r3, r2)
	ASHUD $0x3, (r3, r2)
	ADDD (r3, r2), (r1, r0)
	LOADB *0(r1, r0), r4 # bat_fun

	LOADB *bat_query_opc0_smbus_id, r2
	LOADB *bat_query_opc0_i2c_addr, r3
	MOVB $0x1, r5 # int_en
	
	bal (ra), *smb_query_read_16byte
	
	storb $0x1, *smbus_waiting_completion
	
	BR SMBusRoutine_patch_ret@l

smb_query_read_16byte:
	push $0x3, r7, ra
	push $0x1, r7
	
	movb r2, r9
	movw r5, r8
	movzb r2, r0
	movzw r0, (r1, r0)
	movd (r1, r0), (r7, r6)
	ashud $0x3, (r7, r6)
	addd (r1, r0), (r7, r6)
	ashud $0x2, (r7, r6)
	addd (r1, r0), (r7, r6)
	addd $smb_bufs, (r7, r6)

	movzb r2, r0
	movzw r0, (r1, r0)
	addd $smb_buf_cmds, (r1, r0)
	
	movb $0xd0, r2
	storb r2, *0x0(r1, r0) # smb_cmd_buf
	storb r2, *0x0(r7, r6) # smb_buf.cmd
	storb $2, *0x1(r7, r6) # smb_buf.txlen
	storb r3, *0x2(r7, r6) # smb_buf.i2caddr
	storb r4, *0x3(r7, r6) # smb_buf.i2c_opc
	
	movzb r9, r0
	movzw r0, (r1, r0)
	movd (r1, r0), (r3, r2)
	ashud $0x3, (r3, r2)
	addd (r1, r0), (r3, r2)
	ashud $0x2, (r3, r2)
	addd (r1, r0), (r3, r2)
	addd $smb_bufs, (r3, r2)
	movb r9, r4
	# r5 remains same as input, int_en
	bal (ra), *smb_trans
	
	cmpw $0x0, r8
	beq 1f
	movd $0x0, (r1, r0)
	beq 2f
1:
	movb r9, r2
	bal (ra), *smb_get_rxdata_ptr
2:
	addd $0x2, (sp)
	popret $0x3, r7, ra

SMBusRoutine_patch_checkcmd:
	CMPW $0x3, r0
	BEQ SMBusRoutine_checkcmd_opc03@m
	CMPW $0x80, r0
	BEQ SMBusRoutine_patch_checkcmd_opc80
	BR SMBusRoutine_patch_checkcmd_ret@m

SMBusRoutine_patch_checkcmd_opc80:
	# can trash r1r0, r5r4
	MOVD $smbus_i2c_response_buf, (r5, r4)
	LOADW *0x0(r3, r2), r0
	STORW r0, *0x0(r5, r4)
	LOADW *0x2(r3, r2), r0
	STORW r0, *0x2(r5, r4)
	LOADW *0x4(r3, r2), r0
	STORW r0, *0x4(r5, r4)
	LOADW *0x6(r3, r2), r0
	STORW r0, *0x6(r5, r4)
	LOADW *0x8(r3, r2), r0
	STORW r0, *0x8(r5, r4)
	LOADW *0xa(r3, r2), r0
	STORW r0, *0xa(r5, r4)
	LOADW *0xc(r3, r2), r0
	STORW r0, *0xc(r5, r4)
	LOADW *0xe(r3, r2), r0
	STORW r0, *0xe(r5, r4)
	MOVD $smbus_opc80_done, (r5, r4)
	LOADB *0x0(r5, r4), r0
	ADDB $1, r0
	STORB r0, *0x0(r5, r4)

	BR SMBusRoutine_patch_checkcmd_ret@m

# Set up a read from i2c_addr = 0x70, smbus_id = 1, register 0x04 (should
# return 'I2C '.
TPS65987D_smbus_query:
	.byte 0x70 # i2c_addr
	.byte 0x00 # opcode SETUP
	.byte 0x01, 0x00 # SMBUS ID 1
	.long TPS65987D_smbus_callback@c
	
	.byte 0x04 # register 0x04
	.byte 0x80 # new opcode
	.byte 0x00, 0x00
	.long smbus_i2c_response_buf
	
	.byte 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 # done

TPS65987D_smbus_callback:
	MOVD $smbus_opc80_done, (r3, r2)
	LOADB *0x0(r3, r2), r0
	ADDB $1, r0
	STORB r0, *0x0(r3, r2)
	movw $0xff, r0
	jump (ra)

TPS65987D_call:
	PUSH $0x3, r7, ra
	MOVD $TPS65987D_smbus_query, (r3, r2)
	BAL (ra), *set_bat_query_ptr
	POPRET $0x3, r7, ra
	