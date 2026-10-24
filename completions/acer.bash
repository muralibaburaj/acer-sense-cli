# bash completion for acer
_acer() {
	local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD - 1]}
	local cmds="status quiet balanced performance low-power eco profile limit unlimited
		calibrate fan usb-charging backlight-timeout lcd-override boot-sound rgb
		save restore raw help --version"
	if ((COMP_CWORD == 1)); then
		mapfile -t COMPREPLY < <(compgen -W "$cmds" -- "$cur")
		return
	fi
	case $prev in
	profile)
		mapfile -t COMPREPLY < <(compgen -W "$(cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null)" -- "$cur") ;;
	fan | fans) mapfile -t COMPREPLY < <(compgen -W "auto max 25 50 75 100" -- "$cur") ;;
	usb-charging) mapfile -t COMPREPLY < <(compgen -W "off 10 20 30" -- "$cur") ;;
	backlight-timeout | lcd-override | boot-sound) mapfile -t COMPREPLY < <(compgen -W "on off" -- "$cur") ;;
	calibrate) mapfile -t COMPREPLY < <(compgen -W "start stop" -- "$cur") ;;
	raw)
		local d f names=""
		for d in /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/{nitro,predator}_sense; do
			[[ -d $d ]] || continue
			for f in "$d"/*; do names+=" ${f##*/}"; done
		done
		mapfile -t COMPREPLY < <(compgen -W "$names" -- "$cur")
		;;
	esac
}
complete -F _acer acer
