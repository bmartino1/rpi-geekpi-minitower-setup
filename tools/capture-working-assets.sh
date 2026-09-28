#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo -E bash "$0" "$@"
    fi
    echo "Run this helper as root." >&2
    exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-/root/minitower-working-assets-$STAMP}"
mkdir -p "$OUT/systemd" "$OUT/minitower" "$OUT/bin"

for src in \
    /etc/systemd/system/minitower_moodlight.service \
    /etc/systemd/system/minitower_oled.service \
    /etc/systemd/system/minitower_disable_led.service; do
    [[ -f "$src" ]] && cp -a "$src" "$OUT/systemd/"
done

for src in /usr/local/minitower/sysinfo.py /usr/local/minitower/turnoff_leds.py; do
    [[ -f "$src" ]] && cp -a "$src" "$OUT/minitower/"
done

for src in /usr/local/bin/minitower-moodlight /usr/bin/moodlight; do
    if [[ -x "$src" ]]; then
        cp -a "$src" "$OUT/bin/$(basename "$src")"
        sha256sum "$src" >> "$OUT/SHA256SUMS"
    fi
done

{
    echo "Captured: $(date -Is)"
    echo "Kernel: $(uname -a)"
    echo "OS:"
    cat /etc/os-release
    echo
    echo "Python: $(python3 --version 2>&1)"
    echo "Pip: $(python3 -m pip --version 2>&1 || true)"
    echo
    python3 -m pip freeze 2>/dev/null || true
} > "$OUT/environment.txt"

tar -C "$(dirname "$OUT")" -czf "$OUT.tar.gz" "$(basename "$OUT")"
printf 'Captured working MiniTower assets to:\n  %s\n  %s.tar.gz\n' "$OUT" "$OUT"
