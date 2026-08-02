# Beta 1 Implementation Status

The original vertical slice has grown into a guarded VM-only installation
path. This document records the completed Beta 1 scope and the work deliberately
left for later releases.

## Complete in Beta 1

1. Pin and verify a read-only Aero7-shell source checkout by origin, commit, and
   clean working-tree digest.
2. Build one scalable Qt 6/QML application with separate installer and OOBE
   state machines on a 1024×768 logical canvas.
3. Provide a narrow privileged backend that accepts only a revalidated,
   disposable VirtIO VM disk and creates the fixed GPT/ESP/ext4 layout.
4. Assemble an Archiso image that starts Cage and the installer on TTY1, keeps
   recovery on TTY2, and exposes no live Plasma desktop.
5. Install a one-time Cage/OOBE service that creates the real user, applies the
   Aero7-shell image-mode configuration, enables SDDM, and hands directly to the
   first Plasma session.
6. Remove temporary first-session autologin automatically and return subsequent
   boots to password authentication.
7. Install a focused Plasma 6 Wayland base plus the signed Aero7 desktop and
   applications, with one taskbar and consistent light defaults.
8. Validate state transitions, package parity, disk plans, QML, compiled Qt
   logic, visual renders, the embedded ISO payload, and a fresh VM boot.

## Deliberately deferred

- physical-hardware installation;
- dual boot and install-alongside;
- encryption and manual partitioning;
- legacy BIOS;
- offline package installation;
- broader language and region coverage;
- automatic NVIDIA-specific selection;
- recovery environment beyond the TTY2 console.

These features must not be enabled by removing guards. Each requires its own
design, safety review, automated tests, and disposable-hardware validation.
