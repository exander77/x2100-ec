#!/usr/bin/env python3

import argparse
from ec import *

from elftools.elf.elffile import ELFFile
from elftools.elf.sections import SymbolTableSection

did_something = False
ec = NPCE9MNX()

parser = argparse.ArgumentParser(description='Interact with an X2100 EC.')
def mkaction(*args, func = None, **kwargs):
    class CallableAction(argparse.Action):
        def __call__(self, parser, namespace, values, option_string = None):
            func(values)
    parser.add_argument(action = CallableAction, *args, **kwargs)

# Commands to introspect EC register state.

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
    global did_something
    did_something = True
mkaction('--write-register', help = 'Write a value to a register. (BE CAREFUL!)', nargs = 2, metavar=("REGISTER", "HEX_VALUE"), func = write_register)

def read(args):
    addr = int(args[0], 16)
    print(f"0x{addr:x}: 0x{ec.read8(addr):02x}")
    global did_something
    did_something = True
mkaction("--read", help = 'Read an address in memory.', nargs = 1, metavar = 'ADDRESS', func = read)

# Commands to modify EC memory.
patch_pending = None
patch_syms = None

def elf(args):
    with open(args[0], 'rb') as f:
        elffile = ELFFile(f)
        
        if elffile.header.e_machine != 'EM_CR16':
            raise ValueError(f"{args[0]} does not appear to be a CR1C ELF")
        
        symtab = elffile.get_section_by_name('.symtab')
        if not symtab or not isinstance(symtab, SymbolTableSection):
            raise ValueError(f"{args[0]} did not have a symbol table")

        symbols = []
        symmap = {}
        for sym in symtab.iter_symbols():
            symbols.append((sym.entry.st_value, sym.name, ))
            symmap[sym.name] = sym.entry.st_value
        symbols.sort(key=lambda x: x[0])
        
        load_start = None
        load_regions = []
        for sym in symbols:
            if sym[1].startswith("LOAD_BEGIN"):
                if load_start is not None:
                    raise ValueError(f"nested LOAD_BEGIN symbol {sym[1]}")
                load_start = sym[0]
            elif sym[1].startswith("LOAD_END"):
                if load_start is None:
                    raise ValueError(f"unpaired LOAD_END symbol {sym[1]}")
                load_regions.append((load_start, sym[0] - 1, ))
                load_start = None
        
        if len(load_regions) == 0:
            raise ValueError(f"no load regions in {args[0]} (did you bracket things with LOAD_BEGIN/LOAD_END?)")
        
        load_data = []
        for sect in elffile.iter_sections():
            if sect['sh_type'] != 'SHT_PROGBITS':
                continue
            start = sect['sh_addr']
            end = start + sect['sh_size']
            data = sect.data()
            # we (naively?) assume that every load region is contained completely within exactly one section
            for wantst,wantend in load_regions:
                if wantst < start:
                    continue
                # wantend can go off the end of the section, and we just don't load those extra bytes?
                # XXX: we can miss a load region and never notice, I guess?
                load_data.append((wantst, data[wantst - start:wantend - start + 1], ))
        load_data.sort(key = lambda x: x[0])
        
        for st,ldata in load_data:
            print(f"ELF load: LOAD: 0x{st:x} ({len(ldata)} bytes)")
        global patch_pending
        patch_pending = load_data
        print(f"ELF load: {len(symmap)} symbols")
        global patch_syms
        patch_syms = symmap
mkaction('--elf', help = 'Select an ELF file to operate on.', nargs = 1, metavar=("PATCH.OO"), func = elf)

def hotpatch(args):
    global patch_pending
    if not patch_pending:
        raise ValueError("no patch pending?")
    nbytes = 0
    for st, ldata in patch_pending:
        nbytes += len(ldata)
    print(f"Writing {nbytes} bytes into EC RAM...")
    for st, ldata in patch_pending:
        for bn,b in enumerate(ldata):
            ec.write8(st+bn, int(b))
    print(f"DONE")
    patch_pending = None
    global did_something
    did_something = True
mkaction('--hotpatch', help = 'Non-atomically hotpatch a loaded ELF file into EC RAM. (BE CAREFUL!)', nargs = 0, func = hotpatch)

def atomicpatch(args):
    global patch_pending
    if not patch_pending:
        raise ValueError("no patch pending?")
    
    patchbuf = b""
    
    cbuf = b""
    cbufaddr = 0
    def flush():
        nonlocal cbuf, cbufaddr, patchbuf
        
        if len(cbuf) == 0:
            return
        
        patchbuf = patchbuf + bytes([ cbufaddr & 0xFF, (cbufaddr >> 8) & 0xFF, (cbufaddr >> 16) & 0xFF, (cbufaddr >> 24) & 0xFF, len(cbuf) ]) + cbuf
        cbuf = b""
        cbufaddr = 0
        
    for st, ldata in patch_pending:
        for bn,b in enumerate(ldata):
            addr = st+bn
            if addr != cbufaddr + len(cbuf) or len(cbuf) > 240:
                flush()
                cbufaddr = addr
            cbuf = cbuf + bytes([int(b)])
    flush()
    patchbuf = patchbuf + b"\x00\x00\x00\x00\x00"
    
    print(f"Submitting {len(patchbuf)} byte patch to EC...")
    ec.atomicpatch(patchbuf)
    print(f"DONE")
    
    print(f"Verifying...")
    for st,ldata in patch_pending:
        for bn,b in enumerate(ldata):
            addr = st+bn
            rb = ec.read8(addr)
            if rb != b:
                raise RuntimeError(f"readback failure from 0x{addr:x} (expected 0x{b:02x}, got 0x{rb:02x}); is the patchloader alive?")
    print(f"DONE")
    patch_pending = None
    global did_something
    did_something = True
mkaction('--atomicpatch', help = 'Atomically hotpatch a loaded ELF file into EC RAM. (BE CAREFUL!)', nargs = 0, func = atomicpatch)

def elfcall(args):
    global patch_syms
    if not patch_syms:
        raise ValueError("no ELF loaded?")
    if args[0] not in patch_syms:
        raise ValueError(f"{args[0]} symbol not in loaded ELF")
    addr = patch_syms[args[0]]
    print(f"Calling into {args[0]} (0x{addr:x}) on EC...")
    ec.call(addr)
    print(f"DONE")
mkaction('--call', help = 'Call symbol from ELF file already loaded into EC RAM. (BE CAREFUL!)', nargs = 1, metavar = 'SYMBOL', func = elfcall)

def read_symbol(args):
    global patch_syms
    if not patch_syms:
        raise ValueError("no ELF loaded?")
    if args[0] not in patch_syms:
        raise ValueError(f"{args[0]} symbol not in loaded ELF")
    addr = patch_syms[args[0]]
    print(f"{args[0]} (0x{addr:x}): 0x{ec.read8(addr):02x}")
    global did_something
    did_something = True
mkaction("--read-symbol", help = 'Read a byte from a symbol.', nargs = 1, metavar = 'SYMBOL', func = read_symbol)

# Commands that go with usbc-bitbang-utils.
def i2c_probe(args):
    global patch_syms
    if not patch_syms:
        raise ValueError("no ELF loaded?")
    probeaddr = int(args[0], 16)
    ec.write8(patch_syms['i2c_addr_dev'], probeaddr)
    ec.call(patch_syms['i2c_probe'])
    rv = ec.read8(patch_syms['i2c_rv'])
    print(f"I2C address 0x{probeaddr:02x}: {'OK' if rv == 0 else 'NG'}")
    global did_something
    did_something = True
mkaction("--i2c-probe", help = 'Probe one I2C address.', nargs = 1, metavar = 'I2C_ADDRESS', func = i2c_probe)

def i2c_scan(args):
    global patch_syms
    if not patch_syms:
        raise ValueError("no ELF loaded?")
    for addr in range(0,0x100):
        ec.write8(patch_syms['i2c_addr_dev'], addr)
        ec.call(patch_syms['i2c_probe'])
        rv = ec.read8(patch_syms['i2c_rv'])
        if rv == 0:
            print(f"found device at I2C address 0x{addr:02x}")
    global did_something
    did_something = True
mkaction("--i2c-scan", help = 'Scan all I2C addresses.', nargs = 0, func = i2c_scan)

def i2c_read(args):
    global patch_syms
    if not patch_syms:
        raise ValueError("no ELF loaded?")
    devaddr = int(args[0], 16)
    regaddr = int(args[1], 16)
    nbytes = int(args[2])
    if nbytes > 0x10:
        nbytes = 0x10
    if nbytes < 1:
        nbytes = 1

    ec.write8(patch_syms['i2c_addr_dev'], devaddr)
    ec.write8(patch_syms['i2c_addr_reg'], regaddr)
    ec.write8(patch_syms['i2c_count'], nbytes)
    
    ec.call(patch_syms['i2c_read'])
    global did_something
    did_something = True

    rv = ec.read8(patch_syms['i2c_rv'])
    if rv != 0:
        print(f"failed to read from I2C device 0x{devaddr:02x} (error 0x{rv:02x})")
        return
    rbytes = ec.read(patch_syms['i2c_buf'], nbytes)
    bytesstr = ' '.join([f"{b:02x}" for b in list(rbytes)])
    print(f"{devaddr:02X}/{regaddr:02X}[0..{nbytes-1}]: {bytesstr}")
mkaction("--i2c-read", help = 'Read some bytes from an I2C address.', nargs = 3, metavar = ('DEVADDR', 'REGADDR', 'NBYTES'), func = i2c_read)

args = parser.parse_args()

if not did_something:
    parser.print_help()
