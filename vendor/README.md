# Vendored / reference components

This project keeps the case-specific pieces needed for repeatable recovery in
one repository instead of depending on multiple GitHub repositories at install
time.

## Runtime vendor files

- `luma.examples/` — minimal MIT-licensed Luma OLED test subset (`clock.py` and
  `demo_opts.py`). The production OLED service does not depend on these files.
- `geeekpi/moodlight-aarch64` — ARM64 moodlight/test binary from the official
  GeeekPi ABS Mini Tower source snapshot. It is installed only for RGB modes.

## Upstream reference snapshots

`upstream/` contains the two historical ABS Mini Tower repositories used while
building this standalone Trixie installer. They are retained for provenance and
troubleshooting; `install.sh` does not execute their installers.

- `upstream/geeekpi-absminitowerkit/`
- `upstream/gentleone-absminitowerkit/`

See each snapshot's own license file and `../THIRD_PARTY_NOTICES.md`.
