# Troubleshooting

## OLED service fails with `OSError: cannot open resource`

The system-information display uses DejaVu Sans Mono. On a minimal Trixie install,
the font may not be present unless it is installed explicitly.

```bash
apt update
apt install -y fonts-dejavu-core
systemctl restart minitower_oled.service
```

Verify the expected font path:

```bash
ls -l /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf
```

The bundled `sysinfo.py` also falls back to Pillow's default font instead of
crash-looping if the file disappears later.

## `pip` reports an externally-managed environment / PEP 668

Modern Debian and Raspberry Pi OS protect the system Python environment. This
installer deliberately uses `python3 -m pip ... --break-system-packages` for the
hardware libraries that are installed from PyPI.

## OLED hardware test

Check the I2C bus. The MiniTower OLED normally appears at `0x3c`:

```bash
i2cdetect -y 1
```

Run a Luma example:

```bash
python3 /opt/luma.examples/examples/clock.py
```

Run the production display directly:

```bash
python3 /usr/local/minitower/sysinfo.py
```

## RGB stays on

Run the off script directly:

```bash
python3 /usr/local/minitower/turnoff_leds.py
```

Then check the ordering service:

```bash
systemctl status minitower_disable_led.service --no-pager -l
journalctl -b -u minitower_disable_led.service --no-pager
```

Expected state after boot:

- `minitower_moodlight.service`: `active (running)`
- `minitower_oled.service`: `active (running)`
- `minitower_disable_led.service`: `active (exited)`
- fan: spinning
- OLED: on
- RGB: off

## Capture a known-good machine

Before rebuilding a working Pi, capture its exact packages and service state:

```bash
./tools/collect-working-state.sh
```

Upload the generated `/root/minitower-working-state-*.txt` when comparing or
updating the installer.
