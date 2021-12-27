#!/bin/bash
set -x
dialog --checklist          'Choose the desired patches' 0 0 0 \
    fn-swap                 'Swap Fn and Ctrl keys' off \
    fix-ec-debug            'Allow hot-patching of EC.' on \
    default-lcd-brightness  'Set default LCD backlight brightness behaviour' off \
    lcd-brightness          'Allow lowering LCD backlight brightness to 1%' on \
    lcd-backlight-925hz     'LCD backlight to 925Hz' off \
    true-battery-reading    'Fix battery reading above 70%' on \
    battery-current         'Fix battery current measurement' on \
	backlight-os-only       'EC only changes backlight by ACPI control' on \
    fast-charge             'Fast  charge 6C (3A)   and 9C (4A)   batteries, and limit input power to 80W (65W adapters drop charging regularly)' off \
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
    remove-battery-spam     'Remove battery event spam, includes fix for batery reading above 70% (WORK IN PROGRESS, NOT FULL DONE)' off \
    usb-c                   'USB-C charging check' off \
    2> selected
for p in $(cat selected); do
    fn="patches/$p.rapatch"
    if [ ! -e "$fn" ]; then
        echo "The patch \"$fn\" doesn't exist!"
        exit 1
    fi
    if [[ "$p" =~ .*fan-pwm-table$ ]]; then
        set +x
        echo -e "PWM TABLE:\n  in  out  pwm"; cat patches/$p.rapatch | cut -d" " -f2 | sed "s/\([0-9a-f][0-9a-f]\)/\1 /g" | awk '{ print sprintf("%4d", strtonum("0x" $1)), sprintf("%4d", strtonum("0x" $2)),  sprintf("%4d", strtonum("0x" $3)) }'
        set -x
    fi
    r2 -w -q -P "$fn" ec.bin || true    # see https://github.com/radare/radare2/issues/15002
done
