# Building the ISO

This page is for developers and advanced testers. Most people should download
the signed Beta 1 artifact from [Installation](Installation.md) instead of
rebuilding it.

## Build host

Use an up-to-date Arch Linux host with:

- `archiso`, `base-devel`, Git, CMake, Ninja, Qt 6 development tools, and QML
  linting tools;
- `xorriso`, `squashfs-tools`, ImageMagick, QEMU, OVMF, and SPICE tooling;
- enough free space for the Archiso work tree and output image;
- a clean, pinned Aero7-shell checkout at the path recorded in `sources.lock`.

The build reads Aero7-shell as a source payload. It verifies the checkout's
origin, exact commit, and working-tree digest before copying a runtime-only
subset. It does not run the shell installer against the build host.

## 1. Validate the source tree

```bash
./scripts/check.sh
```

This runs Python tests, Qt controller tests, QML linting, syntax checks, package
parity checks, source-lock validation, and visual smoke tests. ShellCheck is run
when it is available.

## 2. Prepare and build

```bash
sudo ./scripts/build-iso.sh
```

The script prepares the live profile, compiles the installer, imports the
pinned runtime payload, and invokes Archiso. If preparation already completed
and only the privileged Archiso phase remains, use:

```bash
sudo ./scripts/build-iso.sh --mkarchiso-only
```

The build script publishes atomically: it stages a complete ISO before moving
it into `out/`. It also refuses to build while mounts remain below its work
tree, preventing SquashFS from traversing host pseudo-filesystems.

## 3. Verify the artifact

```bash
./scripts/verify-release.sh
```

Verification checks the ISO 9660/GPT/UEFI structure, embedded SquashFS, boot
entry, Beta identity, source lock, disk guards, focused Plasma package list,
Aero taskbar layout, application branding, and login artwork.

## 4. Test in a disposable VM

```bash
./scripts/run-qemu.sh --fresh
```

`--fresh` creates a new disposable VM disk; it does not rebuild the ISO. Use
`--iso /absolute/path/image.iso` to test a non-current artifact. See
[Testing and Release](Testing-and-Release.md) for the complete release gate.

## Output safety

- Never point a development launcher at a host block device.
- Never weaken the VirtIO, VM, fingerprint, or live-media checks for
  convenience.
- Never publish an ISO unless its checksum was generated from the exact file
  that passed verification and the fresh-VM gate.
- Review [Credits and Licensing](Credits-and-Licensing.md) before redistributing
  any derivative image.
