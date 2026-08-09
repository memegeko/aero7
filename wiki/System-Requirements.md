# System Requirements

## Beta 1

| Requirement | Supported configuration |
| --- | --- |
| CPU architecture | x86-64 |
| Firmware | UEFI; Secure Boot disabled for the unsigned test image |
| Environment | x86-64 UEFI PC or QEMU/KVM virtual machine |
| RAM | 4 GiB minimum; 8 GiB recommended |
| CPU allocation | Two cores minimum; four recommended |
| Target disk | Writable, non-removable SATA, NVMe, MMC, or VirtIO disk |
| Disk size | 16 GiB minimum; 40 GiB recommended |
| Display | Intel/AMD graphics on hardware; QXL/SPICE in QEMU |
| Network | Required during installation |
| Desktop session | KDE Plasma 6 Wayland |

Physical installation requires Secure Boot to be disabled and the storage
controller to expose the disk to Linux. On systems offering RAID On/Intel RST
or AHCI, use AHCI after safely preparing any existing operating system.

## Not supported

- legacy BIOS/CSM boot;
- RAID On/Intel RST storage that is hidden from Linux; use AHCI after safely
  preparing any existing operating system;
- removable USB storage as an installation target;
- treating guided preservation as a substitute for a verified backup;
- full-disk encryption;
- full free-form manual partitioning;
- offline package installation;
- Plasma X11 sessions.

The installer accepts only explicit Linux disk paths (`/dev/vd*`, `/dev/sd*`,
`/dev/nvme*n*`, or `/dev/mmcblk*`) that pass its live-media, mount, size,
read-only, removable, and fingerprint checks. That does not make unbacked data
safe from user selection errors or power loss.

## Display recommendation

Use QXL with a SPICE viewer. The project launcher disables image compression and
uses a VirtIO tablet, avoiding the stale frame and mouse-click problems seen
with some QEMU SDL/GTK and virtual-GPU combinations.
