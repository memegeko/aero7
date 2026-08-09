# Security and Disk Safety

The Beta 1 backend is intentionally narrow. It aborts unless every safety
condition is true at execution time.

## Required conditions

1. Live installation was enabled when the ISO profile was prepared.
2. The backend is root and receives the exact destructive-operation guard token.
3. The kernel command line, live hostname, pinned source lock, and overlay root
   prove that the backend is running from booted Aero7 installation media
   rather than an installed system. This also supports Ventoy GRUB2 mode, where
   `/run/archiso/bootmnt` is not always a conventional mount point.
4. The selected parent is a supported whole SATA, NVMe, MMC, or VirtIO disk,
   not an optical or removable device; an
   advanced choice must match an exact child partition or free-sector range.
5. The disk is writable, non-removable, unmounted, and at least 16 GiB.
6. No child partition is mounted.
7. The disk is not the live-media source.
8. Path, kernel name, byte size, model, serial, major/minor number, read-only
   state, and removable state still match the confirmation-time fingerprint.
9. The final confirmation path exactly matches the planned device.
10. Advanced mode requires GPT, rejects the existing ESP, rechecks partition
    UUIDs and sector geometry, and saves a private `sfdisk --dump` backup.
11. Network and every required storage tool are available before disk changes.

Any mismatch cancels installation before `wipefs` or partitioning begins.

## Fixed partition plans

The backend creates only:

- GPT;
- partition 1: 1 GiB FAT32 EFI System Partition;
- partition 2: ext4 root using the remainder;
- systemd-boot in the ESP.

There is no free-form shell command construction. Commands use argument arrays,
and the partition table comes from one tested function.

Advanced mode also uses fixed plans. It can append Aero7 to an exact free
range, replace one explicitly selected partition region, or shrink NTFS into a
smaller unchanged-start partition and use the released tail. NTFS check and
no-action phases run before the real filesystem resize; the partition boundary
moves only after that succeeds. Existing EFI and unrelated partitions are not
formatted. A successful install copies the pre-change table backup into
`/var/log/aero7-partition-table-before.sfdisk` on the installed system.

## Package trust

Official packages come from configured Arch mirrors. Aero7 packages require a
dedicated key, signed repository database, and signed package payloads. Setup
does not silently fall back to unverified AUR compilation.

## First-boot privilege

OOBE runs only once, disables itself, and hands normal operation to SDDM. The
image-mode adapter validates the account and installation provenance. Its
temporary first-login autologin removes itself automatically and does not weaken
sudo policy.

## What this does not guarantee

Beta software can contain defects. VM gating and a table backup reduce the
consequence of a disk bug but cannot recover filesystem data. Use a newly
created disposable VM disk and never attach host storage or important images.
