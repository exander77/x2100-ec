.global _start
_start:
.org 0x10000
.byte 0

# Standard variables from the EC.
.org 0x10085 - 2
state_prev:
.org 0x10089 - 2
repeat_counter:

.org 0x233e8 - 2
change:
    BFC jump2@s

.org 0x2352a - 2
jump1:
    BR patch@l

.org 0x23530 - 2
jump2:
    BR done@l

.org 0x236e6 - 2
fce:

.org 0x2ad94 - 2
acpi_report:

.org 0x2c990 -2
patch:
    # is not 0x1113 go check it
    CMPW $0x1113, r2
    BNE check@s
    MOVW $0x0, r0
    BR nocheck@s    
check: # checks repeat counter
    # repeat_counter is > 0, send event, decrease repeat_counter
    LOADB *repeat_counter, r4
    CMPB $0x0, r4
    BEQ check2@s
    SUBB $0x1, r4
    STORB r4, *repeat_counter
    BR nocheck@s
check2: # checks previous state
    # real check passed, set repeat_counter = 1 (possibly increase if issues)
    LOADB *state_prev, r1
    CMPB r1, r0
    BEQ done@s
    STORB $0x1, *repeat_counter
nocheck:
    STORB r0, *state_prev
    BAL (ra), *acpi_report
done:
    BAL (ra), *fce
    POPRET $0x2, r7, ra
