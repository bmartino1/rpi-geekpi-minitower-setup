# Third-party notices

This repository contains or installs components from the following projects.

## Vendored

- **geeekpi/absminitowerkit** — MIT License; original ABS Mini Tower driver,
  service files, and ARM64 moodlight binary by 52 Information Technology., LTD.
  A historical source snapshot is retained under `vendor/upstream/` and the
  runtime moodlight binary under `vendor/geeekpi/`.
- **gentleone/absminitowerkit** — MIT License; historical/community ABS Mini
  Tower implementation retained under `vendor/upstream/` for reference.
- **rm-hull/luma.examples** — MIT License; a minimal OLED test subset is
  retained under `vendor/luma.examples/` with its license notice.

## Installed as runtime dependencies

- **luma.oled / luma.core** — OLED runtime support installed through Python
  packaging.
- **Adafruit Blinka / CircuitPython NeoPixel** — RGB-off helper dependencies,
  installed only for RGB modes.
- **RPi.GPIO** and related Raspberry Pi Python support packages.

Vendored third-party files remain under their original licenses. This
repository's own code is covered by the top-level `LICENSE`.
