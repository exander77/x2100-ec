#!/bin/bash
set -x
dialog --checklist          'Choose the desired patches' 0 0 0 \
    fn-swap                 'Swap Fn and Ctrl keys' off \
    fix-ec-debug            'Allow hot-patching of EC.' on \
    default-lcd-brightness  'Set default LCD backlight brightness behaviour' off \
    lcd-brightness          'Allow lowering LCD backlight brightness to 1% (1%,2%,4%,8%,16%,32%,44%,48%,55%,60%,65%,70%,78%,84%,94%,99%)' on \
    improved-lcd-brightness 'Allow lowering LCD backlight brightness to 1% (1%,2%,4%,8%,14%,21%,30%,44%,48%,55%,61%,66%,73%,80%,92%,99%)' off \
    lcd-backlight-925hz     'LCD backlight to 925Hz' off \
    true-battery-reading    'Fix battery reading above 70%' on \
    battery-current         'Fix battery current measurement' on \
    backlight-os-only       'EC only changes backlight by ACPI control (see ./acpi for /etc/acpi configuration)' on \
    fast-charge             'Fast charge 6C (3A) and 9C (4A) batteries, and limit input power to 80W (65W adapters drop charging regularly)' off \
    input-current-45w       'Input current 45W' off \
    input-current-65w       'Input current 65W' off \
    input-current-80w       'Input current 80W' off \
    enable-hotkeys          'Generate scancodes for hotkeys' off \
    enable-hotkey-f3        'Generate scancodes for F3 hotkey (interferes with built-in screen off)' off \
    default-fan-pwm-table   'Set default fan pwm table' off \
    silent-fan-pwm-table    'Set silent fan pwm table' off \
    silent2-fan-pwm-table   'Set silent 2 fan pwm table' off \
    silent3-fan-pwm-table   'Set silent 3 fan pwm table' off \
    direct-fan-pwm-values   'Set direct fan values 5 and 15' off \
    fix-other-keys          'Fix some Blender issues with Enter, 7 and enable ThinkVantage button' off \
    remove-temperature-changed  'Remove temperature changed event' off \
    remove-battery-spam     'Remove battery ACPI event spam' off \
    usb-c                   'USB-C charging check' off \
    vlad00                  'Unknown vladisslav2021 patch port' off \
    2> selected
for p in $(cat selected); do
    fn="patches/$p.rapatch"
    if [ ! -e "$fn" ]; then
        echo "The patch \"$fn\" doesn't exist!"
        exit 1
    fi
    if [[ "$p" =~ .*fan-pwm-table$ ]]; then
        set +x
        echo -e "PWM FAN TABLE:\n  in  out  pwm"; cat patches/$p.rapatch | cut -d" " -f2 | sed "s/\([0-9a-f][0-9a-f]\)/\1 /g" | awk '{ print sprintf("%4d", strtonum("0x" $1)), sprintf("%4d", strtonum("0x" $2)),  sprintf("%4d", strtonum("0x" $3)) }'
        set -x
    fi
    if [[ "$p" =~ .*lcd-brightness$ ]]; then
        set +x
        echo -e "PWM BRIGHTNESS TABLE:\n  acc   bat"; cat patches/$p.rapatch | cut -d" " -f2 | sed "s/.\{4\}/&\n/g" | head -n -1 | sed "s/\([0-9a-f][0-9a-f]\)/\1 /g" | awk '{ print sprintf("%4d%", strtonum("0x" $1)), sprintf("%4d%", strtonum("0x" $2)) }'
        set -x
    fi
    r2 -w -q -P "$fn" ec.bin || true    # see https://github.com/radare/radare2/issues/15002
done
