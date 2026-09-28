#!/usr/bin/env python3
"""Turn all four ABS Mini Tower WS281x/NeoPixel LEDs off."""

import board
from neopixel import NeoPixel

pixels = NeoPixel(board.D18, 4, auto_write=True)
pixels.fill((0, 0, 0))
