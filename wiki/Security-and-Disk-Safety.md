# Security and Disk Safety

The Beta 1 backend is intentionally narrow. It aborts unless every safety
condition is true at execution time.

## Required conditions

1. Live installation was enabled when the ISO profile was prepared.
2. The backend is root and receives the exact destructive-operation guard token.
3. DMI identifies a supported virtual machine.
4. The selected path is a whole VirtIO disk, not a partition or optical device.
5. The disk is writable, non-removable, unmounted, and at least 16 GiB.
6. No child partition is mounted.
7. The disk is not the live-media source.
8. Path, kernel name, byte size, model, serial, major/minor number, read-only
   state, and removable state still match the confirmation-time fingerprint.
9. The final confirmation path exactly matches the planned device.

Any mismatch cancels installation before `wipefs` or partitioning begins.

## Fixed partition plan

The backend creates only:

- GPT;
- partition 1: 1 GiB FAT32 EFI System Partition;
- partition 2: ext4 root using the remainder;
- systemd-boot in the ESP.

There is no free-form shell command construction. Commands use argument arrays,
and the partition table comes from one tested function.

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

Beta software can contain defects. VM gating reduces the consequence of a disk
bug but does not make data recovery possible. Use a newly created disposable VM
disk and never attach host storage or important images.
