# Installation

Beta 1 is designed for a **disposable QEMU/KVM virtual machine**. Its installer
will reject physical disks and non-VirtIO targets.

## 1. Download

Open the [latest Aero7 release](https://github.com/memegeko/aero7/releases/latest)
and download both files:

- `aero7-beta1-2026.08.02-x86_64.iso`
- `aero7-beta1-2026.08.02-x86_64.iso.sha256`

## 2. Verify the download

On Linux, place both files in the same directory and run:

```bash
sha256sum -c aero7-beta1-2026.08.02-x86_64.iso.sha256
```

Expected result:

```text
aero7-beta1-2026.08.02-x86_64.iso: OK
```

The expected SHA-256 is:

```text
64115bd497315a871d06786160016487eb9e3eb514fc48900c770a8d9fc6feec
```

## 3. Create the virtual machine

Recommended configuration:

| Setting | Value |
| --- | --- |
| Architecture | x86-64 |
| Firmware | UEFI/OVMF |
| CPU | 4 virtual CPUs |
| Memory | 4 GiB minimum; 8 GiB comfortable |
| Display | QXL with SPICE |
| Input | VirtIO tablet |
| Network | User-mode/NAT with internet access |
| Disk | New 40 GiB VirtIO block disk |
| Installation media | Aero7 Beta 1 ISO |

The target must appear to Linux as `/dev/vd*`. SATA, NVMe, USB, physical host
devices, and already-mounted disks are rejected by the Beta 1 safety gate.

## 4. Boot the ISO

The UEFI menu offers:

- **Aero7 Setup** — normal boot with the graphical splash;
- **Aero7 Setup (debug, no splash)** — visible kernel and service messages;
- **Reboot Into Firmware Interface** — returns to the VM firmware.

Normal setup opens directly. There is no general-purpose live desktop.

## 5. Install

Follow the pages described in [Installer Guide](Installer-Guide.md). The
whole-disk option creates:

1. a GPT partition table;
2. a 1 GiB FAT32 EFI System Partition;
3. an ext4 root partition using the remaining space;
4. a systemd-boot UEFI entry.

The installer downloads official Arch packages and signed Aero7 packages, so
the VM must have internet access.

## 6. Restart and personalize

After the disk phase, the machine restarts from its virtual disk while the ISO
may remain attached. The OOBE pages create your user, password, computer name,
time zone, update choice, and network profile. See
[First Boot and OOBE](First-Boot-and-OOBE.md).

## If something goes wrong

- Boot **Aero7 Setup (debug, no splash)**.
- Press **Alt+F2** for the recovery console and **Alt+F1** to return.
- Read [Troubleshooting](Troubleshooting.md) and
  [Recovery and Logs](Recovery-and-Logs.md).

Do not attach a host drive or important VM disk to a Beta 1 test machine.
