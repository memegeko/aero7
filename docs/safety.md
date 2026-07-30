# Disk safety contract

The backend aborts unless every condition below is true at execution time:

1. `--execute` was supplied and the environment contains the exact guard token.
2. The process is root and DMI identifies a supported virtual machine.
3. The selected path resolves to a whole block disk, not a partition or ROM.
4. It is writable, non-removable, unmounted, and is not the live ISO source.
5. No child partition is mounted.
6. Device path, kernel name, byte size, model, serial, and major/minor number
   still match the confirmation-time fingerprint.
7. The confirmation path is byte-for-byte identical to the plan's device path.
8. The disk is at least 16 GiB.

The implementation uses argument arrays rather than shell interpolation. Its
partition plan is fixed and generated centrally. Tests exercise rejection of
mounted, removable, read-only, changed, undersized, and live-media devices.

The installed-system desktop adapter has a separate first-boot gate. It runs
only as root, requires the exact `AERO7_IMAGE_MODE_GUARD` token and a ready
`/var/lib/aero7/install-source` marker, and accepts only an existing
unprivileged local account with a home directory. Package download/build stages
are skipped at first boot because their payloads were completed during the disk
phase. Plymouth is also skipped there so the ISO-pinned theme is preserved.
