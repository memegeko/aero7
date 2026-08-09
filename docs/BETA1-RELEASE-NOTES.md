# Aero7 Beta 1

Aero7 Beta 1 is the first test release of the graphical installer and
desktop image. It combines an Arch Linux foundation, KDE Plasma 6 Wayland, the
signed Aero7 desktop packages, a purpose-built Qt/QML installer, and a guided
first-boot setup.

> **Back up important data before installing.** Beta 1 supports guarded
> installation on x86-64 UEFI PCs and virtual machines, but it remains
> Beta software. Disconnect unrelated disks and verify the selected
> target before any partition change.

## Download identity

- release tag: `v0.1.0-beta.1`
- ISO: `aero7-beta1-2026.08.09-x86_64.iso`
- size: `1,401,708,544` bytes
- SHA-256: `107d044c41f4bba8e8c308e11b7986858ff46a525937e8f0508181d0c9c6c710`
- ISO label: `AERO7B1_20260809`
- application ID: `AERO7 BETA 1 X86_64 UEFI INSTALLATION MEDIUM`

Download the `.iso` and `.sha256` files from the GitHub release, keep them in
the same directory, and verify them with:

```bash
sha256sum -c aero7-beta1-2026.08.09-x86_64.iso.sha256
```

## Highlights

- direct-to-installer boot with no exposed live desktop;
- full-screen Qt 6/QML setup and OOBE in a Cage Wayland kiosk;
- guarded UEFI/GPT installation to non-removable SATA, NVMe, MMC, or VirtIO
  disks;
- whole-disk installation plus guided New, Format, Shrink, Delete, Extend, and
  storage-driver actions;
- disk identity revalidation immediately before destructive operations;
- signed Aero7 binary packages on a focused `plasma-desktop` base;
- a single Aero taskbar, populated Start menu, light desktop defaults, and
  consistent File Explorer, Photo Viewer, Command Prompt, and Task Manager
  presentation;
- matching installer, Plymouth, OOBE, SDDM, lock-screen, and desktop branding;
- automatic Welcome and Preparing your desktop sequence;
- one-time first-desktop autologin that removes itself after handoff;
- recovery console on TTY2 and a verbose no-splash boot entry;
- Repair your computer handoff to the recovery shell;
- disabled Upgrade option and detailed Linux/open-source license notice;
- Ventoy, Rufus, direct-write, and QEMU/KVM installation paths documented in
  the handbook;
- SPICE/QXL developer launcher defaults that avoid the cursor trails, stale
  fragments, black repaint screen, and dropped clicks seen with earlier VM
  combinations.

## Included Aero7 applications

- Aero Dolphin as **File Explorer**;
- Aero Gwenview as **Photo Viewer**;
- Linux Control Panel and Device Manager;
- Aero KolourPaint;
- Gadgets, execbin, LinVer, and TuxManager;
- QTerminal as **Command Prompt**;
- VLC as **Media Player**;
- Spectacle as **Snipping Tool**, with Print Screen and Meta+Shift+S region
  capture shortcuts;
- KCalc as **Calculator**;
- FeatherPad as **Notepad**.

WinXplorer is optional and is not installed by the ISO. Sevulet is not included
because its source and redistribution terms have not been verified.

## Screenshots

![Aero7 desktop](screenshots/desktop-overview.png)

The current development installer, OOBE, desktop, application, lock-screen,
system-menu, and authentication captures are collected in the
[Screenshot Gallery](../wiki/Screenshot-Gallery.md). The installer and OOBE
sequences are generated from the shipping QML source; desktop and application
captures come from a clean installation of the Beta 1 validation candidate.

## Beta limitations

- x86-64 UEFI only, with Secure Boot disabled;
- RAID On/Intel RST storage is unsupported; disks must be exposed through AHCI;
- whole-disk GPT or guarded guided-partition targets, with a 1 GiB FAT32 ESP
  and ext4 root;
- no encryption, unrestricted manual partition editor, legacy BIOS, or offline
  package payload;
- working network access is required during installation;
- language and regional choices are limited to the currently validated flow.

## Validation

The exact ISO above passed `scripts/verify-release.sh`, including inspection of
the bootable ISO 9660/GPT/UEFI structure, embedded SquashFS, source lock,
destructive-operation gates, package manifest, focused Plasma payload, Aero
layout, application branding, and Beta 1 identity. A clean boot of the release
artifact reached the graphical language page without rendering corruption.

The August 9 release image passed the complete automated image gate. Beta
candidates completed the full installation, OOBE, first-desktop, application,
lock-screen, authentication, and clean-shutdown flow in QEMU/KVM. The August 9
candidate also completed a whole-disk installation on a Dell Latitude 3310 and
reached a working desktop.

See the [validation report](validation.md) and the
[Aero7 handbook](../wiki/Home.md) for details.

## Legal notice

Aero7 is an independent open-source project and is not affiliated with or
endorsed by Microsoft Corporation. Third-party software and artwork retain
their own licenses and notices. PlymouthVista is included under its distributed
MIT license, and Aero7 replaces its logo/reveal/branding frames with project
artwork. See `THIRD_PARTY.md`.
