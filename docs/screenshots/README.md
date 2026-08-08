# Documentation screenshots

This directory contains the current Aero7 installer, first-boot, desktop, and
application screenshots used by the repository README and handbook.

The installer and OOBE images are deterministic 1024×768 captures generated
from the same Qt/QML sources shipped by the ISO:

```bash
cmake -S installer -B build/installer -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/installer
./scripts/render-smoke.sh
```

`--documentation-screenshot` keeps the controller in its non-destructive demo
backend while hiding demo-only labels. It never enables the live disk backend.
The numbered filenames follow the order in which pages appear.

Desktop and application screenshots are captured from a clean installed Aero7
VM after OOBE and the first-login repair have completed. They are documentation
only and are not installed as runtime artwork.

When the interface changes, replace the complete affected sequence. Do not mix
screens from different builds or keep superseded screenshots under alternate
names.

The current set contains:

- 10 ordered installer screens (`installer-01` through `installer-10`);
- 11 ordered OOBE screens (`oobe-01` through `oobe-11`);
- 11 desktop, Start-menu, system-popup, lock, and authentication screens;
- 12 application screens.
