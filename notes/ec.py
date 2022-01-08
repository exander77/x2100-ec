class EC:
    def __init__(self):
        self.mem = open("/sys/kernel/debug/ec/ec0/ram", "r+b", 0)
        self.xop = open("/sys/kernel/debug/ec/ec0/xop", "wb", 0)

    def read(self, addr, nbytes = 1):
        self.mem.seek(addr)
        return self.mem.read(nbytes)

    def write(self, addr, data):
        self.mem.seek(addr)
        self.mem.write(data)

    def read8(self, addr):
        return self.read(addr, nbytes = 1)[0] | 0

    def read16(self, addr):
        d = self.read(addr, nbytes = 2)
        return d[0] | (d[1] << 8)

    def read32(self, addr):
        d = self.read(addr, nbytes = 4)
        return d[0] | (d[1] << 8) | (d[2] << 16) | (d[3] << 24)
    
    def write8(self, addr, data):
        self.write(addr, bytes([data]))

    def do_xop(self, xop):
        self.xop.seek(0)
        self.xop.write(bytes([xop]))
    
    def _verify_patchloader(self):
        for bn,b in enumerate(self.ATOMIC_PATCH_CHECK[1]):
            rd = self.read8(self.ATOMIC_PATCH_CHECK[0] + bn)
            if rd != b:
                raise RuntimeError(f"atomic patchloader verification failed at address 0x{self.ATOMIC_PATCH_CHECK[0] + bn:x} (read back 0x{rd:02x}, expected 0x{b:02x}) ... is the patchloader loaded?")
    
    def atomicpatch(self, data):
        self._verify_patchloader()
        self.write(self.ATOMIC_PATCH_BASE, data)
        self.do_xop(1)

    def call(self, addr):
        self._verify_patchloader()
        addr = addr >> 1
        self.write(self.JUMP_TARGET_PTR, bytes([addr & 0xFF, (addr >> 8) & 0xFF, (addr >> 16) & 0xFF, (addr >> 24) & 0xFF]))
        self.do_xop(0)

class Reg:
    def __init__(self, name, adr, fields = []):
        self.name = name
        self.adr = adr
        self.ordfields = fields
        self.fields = { f.name: f for f in self.ordfields }
    
    def module(self, name, base):
        return Reg(name + "_" + self.name, self.adr + base, self.ordfields)
    
    def print(self, val, fields = True):
        print(f"0x{self.adr:06x} ({self.name:12s}): 0x{val:02x}")
        if fields:
            for field in self.ordfields:
                field.print(self.name, val)

class Field:
    def __init__(self, name, lo, size):
        self.name = name
        self.lo = lo
        self.size = size
        self.hi = lo + size - 1
    
    def print(self, regname, regval):
        print(f"          {regname + '.' + self.name:20s} ([{self.hi}:{self.lo}]) = {(regval >> self.hi) & ((1 << self.size) - 1)}")

# sed -e "s/\#define [^_]*_\([^ ]*\) *\(.\), *\(.\)/            Field('\1', \2, \3),/" < npce9mnx_regs.h

class NPCE9MNX(EC):
    ATOMIC_PATCH_BASE = 0x2E000
    JUMP_TARGET_PTR = 0x10C00
    ATOMIC_PATCH_CHECK = (0x20FFA, [0xE0, 0x18, 0x06, 0xC0])

    CHIP_CFG_BASE = 0xFFF000
    CHIP_CFG_REGS = [
        Reg('DEVCNT', CHIP_CFG_BASE + 0x000, [
            Field('CLKOM', 0, 1),
            Field('EXTCLKSL', 1, 1),
            Field('PECI_EN', 2, 1),
            Field('JENK_CSL', 3, 1),
            Field('JENK_HEN', 4, 1),
            Field('ECSCI_CFG', 5, 1),
            Field('SPI_TRIS', 6, 1),
            Field('GTEFL', 7, 1)]),
        Reg('STRPST', CHIP_CFG_BASE + 0x001, [
            Field('SHBM', 0, 1),
            Field('XORTR', 1, 1),
            Field('TRIST', 2, 1),
            Field('SDP_VIS', 3, 1),
            Field('JEN0', 4, 1),
            Field('JENK', 5, 1),
            Field('TEST', 6, 1),
            Field('VD1_EN', 7, 1)]),
        Reg('RSTCTL', CHIP_CFG_BASE + 0x002, [
            Field('EXT_RST_STS', 0, 1),
            Field('DBGRST_STS', 1, 1),
            Field('SFTRST_STS', 4, 1),
            Field('LRESET_MODE', 5, 1),
            Field('HIPRST_MODE', 6, 1),
            Field('DBGRST_MODE', 7, 1)]),
        Reg('DEV_CTL2', CHIP_CFG_BASE + 0x003, [
            Field('CTL2_HPLUG_CONN', 1, 3),
            Field('CTL2_WD2INTPOR', 4, 1),
            Field('CTL2_MMAP_CTL', 5, 2),
            Field('CTL2_ELPC_EN', 7, 1)]),
        Reg('DEV_CTL3', CHIP_CFG_BASE + 0x004, [
            Field('CTL3_WP_GPIO30', 0, 1),
            Field('CTL3_WP_GPIO41', 1, 1),
            Field('CTL3_WP_GPIO81', 2, 1),
            Field('CTL3_WP_IF', 3, 1),
            Field('CTL3_JTD_LOCK', 4, 1),
            Field('CTL3_KBR_CFG', 5, 1),
            Field('CTL3_GA2_CFG', 6, 1)]),
        Reg('SFT_STRP_CFG', CHIP_CFG_BASE + 0x00F, [
            Field('STRP_CFG_PECIST', 0, 1),
            Field('STRP_CFG_PSL_SEL', 2, 1),
            Field('STRP_CFG_INT_FLASH', 3, 1),
            Field('STRP_CFG_BBRMST', 4, 1)]),
        Reg("DEVALT0", CHIP_CFG_BASE + 0x010, [
            Field('CKOUT_SL', 2, 1),
            Field('SPI_SL', 3, 1)]),
        Reg("DEVALT1", CHIP_CFG_BASE + 0x011, [
            Field('URTI_SL', 1, 1),
            Field('URTO1_SL', 2, 1),
            Field('URTO2_SL', 3, 1)]),
        Reg("DEVALT2", CHIP_CFG_BASE + 0x012, [
            Field('LPCPD_SL', 1, 1),
            Field('CLKRN_SL', 2, 1),
            Field('SMI_SL', 3, 1),
            Field('PWUR_SL', 4, 1),
            Field('ECSCI_SL', 5, 1),
            Field('SMB1_SL', 6, 1),
            Field('SMB2_SL', 7, 1)]),
        Reg("DEVALT3", CHIP_CFG_BASE + 0x013, [
            Field('TA1_SL', 0, 1),
            Field('TA2_SL', 1, 1),
            Field('TB1_SL', 2, 1),
            Field('TB2_SL', 3, 1),
            Field('TA3_SL', 4, 1),
            Field('TB3_SL', 5, 1)]),
        Reg("DEVALT4", CHIP_CFG_BASE + 0x014, [
            Field('DAC0_SL', 0, 1),
            Field('DAC1_SL', 1, 1),
            Field('DAC2_SL', 2, 1),
            Field('DAC3_SL', 3, 1),
            Field('PS2_3_SL', 4, 1),
            Field('PS2_1_SL', 5, 1),
            Field('PS2_2_SL', 6, 1)]),
        Reg("DEVALT5", CHIP_CFG_BASE + 0x015),
        Reg("DEVALT6", CHIP_CFG_BASE + 0x016),
        Reg("DEVALT7", CHIP_CFG_BASE + 0x017),
        Reg("DEVALT8", CHIP_CFG_BASE + 0x018, [
            Field('GA20_SL', 1, 1),
            Field('KBRST_SL', 2, 1),
            Field('IOXDO_SL', 4, 1),
            Field('IOXIO2_SL', 5, 1),
            Field('IOXIO1_SL', 6, 1),
            Field('IOXLC_SL', 7, 1)]),
        Reg("DEVALT9", CHIP_CFG_BASE + 0x019, [
            Field('GPA03_SL', 0, 1),
            Field('GPF07_SL', 1, 1),
            Field('GPA45_SL', 2, 1),
            Field('GPA67_SL', 3, 1),
            Field('GPB03_SL', 4, 1),
            Field('GPB47_SL', 5, 1),
            Field('GPC01_SL', 6, 1),
            Field('GPC23_SL', 7, 1)]),
        Reg("DEVALTA", CHIP_CFG_BASE + 0x01A, [
            Field('CIRRL_SL', 3, 1),
            Field('CIRRM2_SL', 4, 1),
            Field('CIRRM1_SL', 5, 1),
            Field('SMB3_SL', 6, 1),
            Field('SMB4_SL', 7, 1)]),
        Reg("DEVALTB", CHIP_CFG_BASE + 0x01B),
        Reg("DEVALTC", CHIP_CFG_BASE + 0x01C, [
            Field('ADC8_SL', 0, 1),
            Field('ADC9_SL', 1, 1),
            Field('ADC10_SL', 2, 1),
            Field('ADC11_SL', 3, 1),
            Field('SMB3B_SL', 5, 1),
            Field('SMB4B_SL', 6, 1)]),
        Reg("DEVALTD", CHIP_CFG_BASE + 0x01D, [
            Field('F_IO23_SL', 0, 1),
            Field('C_IO23_SL', 1, 1),
            Field('PSL_IN1_AHI', 2, 1),
            Field('PSL_IN1_SL', 3, 1),
            Field('PSL_IN2_AHI', 4, 1),
            Field('PSL_IN2_SL', 5, 1)]),
        Reg("DEVALTE", CHIP_CFG_BASE + 0x01E, [
            Field('VDI1_SL', 0, 1),
            Field('VDO1_SL', 1, 1),
            Field('VDI2_SL', 2, 1),
            Field('VDO2_SL', 3, 1),
            Field('1WIRE_SL', 4, 1)]),
        Reg("DEVALTF", CHIP_CFG_BASE + 0x01F),
        Reg('PWM_SEL', CHIP_CFG_BASE + 0x026, [
            Field('GPIO_SEL', 0, 2),
            Field('GPIO42_POL', 4, 1),
            Field('GPIO43_POL', 5, 1),
            Field('WD_RST_EN', 7, 1)]),
        Reg('PWM_SEL2', CHIP_CFG_BASE + 0x027, [
            Field('ADC_TH1_EN', 0, 1),
            Field('ADC_TH2_EN', 1, 1),
            Field('ADC_TH3_EN', 2, 1),
            Field('FPWM_STS', 7, 1)]),
        Reg('DEV_PU0', CHIP_CFG_BASE + 0x028, [
            Field('SMB1_PUE', 0, 1),
            Field('SMB2_PUE', 1, 1),
            Field('SMB3_PUE', 2, 1),
            Field('SMB3A_PUE', 2, 1),
            Field('SMB4_PUE', 3, 1),
            Field('SMB4A_PUE', 3, 1),
            Field('SMB3B_PUE', 5, 1),
            Field('SMB4B_PUE', 6, 1)]),
        Reg('DEV_PD1', CHIP_CFG_BASE + 0x029, [
            Field('F_SDI_PDE', 6, 1),
            Field('C_SDI_PDE', 7, 1)]),
        Reg('LV_GPIO_CTL0', CHIP_CFG_BASE + 0x02A, [
            Field('GPIO20_LV', 0, 1),
            Field('GPIO21_LV', 1, 1),
            Field('GPIO40_LV', 2, 1),
            Field('GPIO54_LV', 3, 1),
            Field('GPIO80_LV', 4, 1),
            Field('GPIOB1_LV', 5, 1),
            Field('GPIOB7_LV', 6, 1),
            Field('GPIO94_LV', 7, 1)]),
        Reg('LV_GPIO_CTL', CHIP_CFG_BASE + 0x02B),
        Reg('LV_GPIO_CTL2', CHIP_CFG_BASE + 0x02C, [
            Field('GPIO01_LV', 0, 1),
            Field('GPIO13_LV', 2, 1),
            Field('GPIO15_LV', 3, 1),
            Field('GPIO45_LV', 4, 1),
            Field('GPIO32_LV', 6, 1),
            Field('GPIO87_LV', 7, 1)]),
        Reg('LV_GPIO_CTL3', CHIP_CFG_BASE + 0x02D, [
            Field('SD1_LV', 0, 1),
            Field('SC1_LV', 1, 1),
            Field('SD2_LV', 2, 1),
            Field('SC2_LV', 3, 1),
            Field('SD3_LV', 4, 1),
            Field('SC3_LV', 5, 1),
            Field('SD4_LV', 6, 1),
            Field('SC4_LV', 7, 1)]),
        Reg('DBG_CTL', CHIP_CFG_BASE + 0x02E, [
            Field('SMBDBG_MODE', 0, 2),
            Field('SMBDBG_SL', 3, 1),
            Field('JTD', 4, 1)])
    ]
    
    ITIM8_REGS = [
        Reg('ITCNT', 0),
        Reg('ITPRE', 1),
        Reg('ITCNT16L', 2),
        Reg('ITCNT16H', 3),
        Reg('ITCTS', 4, [
            Field('TO_STS', 0, 1),
            Field('TO_IE', 2, 1),
            Field('TO_WUE', 3, 1),
            Field('CKSEL', 4, 1), # 0 = 50MHz, 1 = 32 kHz
            Field('ITEN', 7, 1)])]
    ITIM8_COUNT = 3
    ITIM8_BASE = 0xFFF700
    ITIM8_OFS = 0x10
    
    GPIO_REGS = [
        Reg('DOUT', 0),
        Reg('DIN', 1),
        Reg('DIR', 2),
        Reg('PULL', 3),
        Reg('PUD', 4),
        Reg('ENVDD', 5),
        Reg('OTYPE', 6)
    ]
    GPIO_COUNT = 16
    GPIO_BASE = 0xFFF200
    GPIO_OFS = 0x10
    
    SMB_REGS = [
        Reg('SDA', 0),
        Reg('ST', 2),
        Reg('CST', 4),
        Reg('CTL1', 6),
        Reg('ADDR1', 8),
        Reg('CTL2', 10),
        Reg('ADDR2', 12),
        Reg('CTL3', 14),
        Reg('VER', 31)
    ]
    SMB_COUNT = 5
    SMB_BASE = 0xFFF500
    SMB_OFS = 0x40
    
    def __init__(self):
        super().__init__()
        
        self.modulelist = [
            ('CHIP_CFG', self.CHIP_CFG_REGS),
            *[(f"ITIM8_{n}", [reg.module(f"ITIM8_{n}", self.ITIM8_BASE + n * self.ITIM8_OFS) for reg in self.ITIM8_REGS])
              for n in range(self.ITIM8_COUNT)],
            *[(f"GPIO{n:X}", [reg.module(f"GPIO{n:X}", self.GPIO_BASE + n * self.GPIO_OFS) for reg in self.GPIO_REGS])
              for n in range(self.GPIO_COUNT)],
            *[(f"SMB{n:X}", [reg.module(f"SMB{n:X}", self.SMB_BASE + n * self.SMB_OFS) for reg in self.SMB_REGS])
              for n in range(self.SMB_COUNT)],
        ]
        
        self.modules = { m[0]: m[1] for m in self.modulelist }
        self.regs = {r.name: r for r in sum([m[1] for m in self.modulelist], [])}
    
    def dump_module(self, module):
        for reg in self.modules[module]:
            val = self.read8(reg.adr)
            reg.print(val)
