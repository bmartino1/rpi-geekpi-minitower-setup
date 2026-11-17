#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_NAME="rpi-geekpi-minitower-setup"
INSTALL_DIR="/usr/local/minitower"
LUMA_DIR="/opt/luma.examples"
MOODLIGHT_BIN="/usr/local/bin/minitower-moodlight"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VENDORED_LUMA_DIR="$SCRIPT_DIR/vendor/luma.examples"
VENDORED_MOODLIGHT="$SCRIPT_DIR/vendor/geeekpi/moodlight-aarch64"

log()  { printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"; }
warn() { printf '\nWARNING: %s\n' "$*" >&2; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'USAGE'
Usage: ./install.sh [OPTIONS]

Installs GeeekPi-style ABS Mini Tower OLED/RGB support for modern
64-bit Raspberry Pi OS / Debian, with Trixie as the primary target.

Operating modes:
  1 / rgb-off    OLED + fan + initialize RGB, then turn RGB off (recommended)
  2 / moodlight  OLED + fan + keep the MiniTower RGB moodlight running
  3 / oled-only  OLED only; do not start either RGB service

The case fan is powered by the MiniTower hardware. These mode choices control
OLED/RGB services; they do not intentionally turn off fan power.

Options:
  --mode MODE       MODE is rgb-off, moodlight, or oled-only
  --rgb-off         Alias for --mode rgb-off
  --moodlight       Alias for --mode moodlight
  --oled-only       Alias for --mode oled-only
  --no-reboot       Do not reboot automatically after installation
  -h, --help        Show this help

With no mode option, an interactive menu is shown when run from a terminal.
For non-interactive execution, rgb-off is used unless --mode is specified.
USAGE
}

if [[ ${EUID} -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo -E bash "$0" "$@"
    fi
    die "Run this installer as root."
fi

NO_REBOOT=0
MODE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-reboot)
            NO_REBOOT=1
            shift
            ;;
        --mode)
            [[ $# -ge 2 ]] || die "--mode requires rgb-off, moodlight, or oled-only"
            MODE="$2"
            shift 2
            ;;
        --mode=*)
            MODE="${1#*=}"
            shift
            ;;
        --rgb-off)
            MODE="rgb-off"
            shift
            ;;
        --moodlight)
            MODE="moodlight"
            shift
            ;;
        --oled-only)
            MODE="oled-only"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1"
            ;;
    esac
done

choose_mode() {
    if [[ -n "$MODE" ]]; then
        return
    fi

    if [[ -t 0 ]]; then
        printf '\nChoose MiniTower operating mode:\n\n'
        printf '  1) OLED + fan + RGB OFF after initialization  [recommended]\n'
        printf '  2) OLED + fan + RGB moodlight ON\n'
        printf '  3) OLED only (no RGB services)\n\n'
        printf 'Selection [1]: '
        read -r selection
        selection="${selection:-1}"
        case "$selection" in
            1|rgb-off)   MODE="rgb-off" ;;
            2|moodlight) MODE="moodlight" ;;
            3|oled-only) MODE="oled-only" ;;
            *) die "Invalid selection: $selection" ;;
        esac
    else
        MODE="rgb-off"
        warn "No interactive terminal detected; defaulting to --mode rgb-off."
    fi
}

choose_mode
case "$MODE" in
    rgb-off|moodlight|oled-only) ;;
    *) die "Invalid mode '$MODE'. Use rgb-off, moodlight, or oled-only." ;;
esac

[[ -r /etc/os-release ]] || die "/etc/os-release not found"
# shellcheck disable=SC1091
source /etc/os-release
CODENAME="${VERSION_CODENAME:-unknown}"
ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
MODEL="$(tr -d '\0' </proc/device-tree/model 2>/dev/null || true)"

log "Installing $PROJECT_NAME"
printf 'OS: %s %s (%s)\n' "${PRETTY_NAME:-unknown}" "$CODENAME" "$ARCH"
printf 'Hardware: %s\n' "${MODEL:-unknown}"
printf 'Selected mode: %s\n' "$MODE"

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
    ca-certificates git build-essential pkg-config \
    i2c-tools \
    python3 python3-dev python3-pip python3-pil python3-venv \
    python3-psutil python3-rpi.gpio \
    libjpeg-dev zlib1g-dev libfreetype6-dev liblcms2-dev \
    libopenjp2-7-dev libtiff-dev \
    fonts-dejavu-core

log "Installing Python OLED packages (PEP 668 aware)"
python3 -m pip install --break-system-packages \
    luma.oled \
    RPi.GPIO

if [[ "$MODE" != "oled-only" ]]; then
    log "Installing RGB/NeoPixel Python packages (PEP 668 aware)"
    # Blinka/NeoPixel does not always pull the Raspberry Pi WS281x backend in
    # automatically (notably on Debian/Raspberry Pi OS Trixie + Python 3.13).
    # Without it, importing neopixel fails with:
    # ModuleNotFoundError: No module named '_rpi_ws281x'
    python3 -m pip install --break-system-packages \
        'rpi_ws281x>=4.0.0' \
        adafruit-blinka \
        adafruit-circuitpython-neopixel
fi

log "Installing vendored Luma OLED test files"
[[ -f "$VENDORED_LUMA_DIR/examples/clock.py" ]] || die "Vendored Luma clock.py is missing"
[[ -f "$VENDORED_LUMA_DIR/examples/demo_opts.py" ]] || die "Vendored Luma demo_opts.py is missing"
rm -rf "$LUMA_DIR"
install -d -m 0755 "$LUMA_DIR"
cp -a "$VENDORED_LUMA_DIR/." "$LUMA_DIR/"

if [[ "$MODE" != "oled-only" ]]; then
    log "Installing vendored GeeekPi ARM64 moodlight binary"
    [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]] || \
        die "RGB modes currently require the vendored ARM64 moodlight binary; detected $ARCH"
    [[ -x "$VENDORED_MOODLIGHT" ]] || die "Vendored moodlight binary is missing or not executable"
    install -m 0755 "$VENDORED_MOODLIGHT" "$MOODLIGHT_BIN"
fi

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

# Obsolete workaround from earlier manual installs. Explicit service ordering now
# handles the OLED/RGB boot sequence.
if systemctl list-unit-files minitower_ledfix.service >/dev/null 2>&1; then
    systemctl disable minitower_ledfix.service 2>/dev/null || true
fi

systemctl daemon-reload

# Always provide the OLED system-information display.
systemctl enable minitower_oled.service

# Set the selected next-boot service state. We intentionally do not force-stop
# a currently running moodlight process here because some older vendor units can
# resist a live stop; the normal reboot at the end applies the selected state.
case "$MODE" in
    rgb-off)
        systemctl enable minitower_moodlight.service
        systemctl enable minitower_disable_led.service
        ;;
    moodlight)
        systemctl enable minitower_moodlight.service
        systemctl disable minitower_disable_led.service 2>/dev/null || true
        ;;
    oled-only)
        systemctl disable minitower_moodlight.service 2>/dev/null || true
        systemctl disable minitower_disable_led.service 2>/dev/null || true
        ;;
esac

log "Running dependency self-check"
python3 - <<'PY'
from PIL import ImageFont
import psutil
import luma.oled
font = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
ImageFont.truetype(font, 11)
print("OLED Python imports: OK")
print("DejaVuSansMono: OK")
PY

if [[ "$MODE" != "oled-only" ]]; then
    python3 - <<'PY'
import _rpi_ws281x
import board
import neopixel
print("rpi_ws281x backend import: OK")
print("RGB/NeoPixel Python imports: OK")
PY
fi

if [[ -e /dev/i2c-1 ]]; then
    log "Current I2C bus scan (OLED is normally 0x3c)"
    i2cdetect -y 1 || true
else
    warn "/dev/i2c-1 is not present yet. A reboot may be required after enabling I2C."
fi

log "Installation complete"
printf '\nSelected operating mode: %s\n' "$MODE"
case "$MODE" in
    rgb-off)
        printf 'Expected after boot: fan ON, OLED ON, RGB OFF after about 10 seconds.\n'
        ;;
    moodlight)
        printf 'Expected after boot: fan ON, OLED ON, RGB moodlight running.\n'
        ;;
    oled-only)
        printf 'Expected after boot: fan powered by case hardware, OLED ON, RGB services disabled.\n'
        ;;
esac

printf '\nUseful tests after reboot:\n'
printf '  python3 %s/examples/clock.py -d ssd1305 -i i2c --width 128 --height 64\n' "$LUMA_DIR"
printf '  python3 %s/sysinfo.py\n' "$INSTALL_DIR"
printf '  systemctl status minitower_moodlight minitower_oled minitower_disable_led --no-pager -l\n'
printf '  systemctl --failed\n'

if [[ "$NO_REBOOT" -eq 1 ]]; then
    printf '\nService enable/disable changes are configured for the next boot.\n'
    printf 'Reboot when ready: systemctl reboot\n'
else
    printf '\nRebooting to apply I2C and the selected MiniTower mode...\n'
    sync
    systemctl reboot
fi
