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
    fast-charge             'Fast charge 6C and 9C batteries, and limit input power to 80W' off \
	backlight-os-only       'EC only changes backlight by ACPI control' on \
    fix-fan                 'Patch fan similarly as is done with x210' off \
    enable-hotkeys          'Generate scancodes for hotkeys' off \
    enable-hotkey-f3        'Generate scancodes for F3 hotkey (interferes with built-in screen off)' off \
    default-fan-pwm-table   'Set default fan pwm table' off \
    silent-fan-pwm-table    'Set silent fan pwm table' off \
    silent2-fan-pwm-table   'Set silent 2 fan pwm table' off \
    fix-other-keys          'Fix some Blender issues with Enter, 7 and enable ThinkVantage button' off \
    direct-fan-pwm-values   'Set direct fan values 5 and 15' off \
    remove-temperature-changed  'Remove temperature changed event' off \
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
