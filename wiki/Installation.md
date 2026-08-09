# Installation

The published Beta 1 ISO is designed for a **disposable QEMU/KVM virtual
machine**. A freshly built development candidate also permits guarded
installation on explicitly disposable x86-64 UEFI hardware. Back up every disk
connected to the machine and disconnect unrelated drives before testing.

## 1. Download

Open the [Aero7 Beta 1 release](https://github.com/memegeko/aero7/releases/tag/v0.1.0-beta.1)
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

The development candidate accepts writable, non-removable `/dev/vd*`,
`/dev/sd*`, `/dev/nvme*n*`, and `/dev/mmcblk*` whole disks. Mounted, read-only,
removable, undersized, live-media, and unsupported device paths are rejected.

### Physical test machine

- use x86-64 UEFI with Secure Boot disabled;
- configure the storage controller as AHCI, not Disabled or RAID On/Intel RST;
- write the ISO directly to USB; Ventoy GRUB2 mode may work but is not the
  release-validation path;
- use wired networking when possible because packages are downloaded during
  setup;
- attach only the disposable target disk for the first hardware test.

Changing RAID On to AHCI can make an existing operating system unbootable.
Prepare that operating system first or use a disk that contains nothing you
need. Whole-disk installation erases the selected disk completely.

## 4. Boot the ISO

The UEFI menu offers:

- **Aero7 Setup** — normal boot with the graphical splash;
- **Aero7 Setup (debug, no splash)** — visible kernel and service messages;
- **Reboot Into Firmware Interface** — returns to the VM firmware.

Normal setup opens directly. There is no general-purpose live desktop.

![Installer language screen](images/installer-01-language.png)

## 5. Install

Follow the pages described in [Installer Guide](Installer-Guide.md). The
erase-disk option creates:

1. a GPT partition table;
2. a 1 GiB FAT32 EFI System Partition;
3. an ext4 root partition using the remaining space;
4. a systemd-boot UEFI entry.

The installer downloads official Arch packages and signed Aero7 packages, so
the VM must have internet access.

![Installation progress](images/installer-09-progress.png)

### Guided advanced drive options

Select **Drive options (advanced)** to show existing partitions and unallocated
regions. The current development build supports:

- **New** on at least 17 GiB of unallocated space, preserving existing
  partitions;
- **Format** on one selected partition of at least 17 GiB, erasing only that
  partition and replacing its region with an Aero7 ESP and root;
- **Shrink** on NTFS, leaving at least 16 GiB for the existing filesystem and
  releasing at least 17 GiB for Aero7.

![Guided advanced drive options](images/installer-07-disk-advanced.png)

Delete and Extend remain disabled. Before shrinking, back up the drive, disable
Windows Fast Startup, and fully shut Windows down. The installer checks NTFS,
runs a no-action resize trial, saves the GPT table, shrinks the filesystem
before its partition boundary, and revalidates exact sector geometry.

Developers can create the non-bootable synthetic preservation fixture with
`./scripts/run-qemu.sh --fresh --dualboot-fixture`. It contains an existing EFI
partition, a placeholder Windows data partition, and unallocated space; it is
for testing preservation and installation, not for testing Windows itself.

## 6. Restart and personalize

After the disk phase, the machine restarts from its installed disk. Remove the
USB if the firmware selects it again. The OOBE pages create your user, password, computer name,
time zone, update choice, and network profile. See
[First Boot and OOBE](First-Boot-and-OOBE.md).

## If something goes wrong

- Boot **Aero7 Setup (debug, no splash)**.
- Press **Alt+F2** for the recovery console and **Alt+F1** to return.
- Read [Troubleshooting](Troubleshooting.md) and
  [Recovery and Logs](Recovery-and-Logs.md).

Do not attach an important host, physical, or VM disk to a development test.
