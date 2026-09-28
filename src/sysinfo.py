#!/usr/bin/env python3
"""128x64 SSD1305 system information display for the ABS Mini Tower."""

import os
import socket
import time
from pathlib import Path

import psutil
from PIL import ImageFont
from luma.core.interface.serial import i2c
from luma.core.render import canvas
from luma.oled.device import ssd1305

FONT_CANDIDATES = (
    Path("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"),
    Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
)


def bytes2human(value: int) -> str:
    units = ("B", "K", "M", "G", "T")
    number = float(value)
    for unit in units:
        if number < 1024.0 or unit == units[-1]:
            if unit == "B":
                return f"{int(number)}{unit}"
            return f"{number:.0f}{unit}"
        number /= 1024.0
    return f"{int(value)}B"


def load_font(size: int = 11):
    for path in FONT_CANDIDATES:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    # The installer installs fonts-dejavu-core, but this fallback prevents the
    # OLED service from crash-looping if fonts are changed later.
    return ImageFont.load_default()


def primary_interface() -> str | None:
    # Prefer the interface carrying the default route.
    try:
        with open("/proc/net/route", "r", encoding="utf-8") as route_file:
            next(route_file, None)
            for line in route_file:
                fields = line.split()
                if len(fields) >= 4 and fields[1] == "00000000":
                    return fields[0]
    except OSError:
        pass

    stats = psutil.net_if_stats()
    for iface, iface_stats in stats.items():
        if iface != "lo" and iface_stats.isup:
            return iface
    return None


def primary_ip() -> str:
    iface = primary_interface()
    if iface:
        for addr in psutil.net_if_addrs().get(iface, []):
            if addr.family == socket.AF_INET:
                return addr.address
    return "no-ip"


def load_line() -> str:
    av1, av5, av15 = os.getloadavg()
    return f"Ld:{av1:.1f} {av5:.1f} {av15:.1f}"


def memory_line() -> str:
    mem = psutil.virtual_memory()
    return f"Mem:{bytes2human(mem.used)} {mem.percent:.0f}%"


def disk_line() -> str:
    disk = psutil.disk_usage("/")
    return f"SD:{bytes2human(disk.used)} {disk.percent:.0f}%"


def network_line() -> str:
    iface = primary_interface()
    if not iface:
        return "Net:offline"
    counters = psutil.net_io_counters(pernic=True).get(iface)
    if counters is None:
        return f"{iface}:offline"
    # Keep the line short enough for the 128-pixel OLED.
    return f"{iface} T{bytes2human(counters.bytes_sent)} R{bytes2human(counters.bytes_recv)}"


def main() -> None:
    # The known ABS Mini Tower display is a 128x64 SSD1305 at I2C address 0x3c.
    serial = i2c(port=1, address=0x3C)
    device = ssd1305(serial, width=128, height=64)
    font = load_font(11)

    print("MiniTower OLED: ssd1305, I2C 0x3c, 128x64")

    while True:
        with canvas(device) as draw:
            draw.text((0, 1), load_line(), font=font, fill="white")
            draw.text((0, 12), memory_line(), font=font, fill="white")
            draw.text((0, 24), disk_line(), font=font, fill="white")
            draw.text((0, 36), network_line(), font=font, fill="white")
            draw.text((0, 48), f"IP:{primary_ip()}", font=font, fill="white")
        time.sleep(5)


if __name__ == "__main__":
    main()
