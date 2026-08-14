# Architecture

```text
Archiso boot
  -> systemd on TTY1
  -> Cage kiosk compositor
  -> aero7-installer (Qt 6/QML)
       -> guarded live state machine (default)
       -> aero7-install-backend
            -> validate immutable disk fingerprint
            -> whole-disk GPT + ESP + ext4, or guarded advanced GPT target
            -> pacstrap complete Arch/Plasma dependency set
            -> signed Aero7 binary packages
            -> pinned PlymouthVista theme and initramfs
            -> systemd-boot

First installed boot
  -> aero7-oobe.service on TTY1
  -> Cage
  -> aero7-installer --oobe
       -> aero7-oobe-backend
            -> create user and password
            -> hostname/time/update preference
            -> guarded Aero7-shell image-mode stages
                 -> Plasma theme, layout, and wallpaper
                 -> SDDM and deferred first-login helper
                 -> Fastfetch, management commands, and validation
            -> configure one-time SDDM autologin and self-disabling cleanup timer
            -> disable OOBE, enable SDDM
       -> automatic Welcome and Preparing Desktop pages
       -> full-screen fade
       -> start SDDM without another reboot
       -> automatic first desktop login
```

In simulation mode only, the controller changes from the installer state
machine to the OOBE state machine after the restart countdown. Automatic
transition pages reproduce the applying-settings, video-check, Welcome, and
Preparing Desktop phases before a non-functional desktop preview. Live-install
mode performs one required reboot from the installation media into the newly
installed system. After personalization, it transitions directly from OOBE to
the real Plasma desktop without a second reboot or manual Continue button.

## Trust boundaries

QML never runs partitioning commands. The unprivileged UI sends a complete disk
and target fingerprint plus an exact confirmation path to one narrow backend.
Immediately before modifying anything, the backend repeats `lsblk`, mount,
live-media, VM, size, model, serial, read-only, removable, GPT, UUID, and sector
geometry checks. Advanced mode then saves a private restorable partition-table
dump. Unallocated, replace-one-partition, and NTFS-shrink plans are fixed in the
backend; arbitrary partitioning commands never cross the UI boundary.

The ISO service runs as root because Arch installation is privileged. This is
not carried into the installed desktop. OOBE also runs only for the first boot
and permanently disables itself after the Aero7-shell stages finish. Its SDDM
autologin drop-in is temporary: a 45-second one-shot timer removes it and
disables itself, returning later boots to password authentication. Image mode
requires root, an exact guard token, a ready provenance marker, and a validated
unprivileged target account. It creates no passwordless sudo policy.

## Source consumption

`scripts/build-iso.sh` reads `sources.lock`, verifies the source clone's origin,
HEAD, and porcelain-status digest, then copies a runtime-only subset plus the
public Aero7 repository key into the temporary Archiso profile. Git metadata,
tests, caches, and development output are excluded. The build does not execute
the source installer or write into the clone.

Aero7-shell remains an independent repository with its own history, tests,
release decisions, and update path. The ISO repository owns only the installer,
OOBE, boot media, and the exact shell revision pin. Updating the desktop requires
a tested Aero7-shell commit first, followed by a deliberate `sources.lock`
change here; shell source is never vendored or maintained in the ISO tree.

## Display model

The QML root fills the output with original background artwork. Installer panels
are placed on a 1024×768 logical canvas and uniformly scaled, preserving spacing
and hierarchy at all required resolutions. Controls support mouse, keyboard
focus, Tab/Shift+Tab, Enter, Escape, and visible focus indicators.
