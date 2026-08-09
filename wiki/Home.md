# Aero7 Wiki

<p align="center">
  <img src="https://raw.githubusercontent.com/memegeko/aero7/beta/installer/assets/aero7-logo-circle.png" width="150" alt="Aero7 logo">
</p>

Welcome to the handbook for **Aero7**, an independent Arch Linux-based operating
system with a Windows-7-era-inspired installer and KDE Plasma 6 Wayland desktop.

![Aero7 desktop](images/desktop-overview.png)

> **Beta 1 supports x86-64 UEFI PCs and virtual machines.** The guarded
> installer accepts non-removable SATA, NVMe, MMC, and VirtIO disks. Back up
> important data, disconnect unrelated disks, and verify the selected disk:
> Beta software and partition changes can still cause data loss.
>
> **Public redistribution is not approved yet.** The private Beta is completing
> an artwork-rights, mark, and repository-history review. See
> [Testing and Release](Testing-and-Release.md) for the release gate.

## Start here

| I want to… | Read… |
| --- | --- |
| Download and install Beta 1 | [Installation](Installation.md) |
| Check whether my VM or test PC is supported | [System Requirements](System-Requirements.md) |
| Understand every setup page | [Installer Guide](Installer-Guide.md) |
| Learn what happens after restart | [First Boot and OOBE](First-Boot-and-OOBE.md) |
| See which programs are included | [Included Software](Included-Software.md) |
| Browse the current interface | [Screenshot Gallery](Screenshot-Gallery.md) |
| Fix a failed or black-screen boot | [Troubleshooting](Troubleshooting.md) |
| Open the recovery console | [Recovery and Logs](Recovery-and-Logs.md) |
| Review Beta limitations | [Known Issues](Known-Issues.md) |

## Technical documentation

- [Architecture](Architecture.md)
- [Security and Disk Safety](Security-and-Disk-Safety.md)
- [Building the ISO](Building-the-ISO.md)
- [Testing and Release](Testing-and-Release.md)
- [Public Release Readiness](Public-Release-Readiness.md)
- [Credits and Licensing](Credits-and-Licensing.md)
- [FAQ](FAQ.md)

## Beta 1 artifact

| | |
| --- | --- |
| File | `aero7-beta1-2026.08.09-x86_64.iso` |
| Size | 1,401,708,544 bytes |
| SHA-256 | `107d044c41f4bba8e8c308e11b7986858ff46a525937e8f0508181d0c9c6c710` |
| Firmware | x86-64 UEFI |
| Desktop | KDE Plasma 6 Wayland |
| Intended target | UEFI test PC or disposable QEMU/KVM VM |

Testers can download it from the
[Beta 1 GitHub release](https://github.com/memegeko/aero7/releases/tag/v0.1.0-beta.1).

## Project links

- [Aero7 repository](https://github.com/memegeko/aero7)
- [Aero7-shell](https://github.com/memegeko/aero7-shell)
- [Signed Aero7 package repository](https://github.com/memegeko/aero7-repo)
- [Issue tracker](https://github.com/memegeko/aero7/issues)

Aero7 is not affiliated with or endorsed by Microsoft Corporation. It does not
contain a licensed copy of Microsoft Windows.
