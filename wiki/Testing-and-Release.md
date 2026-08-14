# Testing and Release

## Current publication status

The existing Beta 1 image remains available. New ISO and package artifacts are
not published during the final bug-testing period. Source commits and automated
checks continue normally; publication resumes only after the final release is
explicitly approved.

Beta releases use four gates: source validation, image validation, a fresh
installation, and a second installed-system boot.

## Source gate

Run:

```bash
./scripts/check.sh
```

Required results include passing backend/state-machine tests, successful QML
linting, a Release CMake/Ninja build, render-smoke captures at supported design
sizes, source-lock verification, and exact package-manifest parity.

## Image gate

Run:

```bash
./scripts/verify-release.sh
sha256sum out/aero7-beta1-*.iso
```

There must be exactly one current Beta 1 ISO in `out/`. The verifier inspects
both the boot medium and its embedded live filesystem.

## Fresh-VM gate

Launch a clean disk:

```bash
./scripts/run-qemu.sh --fresh
```

Walk through language, Install now, license, custom installation, disk
confirmation, installation, restart, account, password, update, time, network,
finalization, Welcome, Preparing your desktop, and the first Plasma session.

Confirm all of the following:

- only the disposable `/dev/vda` target is offered;
- progress and restart complete without visible rendering corruption;
- the installed disk wins boot order while the DVD remains attached;
- Plymouth, OOBE, SDDM, and Plasma carry matching Aero7 branding;
- there is one Aero taskbar, a light color scheme, populated All Programs, and
  the expected application names;
- the first desktop login is automatic;
- a clean shutdown leaves the QCOW2 image healthy.

## Disk Management fixture

To test the installed Computer Management disk view without attaching host
storage, boot the existing Aero7 VM with three disposable secondary drives:

```bash
./scripts/run-qemu.sh --installed --disk-management-fixture
```

The launcher preserves the installed Aero7 system disk and adds:

- an entirely blank 8 GiB disk;
- a 24 GiB GPT disk containing 6 GiB `PROJECTS` and 4 GiB `BACKUPS`
  partitions followed by unallocated space;
- a 64 GiB GPT disk containing a 48 GiB `ARCHIVE` partition followed by
  unallocated space.

Use these disks to check rescan, volume enumeration, proportional partition
blocks, filesystem labels, properties, mount/unmount, and unallocated-space
rendering. The fixture files live under `work/qemu/disk-management-fixture/`
and are intentionally excluded from Git.

## Second-boot gate

Boot the same VM disk again. OOBE must remain disabled and SDDM must require the
created account password, proving that temporary first-login autologin was
removed.

## Beta 1 artifact

- file: `aero7-beta1-2026.08.09-x86_64.iso`
- size: `1,401,708,544` bytes
- SHA-256: `107d044c41f4bba8e8c308e11b7986858ff46a525937e8f0508181d0c9c6c710`
- release tag: `v0.1.0-beta.1`

The repository's `docs/validation.md` is the detailed automated, VM, and
real-hardware test record for this release line.
