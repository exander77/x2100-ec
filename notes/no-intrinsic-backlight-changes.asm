.global _start
_start:
.org 0x10000
.byte 0

.org 0x2109a - 2
	POPRET $0x02, ra
	nop

.org 0x210b2 - 2
	POPRET $0x02, ra
	nop
