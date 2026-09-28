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
rm -rf /opt/luma.examples

cat <<'MSG'
MiniTower services and files installed by this repository were removed.

Deliberately left in place:
  - I2C configuration
  - APT/Python dependencies

Those may be used by other Raspberry Pi hardware/software.
MSG
