.macro LOAD_BEGIN
LOAD_BEGIN_\@:
.endm

.macro LOAD_END
LOAD_END_\@:
.endm

.global _start
_start:
.org 0x10000
.byte 0

# Variables defined by me.
.org 0x10b02 - 2
i2c_buf:

.org 0x10b12 - 2
LOAD_BEGIN
i2c_rv:
	.byte 0x00

i2c_addr_dev:
	.byte 0x12

i2c_addr_reg:
	.byte 0x00

i2c_count:
	.byte 0x00
LOAD_END

.org 0x2663a - 2
delaycyc:

.org 0x26668 - 2
i2c_bitbang_start:

.org 0x266b8 - 2
i2c_bitbang_stop:

.org 0x2672c - 2
i2c_bitbang_do_read_ack:

.org 0x26776 - 2
i2c_bitbang_do_read_nack:

.org 0x267c0 - 2
i2c_bitbang_wait_ack:

.org 0x26818 - 2
i2c_bitbang_wrbyte:

.org 0x2686e - 2
i2c_bitbang_rdbyte:

.org 0x26944 - 2
i2c_bitbang_read_multiple:


.org 0x276d4 - 2
gpio_configure:

# GPIO7,3 is SCL
# GPIO7,4 is SDA

.org 0x2c9a0 - 2
LOAD_BEGIN
bitbang_setup:
	PUSH $0x3, r7, ra

	DI

	# Disable SMB1 and SMB2 (devalt2[7:6])
	LOADB *0xFFF012, r0
	ANDB $0x3F, r0
	STORB r0, *0xFFF012

	MOVW $0x31F, r2
	BAL (ra), *gpio_configure
	MOVW $0x717, r2
	BAL (ra), *gpio_configure

	# set up GPIO7,3 and 7,4 as output
	LOADB *0xFFF272, r0
	ORB $0x18, r0
	STORB r0, *0xFFF272
	
	# set up GPIO7,3 and 7,4 as pull
	LOADB *0xFFF273, r0
	ORB $0x18, r0
	STORB r0, *0xFFF273

	# set up GPIO7,3 and 7,4 as PU
	LOADB *0xFFF274, r0
	ORB $0x18, r0
	STORB r0, *0xFFF274

	POPRET $0x3, r7, ra

bitbang_teardown:
	PUSH $0x3, r7, ra

	MOVW $0x1F, r2
	BAL (ra), *gpio_configure
	MOVW $0x17, r2
	BAL (ra), *gpio_configure

	# Reenable SMB1 and SMB2 (devalt2[7:6])
	LOADB *0xFFF012, r0
	ORB $0xC0, r0
	STORB r0, *0xFFF012

	EI

	POPRET $0x3, r7, ra

### 

i2c_probe:
	PUSH $0x3, r7, ra

	BAL (ra), *bitbang_setup

	BAL (ra), *i2c_bitbang_start:l
	LOADB *i2c_addr_dev, r2
	BAL (ra), *i2c_bitbang_wrbyte:l
	BAL (ra), *i2c_bitbang_wait_ack:l
	STORB r0, *i2c_rv
	BAL (ra), *i2c_bitbang_stop:l

	BAL (ra), *bitbang_teardown

	POPRET $0x3, r7, ra

i2c_read:
	PUSH $0x3, r7, ra

	BAL (ra), *bitbang_setup

	BAL (ra), *i2c_bitbang_start:l
	LOADB *i2c_addr_dev, r2
	BAL (ra), *i2c_bitbang_wrbyte:l
	BAL (ra), *i2c_bitbang_wait_ack:l
	CMPB $0, r0
	MOVB $0xF0, r0
	BNE *i2c_read_failed
	LOADB *i2c_addr_reg, r2
	BAL (ra), *i2c_bitbang_wrbyte:l
	BAL (ra), *i2c_bitbang_wait_ack:l
	CMPB $0, r0
	MOVB $0xF1, r0
	BNE *i2c_read_failed
	
	MOVB $5, r2
	BAL (ra), *delaycyc
	
	BAL (ra), *i2c_bitbang_start:l
	LOADB *i2c_addr_dev, r2
	ADDB $1, r2
	BAL (ra), *i2c_bitbang_wrbyte:l
	BAL (ra), *i2c_bitbang_wait_ack:l
	CMPB $0, r0
	MOVB $0xF2, r0
	BNE *i2c_read_failed
	
	LOADB *i2c_count, r7
	MOVD $i2c_buf, (r9, r8)
i2c_read_next:
	BAL (ra), *i2c_bitbang_rdbyte
	STORB r0, *0x0(r9, r8)
	ADDD $1, (r9, r8)
	SUBB $1, r7
	CMPB $0, r7
	BEQ *i2c_read_done
	BAL (ra), *i2c_bitbang_do_read_ack
	BR *i2c_read_next
	
i2c_read_done:
	BAL (ra), *i2c_bitbang_do_read_nack
	MOVB $0, r0

i2c_read_failed:
	STORB r0, *i2c_rv
	BAL (ra), *i2c_bitbang_stop:l

	BAL (ra), *bitbang_teardown

	POPRET $0x3, r7, ra

LOAD_END
