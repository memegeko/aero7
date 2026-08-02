# System Requirements

## Supported in Beta 1

| Requirement | Supported configuration |
| --- | --- |
| CPU architecture | x86-64 with virtualization support |
| Firmware | UEFI through OVMF |
| Hypervisor | QEMU/KVM |
| RAM | 4 GiB minimum; 8 GiB recommended |
| CPU allocation | 2 minimum; 4 recommended |
| Target disk | Disposable VirtIO disk (`/dev/vd*`) |
| Disk size | 16 GiB minimum; 40 GiB recommended |
| Display | QXL/SPICE recommended |
| Network | Required during installation |
| Desktop session | KDE Plasma 6 Wayland |

## Not supported in Beta 1

- physical hardware installation;
- legacy BIOS/CSM boot;
- SATA, NVMe, USB, or host block devices as install targets;
- dual boot or installing alongside another operating system;
- full-disk encryption;
- manual partitioning;
- preserving data or existing partitions;
- offline package installation;
- Plasma X11 sessions.

These limits are deliberate. Beta 1 exercises the complete operating-system
flow while keeping destructive testing constrained to an identifiable virtual
machine and disposable disk.

## Display recommendation

Use QXL with a SPICE viewer. The project launcher disables image compression and
uses a VirtIO tablet, avoiding the stale frame and mouse-click problems seen
with some QEMU SDL/GTK and virtual-GPU combinations.
