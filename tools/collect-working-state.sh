#!/usr/bin/env bash
set -u

OUT="${1:-/root/minitower-working-state-$(date +%Y%m%d-%H%M%S).txt}"

run() {
    printf '\n\n===== %s =====\n' "$*" >> "$OUT"
    "$@" >> "$OUT" 2>&1 || true
}

{
    echo "ABS MiniTower working-state capture"
    echo "Generated: $(date -Is)"
} > "$OUT"

run cat /etc/os-release
run uname -a
run sh -c "tr -d '\\0' </proc/device-tree/model 2>/dev/null"
run python3 --version
run python3 -m pip --version
run python3 -m pip list
run dpkg-query -W -f='${binary:Package}\t${Version}\n' \
    fonts-dejavu-core python3 python3-pip python3-pil python3-psutil python3-rpi.gpio \
    libjpeg-dev zlib1g-dev libfreetype6-dev liblcms2-dev libopenjp2-7-dev libtiff-dev
run ls -l /dev/i2c-1
run i2cdetect -y 1
run lsmod
run sh -c "grep -nE 'i2c|spi|gpio|w1' /boot/firmware/config.txt /boot/config.txt 2>/dev/null"
run sh -c "ls -l /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf /usr/bin/moodlight /usr/local/bin/minitower-moodlight 2>/dev/null"
run systemctl cat minitower_moodlight.service
run systemctl cat minitower_oled.service
run systemctl cat minitower_disable_led.service
run systemctl cat minitower_ledfix.service
run systemctl status minitower_moodlight.service minitower_oled.service minitower_disable_led.service --no-pager -l
run systemctl --failed
run journalctl -b -u minitower_moodlight.service -u minitower_oled.service -u minitower_disable_led.service --no-pager -n 200
run sh -c "sed -n '1,240p' /usr/local/minitower/sysinfo.py 2>/dev/null"
run sh -c "sed -n '1,160p' /root/turnoff_leds.py 2>/dev/null"

echo "Saved working-state report to: $OUT"
