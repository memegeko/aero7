# Frequently Asked Questions

## Is Aero7 Windows?

No. Aero7 is an independent Arch Linux-based operating system with KDE Plasma
6 and an Aero-inspired interface. It does not contain a licensed copy of
Microsoft Windows.

## Can I install Beta 1 on a real PC?

No. Beta 1 deliberately blocks physical disks and supports only a disposable
VirtIO disk in QEMU/KVM. Physical-hardware support is a later milestone.

## Can it dual boot or keep my files?

No. The only enabled path erases the selected VM disk and creates a fixed GPT,
FAT32 ESP, and ext4 root layout. Upgrade, install-alongside, encryption, and
manual partitioning are unavailable.

## Why is Upgrade greyed out?

It communicates the familiar installer structure while making the Beta 1
capability honest: only clean custom installation is implemented.

## Does installation need internet access?

Yes. Beta 1 installs packages from Arch Linux and the signed Aero7 repository.
An offline payload is not included yet.

## Why did the VM boot into setup again?

The virtual disk must be first in UEFI boot order and the DVD second. Follow
the fix in [Troubleshooting](Troubleshooting.md).

## Is WinXplorer included?

No. Aero Dolphin, shown as **File Explorer**, is the supported default. The
WinXplorer package remains optional and is intentionally excluded from the ISO.

## Why does the second boot ask for my password?

That is expected. Only the first desktop handoff uses temporary autologin. A
self-disabling cleanup timer removes it so later boots use normal SDDM
authentication.

## Where are installer logs?

Press Alt+F2 for the recovery console and follow
[Recovery and Logs](Recovery-and-Logs.md).

## Can I build it myself?

Yes, if you are an experienced Arch Linux developer. See
[Building the ISO](Building-the-ISO.md) and review
[Credits and Licensing](Credits-and-Licensing.md) before sharing the result.
