# Vendored Luma examples subset

This directory intentionally contains only the Luma example files needed to
validate the ABS Mini Tower OLED without cloning another repository during
installation:

- `examples/demo_opts.py`
- `examples/clock.py`

The runtime OLED libraries (`luma.core` / `luma.oled`) are installed through
Python packaging by `install.sh`; they are not copied into this repository.

Upstream: https://github.com/rm-hull/luma.examples
License: MIT; see `LICENSE.rst`.

This subset can be replaced later with a fuller known-good Luma snapshot if
required, but the production `/usr/local/minitower/sysinfo.py` does not depend
on this directory.
