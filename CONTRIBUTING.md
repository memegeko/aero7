# Contributing to Aero7

Thanks for helping improve Aero7. Beta 1 is deliberately narrow: an x86-64
UEFI installer for disposable QEMU/KVM virtual machines. Changes should keep
that safety boundary clear and testable.

## Before opening a change

- Search the issue tracker and existing pull requests first.
- Use a dedicated branch and keep each commit focused.
- Do not add passwords, signing keys, tokens, private build logs, or VM images.
- Do not copy proprietary logos, wallpapers, icons, sounds, fonts, screenshots,
  or other artwork into the repository. New assets need a clear source, license,
  and redistribution record in `THIRD_PARTY.md`.
- Never weaken the physical-disk, target-identity, or confirmation guards to
  make a test easier.

## Local checks

Run the unprivileged source gate before opening a pull request:

```bash
./scripts/check.sh
```

If your change affects the built image, also rebuild it and run:

```bash
./scripts/verify-release.sh
./scripts/run-qemu.sh --fresh
```

The complete test sequence is documented in
[`wiki/Testing-and-Release.md`](wiki/Testing-and-Release.md). ISO builds and
fresh-VM tests require an Arch Linux build host and are not expected for a
documentation-only change.

## Pull requests

Explain what changed, why it is safe, what you tested, and whether the change
affects artwork or third-party licensing. Include screenshots for visible UI
changes, but do not attach screenshots containing secrets or personal data.

By submitting a contribution, you confirm that you have the right to license
your contribution under the repository's MIT license and any clearly declared
third-party terms that apply to the files you changed.
