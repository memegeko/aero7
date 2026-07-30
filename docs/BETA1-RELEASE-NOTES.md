# Aero7 ISO Beta 1

Aero7 ISO Beta 1 is the first test release of the VM-only graphical installer.
It provides a Windows-7-era-inspired setup flow with original Aero7 branding,
installs the pinned Arch/Plasma/Aero7 payload, and continues into first-boot
setup before handing directly to the desktop.

Refreshed release artifact: pending the final privileged Archiso build and
fresh-VM gate. Do not reuse the checksum from the previous candidate.

## Highlights

- full-screen Qt/QML installer and OOBE in a Cage Wayland kiosk;
- clean QXL guest rendering through the stable SDL host frontend, without
  cursor trails, stale-page fragments, or GTK stride flashes;
- UEFI/GPT whole-disk installation to a guarded disposable VirtIO disk;
- disk-first reboot while the installer ISO remains attached;
- unchanged PlymouthVista animation with enough display time to finish;
- automatic Welcome and Preparing Desktop sequence;
- one-time first-desktop autologin, removed after 45 seconds;
- original Aero7 logo, installer branding, SDDM branding, and logout watermark;
- full black finalization screen without blue edge leakage;
- recovery console on TTY2 and a verbose no-splash boot entry.
- confirmed **Repair your computer** handoff to the TTY2 recovery shell;
- unavailable Upgrade option is visibly disabled and cannot be activated;
- detailed Linux/open-source, data-loss, network, and no-warranty notice;
- package parity checks plus post-install verification of every Aero package;
- light first-session KDE defaults and the pinned shell wallpaper across SDDM,
  Welcome, lock screen, and Plasma;
- glossy project-owned 350x50 PNG login and Welcome branding.

## Beta limitations

- x86-64 UEFI only;
- VM-only destructive backend (`/dev/vd*` with VM and fingerprint guards);
- whole-disk GPT/FAT32/ext4 layout only;
- no dual boot, encryption, manual partitioning, legacy BIOS, or physical-disk
  installation;
- package installation requires working internet access;
- ShellCheck was not available on the build host.

Use only with the provided `scripts/run-qemu.sh --fresh` workflow and keep
backups of anything important.
