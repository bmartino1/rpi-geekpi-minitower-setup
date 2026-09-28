#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_NAME="rpi-abs-minitower-setup"
INSTALL_DIR="/usr/local/minitower"
LUMA_DIR="/opt/luma.examples"
WS281X_DIR="/usr/local/src/rpi_ws281x"
MOODLIGHT_BIN="/usr/local/bin/minitower-moodlight"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"; }
warn() { printf '\nWARNING: %s\n' "$*" >&2; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

if [[ ${EUID} -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo -E bash "$0" "$@"
    fi
    die "Run this installer as root."
fi

NO_REBOOT=0
for arg in "$@"; do
    case "$arg" in
        --no-reboot) NO_REBOOT=1 ;;
        -h|--help)
            cat <<USAGE
Usage: ./install.sh [--no-reboot]

Installs the GeeekPi-style ABS Mini Tower OLED/RGB support for modern
64-bit Raspberry Pi OS / Debian, with Trixie as the primary target.

Default result after boot:
  - fan remains powered by the case hardware
  - OLED shows system information
  - RGB LEDs initialize, then are turned off after 10 seconds
USAGE
            exit 0
            ;;
        *) die "Unknown option: $arg" ;;
    esac
done

[[ -r /etc/os-release ]] || die "/etc/os-release not found"
# shellcheck disable=SC1091
source /etc/os-release
CODENAME="${VERSION_CODENAME:-unknown}"
ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
MODEL="$(tr -d '\0' </proc/device-tree/model 2>/dev/null || true)"

log "Installing $PROJECT_NAME"
printf 'OS: %s %s (%s)\n' "${PRETTY_NAME:-unknown}" "$CODENAME" "$ARCH"
printf 'Hardware: %s\n' "${MODEL:-unknown}"

case "$ARCH" in
    arm64|aarch64) ;;
    *) warn "This project is intended for 64-bit Raspberry Pi systems; detected $ARCH." ;;
esac

case "$CODENAME" in
    trixie) log "Detected Debian/Raspberry Pi OS Trixie." ;;
    bookworm) warn "Bookworm detected. It should work, but Trixie is the primary target." ;;
    *) warn "Untested Debian codename: $CODENAME" ;;
esac

if [[ -n "$MODEL" && "$MODEL" != *"Raspberry Pi"* ]]; then
    warn "Hardware does not identify itself as a Raspberry Pi. Continuing because you invoked the installer explicitly."
fi

log "Installing APT dependencies"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates git cmake scons build-essential pkg-config \
    i2c-tools \
    python3 python3-dev python3-pip python3-pil python3-venv \
    python3-psutil python3-rpi.gpio \
    libjpeg-dev zlib1g-dev libfreetype6-dev liblcms2-dev \
    libopenjp2-7-dev libtiff-dev \
    fonts-dejavu-core

log "Installing Python hardware/OLED packages (PEP 668 aware)"
python3 -m pip install --break-system-packages \
    luma.oled \
    adafruit-blinka \
    adafruit-circuitpython-neopixel \
    RPi.GPIO

log "Installing luma.examples for OLED testing/demo programs"
if [[ -d "$LUMA_DIR/.git" ]]; then
    git -C "$LUMA_DIR" fetch --depth=1 origin
    git -C "$LUMA_DIR" reset --hard FETCH_HEAD
else
    rm -rf "$LUMA_DIR"
    git clone --depth 1 https://github.com/rm-hull/luma.examples.git "$LUMA_DIR"
fi
python3 -m pip install --break-system-packages -e "$LUMA_DIR"

log "Building rpi_ws281x moodlight test binary"
mkdir -p "$(dirname "$WS281X_DIR")"
if [[ -d "$WS281X_DIR/.git" ]]; then
    git -C "$WS281X_DIR" fetch --depth=1 origin
    git -C "$WS281X_DIR" reset --hard FETCH_HEAD
else
    rm -rf "$WS281X_DIR"
    git clone --depth 1 https://github.com/jgarff/rpi_ws281x.git "$WS281X_DIR"
fi
cmake -S "$WS281X_DIR" -B "$WS281X_DIR/build" \
    -D BUILD_SHARED=OFF \
    -D BUILD_TEST=ON
cmake --build "$WS281X_DIR/build" --parallel "$(nproc)"
[[ -x "$WS281X_DIR/build/test" ]] || die "rpi_ws281x test binary was not built"
install -m 0755 "$WS281X_DIR/build/test" "$MOODLIGHT_BIN"

log "Enabling I2C"
if command -v raspi-config >/dev/null 2>&1; then
    raspi-config nonint do_i2c 0 || warn "raspi-config could not enable I2C; applying config.txt fallback."
fi

BOOT_CONFIG=""
for candidate in /boot/firmware/config.txt /boot/config.txt; do
    if [[ -f "$candidate" ]]; then
        BOOT_CONFIG="$candidate"
        break
    fi
done

if [[ -n "$BOOT_CONFIG" ]]; then
    if grep -Eq '^[#[:space:]]*dtparam=i2c_arm=' "$BOOT_CONFIG"; then
        sed -Ei 's|^[#[:space:]]*dtparam=i2c_arm=.*$|dtparam=i2c_arm=on|' "$BOOT_CONFIG"
    else
        printf '\n# Enabled by %s\ndtparam=i2c_arm=on\n' "$PROJECT_NAME" >> "$BOOT_CONFIG"
    fi
    log "I2C configured in $BOOT_CONFIG"
else
    warn "Could not locate Raspberry Pi config.txt. Verify I2C manually before rebooting."
fi

modprobe i2c-dev 2>/dev/null || true
modprobe i2c-bcm2835 2>/dev/null || true

log "Installing MiniTower scripts"
install -d -m 0755 "$INSTALL_DIR"
install -m 0755 "$SCRIPT_DIR/src/sysinfo.py" "$INSTALL_DIR/sysinfo.py"
install -m 0755 "$SCRIPT_DIR/src/turnoff_leds.py" "$INSTALL_DIR/turnoff_leds.py"

log "Installing systemd units"
install -m 0644 "$SCRIPT_DIR/systemd/minitower_moodlight.service" /etc/systemd/system/minitower_moodlight.service
install -m 0644 "$SCRIPT_DIR/systemd/minitower_oled.service" /etc/systemd/system/minitower_oled.service
install -m 0644 "$SCRIPT_DIR/systemd/minitower_disable_led.service" /etc/systemd/system/minitower_disable_led.service

# Remove the obsolete local workaround if it exists. It restarts the OLED after
# boot and is no longer needed with explicit service ordering.
if systemctl list-unit-files minitower_ledfix.service >/dev/null 2>&1; then
    systemctl disable minitower_ledfix.service 2>/dev/null || true
fi

systemctl daemon-reload
systemctl enable minitower_moodlight.service
systemctl enable minitower_oled.service
systemctl enable minitower_disable_led.service

log "Running dependency self-check"
python3 - <<'PY'
from PIL import ImageFont
import psutil
import luma.oled
import board
import neopixel
font = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
ImageFont.truetype(font, 11)
print("Python imports: OK")
print("DejaVuSansMono: OK")
PY

if [[ -e /dev/i2c-1 ]]; then
    log "Current I2C bus scan (OLED is normally 0x3c)"
    i2cdetect -y 1 || true
else
    warn "/dev/i2c-1 is not present yet. A reboot may be required after enabling I2C."
fi

log "Installation complete"
printf '\nUseful tests after reboot:\n'
printf '  python3 %s/examples/clock.py\n' "$LUMA_DIR"
printf '  python3 %s/sysinfo.py\n' "$INSTALL_DIR"
printf '  systemctl status minitower_moodlight minitower_oled minitower_disable_led --no-pager -l\n'
printf '  systemctl --failed\n'

if [[ "$NO_REBOOT" -eq 1 ]]; then
    printf '\nReboot when ready: systemctl reboot\n'
else
    printf '\nRebooting to apply I2C and validate the full cold-boot sequence...\n'
    sync
    systemctl reboot
fi
