#!/bin/sh
# Default acpi script that takes an entry for all actions

# NOTE: This is a 2.6-centric script.  If you use 2.4.x, you'll have to
#       modify it to not use /sys

minspeed=`cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq`
maxspeed=`cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq`
setspeed="/sys/devices/system/cpu/cpu0/cpufreq/scaling_setspeed"

brightness="/sys/class/backlight/acpi_video0/brightness"

# Detect owner of GUI
xs=$(ps -C xinit -o user= || ps -C sway -o user= || ps -C xfce4-session -o user=)
set $*

PID=$(pgrep dbus-launch)
export USER=$(ps -o user --no-headers $PID)
USERHOME=$(eval echo "~$USER")
export XAUTHORITY="$USERHOME/.Xauthority"
for x in /tmp/.X11-unix/*; do
    displaynum=`echo $x | sed s#/tmp/.X11-unix/X##`
    if [ x"$XAUTHORITY" != x"" ]; then
        export DISPLAY=":$displaynum"
    fi
done

case "$1" in
    video/brightnessdown)
        case "$2" in
            BRTDN)
                level=$(cat $brightness)
                if [ "$level" -gt "0" ]; then
                    echo -n $(($level-1)) > $brightness
                fi
            ;;
        esac
    ;;
    video/brightnessup)
        case "$2" in
            BRTUP)
                level=$(cat $brightness)
                if [ "$level" -lt "15" ]; then
                    echo -n $(($level+1)) > $brightness
                fi
            ;;
        esac
        ;;
    jack/headphone)
        ;;
    button/mute)
        ;;
    button/f20)
        ;;
    button/volumeup)
        ;;
    button/volumedown)
        ;;
    ac_adapter)
        ;;
    battery)
        ;;
    button/power)
        ;;
    button/sleep)
        ;;
    button/screenlock)
        ;;
    button/lid)
        ;;
    *)  
        # tail -F /var/log/syslog | grep ACPI
        logger "ACPI group/action undefined: $1 / $2"
        if test $xs; then export DISPLAY=:0 && su $xs -c "notify-send \"ACPI group/action undefined: $1 / $2\"" ; fi
        ;;
esac

# vim:set ts=4 sw=4 ft=sh et:
