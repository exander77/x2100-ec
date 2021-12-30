.global _start
_start:
.org 0x10000
.byte 0

# Standard variables from the EC.
.org 0x10084 - 2
charging_state:
.org 0x10085 - 2
state_prev:
.org 0x10124 - 2
acpi_6a_present_rate:
.org 0x10159 - 2
charger_is_configured: #0 no charger
.org 0x1015b - 2
chargesm_output_15b: #0 no battery

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
    LOADB *charger_is_configured, r0
    LOADB *chargesm_output_15b, r1
    CMPB $0, r1
    BEQ no_battery@s
    ORB $2, r0
no_battery:
    LOADB *state_prev, r1
    CMPB r1, r0
    BEQ done@s
    STORB r0, *state_prev
    BAL (ra), *acpi_report
done:
    BAL (ra), *fce
    POPRET $0x2, r7, ra
