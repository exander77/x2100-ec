#!/usr/bin/env python3

import argparse
from ec import *

did_something = False
ec = NPCE9MNX()

parser = argparse.ArgumentParser(description='Interact with an X2100 EC.')
def mkaction(*args, func = None, **kwargs):
    class CallableAction(argparse.Action):
        def __call__(self, parser, namespace, values, option_string = None):
            func(values)
    parser.add_argument(action = CallableAction, *args, **kwargs)

def dump_all(args):
    for (module,regs) in ec.modulelist:
        print("----------")
        print(module)
        print("----------")
        ec.dump_module(module)
    global did_something
    did_something = True
mkaction('--dump-all', help = 'Dump all registers.', nargs = 0, func = dump_all)

def dump_gpios(args):
    for gpio in range(ec.GPIO_COUNT):
        ec.dump_module(f"GPIO{gpio:X}")
    global did_something
    did_something = True
mkaction('--dump-gpios', help = 'Dump all GPIO registers.', nargs = 0, func = dump_gpios)

def dump_module(args):
    for module in args:
        ec.dump_module(module)
        global did_something
        did_something = True
mkaction('--dump-module', help = 'Dump one module.', metavar = "MODULE", nargs = 1, func = dump_module)

def dump_register(args):
    for reg in args:
        nreg = ec.regs[reg]
        nreg.print(ec.read8(nreg.adr))
        global did_something
        did_something = True
mkaction('--dump-register', help = 'Dump one register.', metavar = "REGISTER", nargs = 1, func = dump_register)

def write_register(args):
    reg = args[0]
    da = int(args[1], 16)
    print(f"0x{ec.regs[reg].adr:06x} ({reg:12s}) <- 0x{da:02x}")
    ec.write8(ec.regs[reg].adr, da)
mkaction('--write-register', help = 'Write a value to a register. (BE CAREFUL!)', nargs = 2, metavar=("REGISTER", "HEX_VALUE"), func = write_register)
args = parser.parse_args()

if not did_something:
    parser.print_help()
