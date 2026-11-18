#!/usr/bin/env python3
"""Set the four MiniTower WS281x LEDs to a persistent solid color."""
import os
import board
import neopixel

NAMED_COLORS = {
    "blue": "0000FF",
    "red": "FF0000",
    "green": "00FF00",
    "white": "FFFFFF",
    "purple": "8000FF",
    "cyan": "00FFFF",
    "yellow": "FFFF00",
    "orange": "FF8000",
}

def rgb_from_value(value):
    value = value.strip().lower()
    value = NAMED_COLORS.get(value, value.removeprefix("#"))
    if len(value) != 6 or any(c not in "0123456789abcdef" for c in value):
        raise ValueError("Color must be a named color or 6-digit RGB hex value")
    return tuple(int(value[i:i+2], 16) for i in (0, 2, 4))

color = rgb_from_value(os.environ.get("MINITOWER_COLOR", "blue"))
brightness = float(os.environ.get("MINITOWER_BRIGHTNESS", "0.30"))
if not (0.0 <= brightness <= 1.0):
    raise ValueError("MINITOWER_BRIGHTNESS must be between 0 and 1")
pixels = neopixel.NeoPixel(board.D18, 4, brightness=brightness, auto_write=False)
pixels.fill(color)
pixels.show()
