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

## Target behavior

After a normal cold boot:

- the case/CPU fan remains powered and spinning;
- the 128x64 front OLED displays system information;
- the MiniTower moodlight hardware is initialized;
- the four WS281x/NeoPixel RGB LEDs are turned **off** after initialization;
- the OLED remains on after the RGB-off action;
- all three services are managed by systemd.

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
- Explicitly installs `fonts-dejavu-core`, preventing the common OLED
  `OSError: cannot open resource` failure.
- Installs `luma.examples` to `/opt/luma.examples` so `clock.py` and the other
  hardware demos are always available.
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

git clone https://github.com/YOUR-GITHUB-USER/rpi-abs-minitower-setup.git
cd rpi-abs-minitower-setup
./install.sh
```

The installer reboots by default. To inspect everything before rebooting:

```bash
./install.sh --no-reboot
```

Then reboot manually:

```bash
systemctl reboot
```

## Verify after reboot

Physically confirm:

- **fan:** spinning
- **OLED:** on and updating
- **RGB:** off roughly 10 seconds after MiniTower service initialization

Then run:

```bash
systemctl status \
  minitower_moodlight.service \
  minitower_oled.service \
  minitower_disable_led.service \
  --no-pager -l

systemctl --failed
```

Expected systemd states:

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

Test a stock Luma demo:

```bash
python3 /opt/luma.examples/examples/clock.py
```

Test the production display directly:

```bash
python3 /usr/local/minitower/sysinfo.py
```

## Services

### `minitower_moodlight.service`

Starts the `rpi_ws281x` hardware/test process used by the original MiniTower
setup. It remains running.

### `minitower_oled.service`

Runs:

```text
/usr/bin/python3 /usr/local/minitower/sysinfo.py
```

The production OLED code talks directly to the SSD1305 via `luma.oled`; it does
not depend on the `luma.examples` source tree. The examples are installed only
for testing/demo use.

### `minitower_disable_led.service`

Runs **after** moodlight and OLED services, waits 10 seconds, then executes:

```text
/usr/bin/python3 /usr/local/minitower/turnoff_leds.py
```

This leaves the fan running and OLED active while setting all four RGB pixels
to `(0, 0, 0)`.

## Rebuilding from a known-good Pi

A state-capture helper is included. On a working machine run:

```bash
./tools/collect-working-state.sh
```

It records package versions, Python modules, I2C status, service definitions,
service logs, and the current installed scripts. Use that report to pin or
adjust future releases without guessing.

## Uninstall

```bash
sudo ./uninstall.sh
```

The uninstaller removes the MiniTower services and local MiniTower files, but
intentionally leaves I2C enabled and leaves common Python/APT dependencies and
cloned third-party source trees in place.

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Upstream / license

The original GeeekPi/52Pi ABS Mini Tower repository is MIT licensed. This
project retains the original MIT copyright notice where applicable and records
its upstream references in [docs/UPSTREAM.md](docs/UPSTREAM.md).
