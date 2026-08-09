# Disk safety contract

The backend aborts unless every condition below is true at execution time:

1. `--execute` was supplied and the environment contains the exact guard token.
2. The process is root, the kernel command line identifies the Aero7 Archiso,
   the live hostname and pinned source lock are present, and `/` is the Archiso
   overlay. This works with direct-written media and Ventoy GRUB2 mode without
   trusting a copied backend on an installed system.
3. The selected parent resolves to a whole block disk, not a ROM; an advanced
   target must resolve to an exact child partition or exact unallocated range.
4. It is writable, non-removable, unmounted, and is not the live ISO source.
5. No child partition is mounted.
6. Device path, kernel name, byte size, model, serial, and major/minor number
   still match the confirmation-time fingerprint.
7. The confirmation path is byte-for-byte identical to the plan's device path.
8. The disk is at least 16 GiB and an advanced target can hold a 1 GiB Aero7
   ESP plus at least 16 GiB of root space.
9. An advanced target is on GPT, its disk/partition UUID and sector geometry
   are unchanged, and it is not an existing EFI System Partition.
10. Network, required tools, and a restorable `sfdisk --dump` backup succeed
    before any advanced disk change begins.

The implementation uses argument arrays rather than shell interpolation. Its
partition plans are generated centrally. The guided advanced path can consume
an exact unallocated range, replace one explicitly selected partition, or
shrink NTFS after `ntfsresize --check` and a no-action trial. The filesystem is
shrunk before its GPT boundary moves. Tests exercise rejection of mounted,
removable, read-only, changed, undersized, live-media, unsupported-path,
non-GPT, ESP, stale-gap, and stale-partition targets. Physical execution is
enabled for guarded development candidates while disposable-hardware evidence
is collected.

The installed-system desktop adapter has a separate first-boot gate. It runs
only as root, requires the exact `AERO7_IMAGE_MODE_GUARD` token and a ready
`/var/lib/aero7/install-source` marker, and accepts only an existing
unprivileged local account with a home directory. Package download/build stages
are skipped at first boot because their payloads were completed during the disk
phase. Plymouth is also skipped there so the ISO-pinned theme is preserved.
