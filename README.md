# acer: control Acer Nitro / Predator laptops from the terminal

A single bash script for the things NitroSense / PredatorSense does on
Windows: thermal profile, fan speed, the 80% battery charge limit, USB
charging while off, keyboard backlight and four-zone RGB. It also saves and
restores them, because the firmware forgets some of them on every boot.

```console
$ acer
Model                Nitro ANV15-51
Profile              balanced (low-power quiet balanced balanced-performance)
Charge limit         on (80%)
Calibration          off
Fan speed            auto
Fans                 CPU 2087 rpm, GPU 1921 rpm
Temperatures         45 / 42 / 43 °C
USB charging         on until battery is at 30%
Backlight timeout    on (30 s)
Driver               linuwu_sense 25.701 (nitro_sense)

$ acer performance
Profile: balanced-performance
$ acer fan 50,70
Fan speed: CPU 50%, GPU 70%
$ acer limit
80% charge limit enabled.
```

## Requirements

- The [Linuwu-Sense](https://github.com/PXDiv/Div-Linuwu-Sense) kernel driver
  (`linuwu_sense`), with the stock `acer_wmi` module blacklisted, as its README
  describes. Without it, only `acer profile` and (on kernels that expose
  `charge_control_end_threshold`) `acer limit` work.
  Packages that patch `acer_wmi` in place instead of adding `linuwu_sense`
  (such as `acer-wmi-linuwu-dkms-git` on the AUR) work too; no blacklist is
  needed for those.
- bash 4+, coreutils, and sudo or doas for writes when not run as root.

Tested on a Nitro V 15 (ANV15-51). Predator models use the `predator_sense`
directory, which is detected automatically; commands for features your model
lacks fail with a clear error instead of writing anything.

## Install

```sh
git clone https://github.com/muralibaburaj/acer-sense-cli
cd acer-sense-cli
sudo make install               # /usr/local/bin/acer + bash completion
```

Nix / NixOS:

```sh
nix run github:muralibaburaj/acer-sense-cli
nix profile install github:muralibaburaj/acer-sense-cli
```

## Commands

| Command | Does |
|---|---|
| `acer` / `acer status` | show everything |
| `acer quiet` · `balanced` · `performance` · `low-power` / `eco` | thermal profile (`performance` maps to `balanced-performance` on models without a full performance profile, or whose firmware rejects it) |
| `acer profile [NAME]` | show or set any profile in `platform_profile_choices` |
| `acer limit` / `acer unlimited` | 80% charge limit on / off |
| `acer calibrate start\|stop` | battery calibration (keep AC connected) |
| `acer fan [auto\|max\|PCT\|CPU,GPU]` | fan speed, 1–100%, 0 or `auto` for firmware control |
| `acer usb-charging [off\|10\|20\|30]` | power USB while off, until the battery reaches that % |
| `acer backlight-timeout [on\|off]` | keyboard light off after 30 s idle |
| `acer lcd-override [on\|off]` | lower panel latency (Predator) |
| `acer boot-sound [on\|off]` | boot animation and sound (Predator) |
| `acer rgb COLOR[,C2,C3,C4] [BRIGHTNESS]` | four-zone keyboard colour, `RRGGBB` hex |
| `acer raw SETTING [VALUE]` | read or write any other driver setting |
| `acer save` / `acer restore` | remember / re-apply profile, fans, charge limit, USB charging, backlight |

Values are validated before anything is written to the firmware.

## Keep settings across reboots

`acer save` writes the current settings to `/var/lib/acer-sense`
(`ACER_STATE_DIR` to change it); `acer restore` re-applies them, skipping any
value the hardware doesn't accept. Run them at shutdown and boot:

- **systemd:** `sudo make install-systemd && sudo systemctl enable --now acer-sense`
- **OpenRC:** `sudo make install-openrc && sudo rc-update add acer-sense default`
- **anything else** (runit, s6, dinit, SysV): call `acer restore` from your
  boot scripts (e.g. `/etc/rc.local`) and `acer save` from shutdown.

## Development

`make test` runs shellcheck and the test suite in `tests/`, which drives the
script against a fake `/sys` tree (`ACER_SYSFS_ROOT`), so it needs neither
root nor Acer hardware.

## License

MIT. The kernel driver is a separate project under GPL-2.0.
