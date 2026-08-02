# Aero7 Beta 1

Aero7 Beta 1 is the first test release of the VM-only graphical installer and
desktop image. It combines an Arch Linux foundation, KDE Plasma 6 Wayland, the
signed Aero7 desktop packages, a purpose-built Qt/QML installer, and a guided
first-boot setup.

> **Use only in a disposable QEMU/KVM virtual machine.** Beta 1 intentionally
> blocks physical disks and supports only whole-disk installation to a VirtIO
> target.

## Download identity

- release tag: `v0.1.0-beta.1`
- ISO: `aero7-beta1-2026.08.02-x86_64.iso`
- size: `1,406,070,784` bytes
- SHA-256: `64115bd497315a871d06786160016487eb9e3eb514fc48900c770a8d9fc6feec`
- ISO label: `AERO7B1_20260802`
- application ID: `AERO7 BETA 1 X86_64 UEFI INSTALLATION MEDIUM`

Download the `.iso` and `.sha256` files from the GitHub release, keep them in
the same directory, and verify them with:

```bash
sha256sum -c aero7-beta1-2026.08.02-x86_64.iso.sha256
```

## Highlights

- direct-to-installer boot with no exposed live desktop;
- full-screen Qt 6/QML setup and OOBE in a Cage Wayland kiosk;
- guarded UEFI/GPT whole-disk installation to a disposable VirtIO disk;
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
- SPICE/QXL launcher defaults that avoid the cursor trails, stale fragments,
  black repaint screen, and dropped clicks seen with earlier VM combinations.

## Included Aero7 applications

- Aero Dolphin as **File Explorer**;
- Aero Gwenview as **Photo Viewer**;
- Linux Control Panel and Device Manager;
- Aero KolourPaint;
- Gadgets, execbin, LinVer, and TuxManager;
- Konsole integration as **Command Prompt**.

WinXplorer is optional and is not installed by the ISO. Sevulet is not included
because its source and redistribution terms have not been verified.

## Beta limitations

- x86-64 UEFI and QEMU/KVM only;
- destructive backend limited to a guarded `/dev/vd*` VM disk;
- fixed whole-disk GPT, 1 GiB FAT32 ESP, and ext4 root layout;
- no dual boot, encryption, manual partitioning, legacy BIOS, physical-disk
  installation, or offline package payload;
- working network access is required during installation;
- language and regional choices are limited to the currently validated flow.

## Validation

The exact ISO above passed `scripts/verify-release.sh`, including inspection of
the bootable ISO 9660/GPT/UEFI structure, embedded SquashFS, source lock,
destructive-operation gates, package manifest, focused Plasma payload, Aero
layout, application branding, and Beta 1 identity. A clean boot of the release
artifact reached the graphical language page without rendering corruption.

The full installation/OOBE/first-desktop sequence was previously validated on
the immediately preceding Beta candidate. The final August 2 image includes
the verified package-focus regression changes and passed the automated release
gate; treat it as Beta software and report any full-flow regression.

See the [validation report](validation.md) and the
[Aero7 handbook](../wiki/Home.md) for details.

## Legal notice

Aero7 is an independent open-source project and is not affiliated with or
endorsed by Microsoft Corporation. Third-party software and artwork retain
their own licenses and notices. In particular, the retained PlymouthVista
animation frames require an independent rights review before public or
commercial redistribution; see `THIRD_PARTY.md`.
