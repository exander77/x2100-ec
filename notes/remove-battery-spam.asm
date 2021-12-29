.global _start
_start:
.org 0x10000
.byte 0

# Standard variables from the EC.
.org 0x10084 - 2
charging_state:
.org 0x10085 - 2
charging_state_prev:

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
#   POPRET $0x2, r7, ra
#   LOADB *charging_state, r0
    LOADB *charging_state_prev, r1
    CMPB r1, r0
    BEQ done@s
    STORB r0, *charging_state_prev
    BAL (ra), *acpi_report
done:
    BAL (ra), *fce
    POPRET $0x2, r7, ra
