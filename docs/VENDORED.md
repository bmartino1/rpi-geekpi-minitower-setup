# Vendored components

The goal of this repository is repeatable recovery of the ABS Mini Tower on a
fresh Debian/Raspberry Pi OS installation without depending on several old
installers at runtime.

## Luma OLED test subset

`vendor/luma.examples/` contains only the example support used for a basic OLED
hardware test (`clock.py` + `demo_opts.py`). Luma examples are MIT licensed.
The maintained `luma.oled`/`luma.core` Python packages are still installed by
`pip` because those are runtime libraries, not case-specific source files.

Upstream: https://github.com/rm-hull/luma.examples

## GeeekPi moodlight binary

`vendor/geeekpi/moodlight-aarch64` is the ARM64 `moodlight` executable from the
official GeeekPi ABS Mini Tower source snapshot used while recovering the
working Raspberry Pi 4. It is installed only when `rgb-off` or `moodlight` mode
is selected.

The included snapshot corresponds to official GeeekPi commit:
`96c3e542ede8cfecdf94dde1d727a138ca680996`.

Before a later release, `tools/capture-working-assets.sh` can be run on the
known-good Pi to capture and compare the actually running `/usr/bin/moodlight`
or `/usr/local/bin/minitower-moodlight` binary.

## Historical ABS Mini Tower snapshots

For troubleshooting/provenance, `vendor/upstream/` contains the source trees
provided while this project was assembled:

- official GeeekPi/52Pi snapshot — commit
  `96c3e542ede8cfecdf94dde1d727a138ca680996`
- gentleone community snapshot — commit
  `4784b91b5188082e3a4c35486d8708066a68fb5a`

These historical installers are reference material only. The top-level
`install.sh` is the supported installer for this repository.
