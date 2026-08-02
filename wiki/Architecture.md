# Architecture

```text
UEFI Archiso boot
  → systemd on TTY1
  → Cage Wayland kiosk
  → Qt 6/QML Aero7 installer
      → guarded Python disk backend
          → GPT + FAT32 ESP + ext4 root
          → pacstrap focused Arch/Plasma base
          → signed Aero7 package repository
          → Plymouth + systemd-boot

First installed boot
  → aero7-oobe.service
  → Cage + the same Qt application in OOBE mode
      → user, password, hostname, time, update, and network settings
      → guarded Aero7-shell image-mode adapter
      → Welcome / Preparing desktop
      → SDDM one-time autologin
      → Plasma 6 Wayland desktop
```

## UI boundary

QML never formats disks directly. It sends a complete immutable plan and exact
confirmation device to the privileged backend. The backend independently reads
current block-device and VM state immediately before any destructive command.

## Live environment

The ISO does not expose a normal Plasma live session. Cage owns the graphical
output and runs one application. TTY2 remains a recovery getty. A debug boot
entry removes `quiet splash` so early boot failures stay visible.

## Target installation

The base transaction installs a focused `plasma-desktop` runtime. A second
transaction configures the signed Aero7 repository, imports and locally signs
its dedicated public key, refreshes metadata, installs the allowlisted Aero7
packages, and verifies every requested package with `pacman -Q`.

## First boot

OOBE is a root-owned one-time service because it must create an account and
finish system configuration. Aero7-shell image mode requires an exact guard
token, a ready installation provenance marker, and a validated unprivileged
target account. It never creates passwordless sudo.

## First-login cleanup

A short-lived SDDM autologin drop-in provides the continuous first desktop
transition. A one-shot timer removes it after 45 seconds and disables itself.
The per-user helper then repairs menu indexing, application names, light colors,
and the single Aero taskbar before marking completion.

## Source pinning

The ISO records the exact Aero7-shell origin, commit, and clean status digest in
`sources.lock`. Preparation refuses an unexpected source revision or dirty
working tree. Only runtime files are embedded; Git metadata, tests, caches, and
build output are excluded.
