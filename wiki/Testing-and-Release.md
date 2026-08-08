# Testing and Release

Beta releases use four gates: source validation, image validation, a fresh
installation, and a second installed-system boot.

Public distribution has a fifth gate: artwork, mark, history, and security
review. The machine-readable gate is intentionally blocked until those reviews
are recorded. Run it with:

```bash
./scripts/check-public-release.sh
```

A passing source or image test does not override a blocked public-release gate.
The repository version of `docs/PUBLIC-RELEASE-CHECKLIST.md` is authoritative.

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

## Second-boot gate

Boot the same VM disk again. OOBE must remain disabled and SDDM must require the
created account password, proving that temporary first-login autologin was
removed.

## Published private Beta 1 artifact

- file: `aero7-beta1-2026.08.02-x86_64.iso`
- size: `1,406,070,784` bytes
- SHA-256: `64115bd497315a871d06786160016487eb9e3eb514fc48900c770a8d9fc6feec`
- release tag: `v0.1.0-beta.1`

The repository's `docs/validation.md` is the detailed test record for this
release and the newer August 8 candidate. The August 8 image has not replaced
the published asset; real-hardware validation remains pending until its logs
are reviewed and archived.
