#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo -E bash "$0" "$@"
    fi
    echo "Run this uninstaller as root." >&2
    exit 1
fi

for unit in minitower_disable_led.service minitower_oled.service minitower_moodlight.service; do
    systemctl disable --now "$unit" 2>/dev/null || true
    rm -f "/etc/systemd/system/$unit"
done

systemctl daemon-reload
systemctl reset-failed
rm -rf /usr/local/minitower
rm -f /usr/local/bin/minitower-moodlight

cat <<'MSG'
MiniTower services and locally installed MiniTower files were removed.

Deliberately left in place:
  - I2C configuration
  - APT/Python dependencies
  - /opt/luma.examples
  - /usr/local/src/rpi_ws281x

Those may be used by other Raspberry Pi hardware/software.
MSG
