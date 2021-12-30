.global _start
_start:
.org 0x10000
.byte 0

.org 0x2204a - 2
jumpfrom:
    BR jumpto@s

.org 0x2213c - 2
jumpto:
