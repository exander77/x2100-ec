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
smbus_i2c_response_buf:

.org 0x10b12 - 2
LOAD_BEGIN
last_good_address:
	.byte 0xFE, 0x00
LOAD_END

.org 0x10b14 - 2
did_anything_at_all:

.org 0x26668 - 2
i2c_bitbang_start:

.org 0x266b8 - 2
i2c_bitbang_stop:

.org 0x267c0 - 2
i2c_bitbang_wait_ack:

.org 0x26818 - 2
i2c_bitbang_wrbyte:

.org 0x26944 - 2
i2c_bitbang_read_multiple:

.org 0x276d4 - 2
gpio_configure:

# GPIO7,3 is SCL
# GPIO7,4 is SDA

.org 0x2c9a0 - 2
LOAD_BEGIN
bitbang_scan:
	PUSH $0x3, r7, ra

	DI

	MOVW $0x0aaa, r0
	STORW r0, *did_anything_at_all

	# Disable SMB1 and SMB2 (devalt2[7:6])
	LOADB *0xFFF012, r0
	ANDB $0x3F, r0
	STORB r0, *0xFFF012

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

nextaddr:
	BAL (ra), *i2c_bitbang_start:l
	LOADW *last_good_address, r2
	ADDB $2, r2
	STORW r2, *last_good_address
	BAL (ra), *i2c_bitbang_wrbyte:l
	BAL (ra), *i2c_bitbang_wait_ack:l
	CMPB $1, r0
	BNE foundone
	BAL (ra), *i2c_bitbang_stop:l
	BR nextaddr

foundone:
	BAL (ra), *i2c_bitbang_stop:l

	# Reenable SMB1 and SMB2 (devalt2[7:6])
	LOADB *0xFFF012, r0
	ORB $0xC0, r0
	STORB r0, *0xFFF012

	EI

	POPRET $0x3, r7, ra

LOAD_END
