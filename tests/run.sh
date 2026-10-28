#!/usr/bin/env bash
# Runs acer against a fake /sys tree. No root, no hardware needed.
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
acer="$here/../acer"
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
export ACER_SYSFS_ROOT=$root ACER_STATE_DIR=$root/state

fails=0
check() {
	local desc=$1 want=$2 got=$3
	if [[ $got == "$want" ]]; then
		printf 'ok   %s\n' "$desc"
	else
		printf 'FAIL %s\n     want: %q\n     got:  %q\n' "$desc" "$want" "$got"
		fails=$((fails + 1))
	fi
}
fails_with() {
	local desc=$1 code
	shift
	code=0
	"$acer" "$@" >/dev/null 2>&1 || code=$?
	check "$desc" nonzero "$([[ $code != 0 ]] && echo nonzero || echo zero)"
}
val() { cat "$root/sys/$1"; }

mkfake() {
	rm -rf "$root/sys" "$root/state"
	local s=$root/sys/module/${3:-linuwu_sense}/drivers/platform:acer-wmi/acer-wmi/${1:-nitro_sense}
	mkdir -p "$s" "$root/sys/firmware/acpi" "$root/sys/class/dmi/id"
	echo "${2:-low-power quiet balanced balanced-performance}" >"$root/sys/firmware/acpi/platform_profile_choices"
	echo balanced >"$root/sys/firmware/acpi/platform_profile"
	echo "Nitro TEST" >"$root/sys/class/dmi/id/product_name"
	for f in battery_limiter battery_calibration backlight_timeout usb_charging; do echo 0 >"$s/$f"; done
	echo 0,0 >"$s/fan_speed"
	echo 25.701 >"$s/version"
}
P=firmware/acpi/platform_profile
N=module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/nitro_sense

mkfake
"$acer" quiet >/dev/null
check "quiet sets the profile" quiet "$(val $P)"
"$acer" performance >/dev/null
check "performance falls back to balanced-performance" balanced-performance "$(val $P)"
"$acer" eco >/dev/null
check "eco means low-power" low-power "$(val $P)"
fails_with "unsupported profile is refused" profile turbo

mkfake "" "low-power balanced performance"
"$acer" performance >/dev/null
check "performance used when offered" performance "$(val $P)"

# Firmware that lists "performance" but rejects the write (needs a non-root
# user, so the write goes through the fake sudo below).
if ((EUID != 0)); then
	mkfake "" "low-power balanced balanced-performance performance"
	mkdir "$root/bin"
	# Fake sudo: rejects "performance", otherwise writes as the owner would be allowed to.
	printf '#!/bin/sh\nread -r v\n[ "$v" = performance ] && exit 1\nchmod u+w "$2"\nprintf "%%s\\n" "$v" | "$@"\n' >"$root/bin/sudo"
	chmod +x "$root/bin/sudo"
	chmod a-w "$root/sys/$P"
	PATH=$root/bin:$PATH "$acer" performance >/dev/null 2>&1
	check "rejected performance falls back to balanced-performance" balanced-performance "$(val $P)"
fi

# DKMS packages that patch acer_wmi in place instead of adding linuwu_sense.
mkfake nitro_sense "" acer_wmi
"$acer" limit >/dev/null
check "limit via patched acer_wmi" 1 "$(val module/acer_wmi/drivers/platform:acer-wmi/acer-wmi/nitro_sense/battery_limiter)"

mkfake
"$acer" limit >/dev/null
check "limit" 1 "$(val $N/battery_limiter)"
"$acer" unlimited >/dev/null
check "unlimited" 0 "$(val $N/battery_limiter)"

"$acer" fan 60 >/dev/null
check "fan PCT sets both" 60,60 "$(val $N/fan_speed)"
"$acer" fan 50,70 >/dev/null
check "fan CPU,GPU" 50,70 "$(val $N/fan_speed)"
"$acer" fan 40 max >/dev/null
check "fan CPU GPU with max" 40,100 "$(val $N/fan_speed)"
"$acer" fan auto >/dev/null
check "fan auto" 0,0 "$(val $N/fan_speed)"
check "fan read" "auto" "$("$acer" fan)"
fails_with "fan 101 refused" fan 101
fails_with "fan junk refused" fan fast

"$acer" usb-charging 20 >/dev/null
check "usb-charging 20" 20 "$(val $N/usb_charging)"
"$acer" usb-charging off >/dev/null
check "usb-charging off" 0 "$(val $N/usb_charging)"
fails_with "usb-charging 15 refused" usb-charging 15

"$acer" backlight-timeout on >/dev/null
check "backlight-timeout on" 1 "$(val $N/backlight_timeout)"
check "backlight-timeout read" on "$("$acer" backlight-timeout)"
fails_with "lcd-override missing on Nitro" lcd-override on

"$acer" calibrate start >/dev/null
check "calibrate start" 1 "$(val $N/battery_calibration)"
"$acer" calibrate stop >/dev/null

# save / restore round-trip, and validation of a tampered state file.
"$acer" quiet >/dev/null
"$acer" fan 30,40 >/dev/null
"$acer" limit >/dev/null
"$acer" save >/dev/null
"$acer" balanced >/dev/null
"$acer" fan auto >/dev/null
"$acer" unlimited >/dev/null
"$acer" restore >/dev/null
check "restore profile" quiet "$(val $P)"
check "restore fans" 30,40 "$(val $N/fan_speed)"
check "restore limit" 1 "$(val $N/battery_limiter)"
echo 999,5 >"$root/state/fan_speed"
echo turbo >"$root/state/platform_profile"
"$acer" restore >/dev/null
check "restore skips invalid fan value" 30,40 "$(val $N/fan_speed)"
check "restore skips unsupported profile" quiet "$(val $P)"

fails_with "raw rejects path traversal" raw ../../platform_profile
check "raw read" 25.701 "$("$acer" raw version)"

# Predator layout and four-zone keyboard.
mkfake predator_sense
echo 0 >"$root/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/lcd_override"
mkdir -p "$root/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/four_zoned_kb"
K=module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/four_zoned_kb/per_zone_mode
echo 000000,000000,000000,000000,0 >"$root/sys/$K"
"$acer" lcd-override on >/dev/null
check "predator_sense is found" 1 "$(val module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/lcd_override)"
"$acer" rgb '#ff0000' 50 >/dev/null
check "rgb one color" ff0000,ff0000,ff0000,ff0000,50 "$(val $K)"
"$acer" rgb 111111,222222,333333,444444 >/dev/null
check "rgb four zones" 111111,222222,333333,444444,100 "$(val $K)"
fails_with "rgb two zones refused" rgb 111111,222222

# No Linuwu-Sense: fall back to the kernel battery threshold.
rm -rf "$root/sys/module"
mkdir -p "$root/sys/class/power_supply/BAT0"
echo 100 >"$root/sys/class/power_supply/BAT0/charge_control_end_threshold"
"$acer" limit >/dev/null
check "fallback threshold limit" 80 "$(val class/power_supply/BAT0/charge_control_end_threshold)"
"$acer" unlimited >/dev/null
check "fallback threshold unlimited" 100 "$(val class/power_supply/BAT0/charge_control_end_threshold)"
"$acer" status >/dev/null
check "status works without driver" 0 "$?"
fails_with "fan needs the driver" fan 50

echo
if ((fails)); then
	echo "$fails test(s) failed"
	exit 1
fi
echo "all tests passed"
