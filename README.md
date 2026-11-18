# Raspberry Pi ABS Mini Tower Setup — Debian Trixie

A standalone, repeatable setup for the GeeekPi/52Pi-style **ABS Mini Tower / Mini
Tower NAS kit** on 64-bit Raspberry Pi systems, focused on modern Debian /
Raspberry Pi OS **Trixie**.

This project exists so a fresh SD-card install does not require stitching
together old README fragments, issue comments, Bookworm-era installer fixes,
and manual systemd edits every time.

> **Unofficial community project.** This repository is not affiliated with
> GeeekPi/52Pi. See [docs/UPSTREAM.md](docs/UPSTREAM.md) and
> [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Operating modes

The installer asks which behavior you want. The default/recommended mode matches
the configuration validated on a working Raspberry Pi 4 MiniTower:

1. **RGB off (`rgb-off`)** — fan remains powered, OLED shows system information,
   MiniTower RGB hardware initializes, then the four WS281x/NeoPixel LEDs are
   turned off after about 10 seconds.
2. **Moodlight (`moodlight`)** — fan remains powered, OLED shows system
   information, and the MiniTower RGB moodlight service remains running.
3. **OLED only (`oled-only`)** — OLED system information is enabled and both RGB
   services are disabled. Fan power is left to the MiniTower case hardware.
4. **Solid color (`solid-color`)** — OLED and fan stay on, and all four RGB LEDs
   use a fixed color. Defaults to **solid blue at 30% brightness**, matching the
   tested PiTower setup. Choose a named color or 6-digit RGB hex value.

The installer manages these choices through systemd and can be rerun later to
change modes.

The Pi 4 NAS kit commonly sold as Amazon ASIN **B0B6V66PRB** uses the ABS Mini
Tower format with the ICE Tower cooler, PWM/RGB fan, OLED board, and M.2 SATA
SSD expansion hardware. Similar GeeekPi Mini Tower products continue to be sold,
but only hardware matching the interfaces described here should be assumed
compatible without testing.

Hardware listing references:

- Pi 4 Mini Tower NAS kit / M.2 SATA variant: https://www.amazon.com/dp/B0B6V66PRB
- Related current Pi 5 Mini Tower family listing: https://www.newegg.com/p/3C6-0688-00Z62

The Pi 5 listing is included only to document that the Mini Tower product family
continues to be sold; this repository's tested configuration is the Pi 4-style
OLED/RGB setup described above.

## What this fixes compared with the older install paths

- Supports running the installer directly as `root`.
- Uses `--break-system-packages` where modern Debian PEP 668 requires it.
- Installs `rpi_ws281x` and `Adafruit-Blinka-Raspberry-Pi-PWM` explicitly
  for modern Raspberry Pi OS / Debian Trixie RGB support, avoiding missing
  platform-dependency prompts during first boot.
- Explicitly installs `fonts-dejavu-core`, preventing the common OLED
  `OSError: cannot open resource` failure.
- Ships a vendored Luma OLED test subset and installs it to `/opt/luma.examples`,
  so `clock.py` remains available even if the upstream examples repo changes.
- Uses `/boot/firmware/config.txt` when present, with `/boot/config.txt` only as
  a compatibility fallback.
- Does **not** rewrite `/etc/resolv.conf` or force public DNS servers.
- Does not assume a user named `pi`.
- Does not put `sudo` inside root-owned systemd services.
- Replaces the hard-coded `wlan0` OLED network display with automatic primary
  interface detection, so Ethernet-only installs still show network/IP data.
- Installs a dedicated RGB-off oneshot service that runs after moodlight and
  OLED initialization, with the 10-second delay validated on a working setup.

## Install

Start from a current 64-bit Raspberry Pi OS / Debian install with network access.
Trixie is the primary target.

```bash
sudo -i
apt update
apt install -y git

git clone https://github.com/bmartino1/rpi-geekpi-minitower-setup.git
cd rpi-geekpi-minitower-setup
./install.sh
```

With no mode option, `./install.sh` shows an interactive menu. For scripted or
repeat installs, select the mode explicitly:

```bash
./install.sh --mode rgb-off
./install.sh --mode moodlight
./install.sh --mode oled-only
./install.sh --mode solid-color
./install.sh --mode solid-color --color red --brightness 0.50
./install.sh --solid-color --color '#0080FF' --brightness 0.30
```

Short aliases are also available: `--rgb-off`, `--moodlight`, `--oled-only`,
and `--solid-color`. Named colors are blue, red, green, white, purple,
cyan, yellow, and orange. Brightness ranges from 0.0 to 1.0.
If the installer is run non-interactively without a mode, it defaults to
`rgb-off`.

The installer reboots by default. To inspect everything before rebooting:

```bash
./install.sh --no-reboot
```

Then reboot manually:

```bash
systemctl reboot
```

## Verify after reboot

For the recommended `rgb-off` mode, physically confirm:

- **fan:** spinning
- **OLED:** on and updating
- **RGB:** off roughly 10 seconds after MiniTower service initialization

For `moodlight`, the RGB service should remain active. For `oled-only`, the RGB
services should remain disabled. For `solid-color`, all four LEDs should hold
the selected color; `minitower_solid_color.service` should show
`active (exited)`, which is expected for a oneshot service.

Then run:

```bash
systemctl status \
  minitower_moodlight.service \
  minitower_oled.service \
  minitower_disable_led.service \
  minitower_solid_color.service \
  --no-pager -l

systemctl --failed
```

Expected systemd states for the recommended `rgb-off` mode:

```text
minitower_moodlight.service      active (running)
minitower_oled.service           active (running)
minitower_disable_led.service    active (exited)
```

and ideally:

```text
0 loaded units listed.
```

## OLED tests

Confirm the display appears at the expected I2C address:

```bash
i2cdetect -y 1
```

Normally the OLED is at `0x3c`.

Test the vendored Luma clock demo:

```bash
python3 /opt/luma.examples/examples/clock.py -d ssd1305 -i i2c --width 128 --height 64
```

Test the production display directly:

```bash
python3 /usr/local/minitower/sysinfo.py
```

## Services

### `minitower_moodlight.service`

Starts the vendored ARM64 GeeekPi moodlight/test binary used by the original
MiniTower setup. It remains running in RGB modes.

### `minitower_solid_color.service`

Runs `/usr/local/minitower/solid_color.py` once at boot to set all four
NeoPixel LEDs on GPIO18. Reads `/etc/default/minitower-color` for
`MINITOWER_COLOR` and `MINITOWER_BRIGHTNESS`. No rainbow/moodlight
process is left running. Settings are created by the installer when you choose
`solid-color`. To change them later, edit that file and restart the service.

### `minitower_oled.service`

Runs:

```text
/usr/bin/python3 /usr/local/minitower/sysinfo.py
```

The production OLED code talks directly to the SSD1305 via `luma.oled`; it does
not depend on the Luma example files. A small vendored Luma test subset is
installed only for hardware validation.

### `minitower_disable_led.service`

Runs **after** moodlight and OLED services, waits 10 seconds, then executes:

```text
/usr/bin/python3 /usr/local/minitower/turnoff_leds.py
```

This leaves the fan running and OLED active while setting all four RGB pixels
to `(0, 0, 0)`.


## Self-contained case assets

The case-specific recovery files are kept in this repository under `vendor/`:

- a minimal Luma `clock.py` / `demo_opts.py` test subset;
- the official GeeekPi ARM64 moodlight binary and license;
- reference snapshots of the official GeeekPi and gentleone MiniTower repos.

This means the installer no longer needs to clone those repositories while a
Pi is being rebuilt. Runtime Python libraries are still installed from Debian /
Python packaging so security and compatibility fixes can be received normally.
See [docs/VENDORED.md](docs/VENDORED.md).

## Rebuilding from a known-good Pi

Two capture helpers are included. On a working machine run:

```bash
./tools/collect-working-state.sh
./tools/capture-working-assets.sh
```

The first records package versions, Python modules, I2C status, service
definitions, logs, and installed scripts. The second also copies the actually
running moodlight binary and MiniTower files into a tarball so a known-good
installation can be compared with or imported into a future release.

## Uninstall

```bash
sudo ./uninstall.sh
```

The uninstaller removes the MiniTower services (including solid-color), `/usr/local/minitower`, the
vendored moodlight install, and `/opt/luma.examples`. It intentionally leaves
I2C enabled and leaves common Python/APT dependencies in place.

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Upstream / license

The original GeeekPi/52Pi ABS Mini Tower repository is MIT licensed. This
project retains the original MIT copyright notice where applicable and records
its upstream references in [docs/UPSTREAM.md](docs/UPSTREAM.md).
