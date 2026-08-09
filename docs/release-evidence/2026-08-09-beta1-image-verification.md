# Beta 1 image verification — 2026-08-09

- File: `aero7-beta1-2026.08.09-x86_64.iso`
- Size: `1,401,708,544` bytes
- SHA-256: `107d044c41f4bba8e8c308e11b7986858ff46a525937e8f0508181d0c9c6c710`
- ISO label: `AERO7B1_20260809`
- Application ID: `AERO7 BETA 1 X86_64 UEFI INSTALLATION MEDIUM`

`scripts/verify-release.sh` completed successfully against this exact image.
The verifier inspected the hybrid ISO/UEFI boot structure, extracted and read
the embedded SquashFS, checked the normal boot entry, and validated the pinned
source lock, package manifest, destructive-operation gates, Aero7 identity,
Plymouth and desktop branding, and installed payload.

The matching checksum is committed in `docs/checksums/SHA256SUMS`. Interactive
fresh-install and second-boot validation remain separate gates.
