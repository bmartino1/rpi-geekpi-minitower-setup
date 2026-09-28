# Upstream sources and project intent

This is a standalone installer/recovery repository for the ABS Mini Tower case.
It is not intended to be a GitHub fork of either upstream repository.

Sources used as references:

- GeeekPi / 52Pi official repository:
  https://github.com/geeekpi/absminitowerkit
- OLED service issue and Debian/modern-Python troubleshooting history:
  https://github.com/geeekpi/absminitowerkit/issues/15
- Older/community repository with manual Luma setup notes:
  https://github.com/gentleone/absminitowerkit
- Luma examples:
  https://github.com/rm-hull/luma.examples
- rpi_ws281x:
  https://github.com/jgarff/rpi_ws281x

The official `absminitowerkit` source is MIT licensed. Its copyright and MIT
permission notice are retained in this repository's LICENSE and notices.
External projects cloned by the installer remain under their own licenses.

## Why this repository exists

The goal is a repeatable install after replacing/reimaging a Raspberry Pi SD
card, without rediscovering several unrelated fixes each time:

1. modern Debian/Raspberry Pi OS PEP 668 behavior;
2. root-run installation and system services;
3. explicit `fonts-dejavu-core` dependency for the OLED sysinfo display;
4. Luma examples installed in a predictable location for hardware testing;
5. modern `/boot/firmware/config.txt` I2C configuration, with an older fallback;
6. fan/moodlight initialization preserved while RGB is intentionally disabled
   afterward;
7. systemd service ordering proven on a cold boot;
8. no modification of `/etc/resolv.conf`.
