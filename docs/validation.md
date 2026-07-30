# Validation report — Aero7 ISO Beta 1

## Current source-candidate status

The current Beta 1 source candidate passed its non-privileged release checks on
2026-07-30. It includes the disabled Upgrade presentation, confirmed recovery
shell handoff, expanded Linux/open-source notice, package parity and installed
package gates, light desktop defaults, copyright-free login wallpaper, and new
project-owned PNG login/Welcome branding.

The prepared live-install profile is in `work/profile`. A new ISO has **not**
yet been assembled from this profile because that final Archiso step requires
sudo. Therefore no current source-candidate artifact should be published yet.

The older, previously validated artifact is:

`out/aero7-beta1-2026.07.30-x86_64.iso`

- byte size: `1,405,865,984`
- SHA-256: `fbb490c807a3e8302d87962706d62570f0d31a237778bb55d2cc91020aa82aaf`
- ISO label: `AERO7B1_20260730`
- application ID: `AERO7 BETA 1 X86_64 UEFI INSTALLATION MEDIUM`

`scripts/verify-release.sh` passed against this exact file, including the
bootable ISO 9660/GPT/UEFI structure, embedded SquashFS, pinned source lock,
backend guards, and Beta 1 identity. Superseded images are retained only under
`out/archive/` and must not be published.

## Passing checks

- 20 Python disk, package, backend, OOBE, branding, and build-safety tests
- 2 compiled Qt tests: flow-state ordering and complete controller walkthrough
- Python and Bash syntax validation
- QML validation for every component and screen
- Release C++/Qt build with CMake and Ninja
- 28 render-smoke captures at 1024x768, 1366x768, and 1920x1080
- Prepared current live-install Archiso profile with no unresolved placeholders
- exact parity with the pinned shell base/Aero package manifests
- package post-install verification and diagnostic requested-package manifest
- rendered disabled Upgrade, expanded license, and unchanged installer layout
- Exact pinned Aero7-shell source status hash validation
- QEMU runner ignores superseded ISO names unless `--iso PATH` is explicit

ShellCheck remains skipped because it is not installed on the host.

## Previous-artifact installation proof

A fresh 40 GiB project-local QCOW2 disk was installed in a UEFI/KVM/QXL QEMU
VM from the exact final Beta 1 ISO named above. The backend exposed only the
disposable `/dev/vda` device. The test covered language, welcome, licence,
custom installation, disk confirmation, installation, automatic disk-first
reboot, installed-system Plymouth, OOBE, finalization, automatic Welcome and
Preparing Desktop screens, one-time autologin, the Plasma desktop, the
security/logout screen, clean shutdown, and a second installed-disk boot.

Verified results:

- the DVD remained attached, but OVMF booted the installed disk after restart;
- the finalization framebuffer was fully black with no blue side leakage;
- no cursor trails or stale-page fragments appeared;
- no manual Continue button appeared on the OOBE Welcome screen;
- the desktop opened without a second reboot or password prompt;
- the second boot stopped at the password screen, proving the 45-second
  one-time-autologin cleanup had taken effect;
- the security/logout and login screens showed the project-owned
  `Aero7 Professional` watermark with no Windows wording or upstream bitmap;
- `qemu-img check` reported no QCOW2 errors after clean shutdown;
- PlymouthVista itself was not modified.

An earlier candidate exposed an upstream `Windows 7 Ultimate` bitmap on the
Plasma security/logout screen. Beta 1 replaces that QML watermark with the
project-owned `Aero7 Professional` artwork, removes the unused upstream bitmap
and preview screenshots, and sanitizes visible look-and-feel metadata. The
current source candidate upgrades that replacement to a glossy, transparent
350x50 PNG and applies the shell wallpaper to SDDM, the Welcome splash, and the
lock-screen background. These new changes are covered by automated regression
tests but still need the new-ISO VM gate below.

One first-session QXL hotplug event opened Plasma's Display Configuration KCM.
It closed normally, did not return, and was absent from the prior full-flow run;
this is recorded as a non-blocking VM/display-stack quirk rather than an
installer failure. QEMU's host GTK frontend also logged `invalid value for
stride` while switching video modes. A later interactive run reproduced this
as a black host window that repainted only while the pointer moved. The QEMU
runner now defaults to the SDL frontend with OpenGL disabled while retaining
QXL in the guest; `--display gtk` remains available for diagnostics.

## Build-safety findings

An interrupted Archiso run left `/proc` mounted below its work tree. The first
mount guard incorrectly used `findmnt -R` on a path that was not itself a mount
point, allowing SquashFS to start traversing roughly 141 million host pseudo-
filesystem entries. The build was stopped at 1%.

The corrected guard enumerates the mount table, filters exact descendants,
unmounts deepest-first, and refuses to continue if anything remains. A later
build compressed the expected ~63,000 entries. ISO publication is also atomic:
the old ISO is not archived until the staged replacement has completed, and
interrupted staging directories are preserved for diagnosis.

## Remaining final release gate

Run the remaining privileged build step:

```bash
sudo ./scripts/build-iso.sh --mkarchiso-only
./scripts/verify-release.sh
```

Then install that exact new ISO on a fresh disposable disk with
`./scripts/run-qemu.sh --fresh`. Recheck package manifest completion, the light
Dolphin view, SDDM/login logo, automatic Welcome splash, recovery handoff, and
second-boot password behavior. Only after those checks pass is the refreshed
Beta 1 ready for VM-only test distribution.
