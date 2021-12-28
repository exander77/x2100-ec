Provide a `ec.bin` firmware and hit `make`.

To get an ec.bin:

```
sudo flashrom -p internal -r x2100-current-internal-flashrom.bin
dd if=x2100-current-internal-flashrom.bin of=ec.bin bs=1 skip=$((0x400000)) count=$((0x10000))
```

Then, to modify and flash:
```
dd if=x2100-current-internal-flashrom.bin of=fw.bin bs=1024 count=4096
dd if=ec.bin of=fw.bin bs=1024 count=64 seek=4096
dd if=x2100-current-internal-flashrom.bin of=fw.bin bs=1024 seek=4160 skip=4160
sudo flashrom -p internal -w fw.bin
```

Note that you need a flashrom that has this patch: https://review.coreboot.org/c/flashrom/+/44921
