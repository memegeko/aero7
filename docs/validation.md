# Validation Report — Aero7 Beta 1

## Published private Beta 1 artifact

The prerelease published on GitHub was assembled on 2026-08-02:

`aero7-beta1-2026.08.02-x86_64.iso`

- byte size: `1,406,070,784`
- SHA-256: `64115bd497315a871d06786160016487eb9e3eb514fc48900c770a8d9fc6feec`
- ISO label: `AERO7B1_20260802`
- application ID: `AERO7 BETA 1 X86_64 UEFI INSTALLATION MEDIUM`

The matching checksum remains recorded in `docs/checksums/SHA256SUMS`.

## Current local validation candidate

The image used for the first successful real-hardware installation is:

- file: `out/aero7-beta1-2026.08.09-x86_64.iso`;
- byte size: `1,401,708,544`;
- SHA-256: `cea0f8db6957852169031792ce77315bdf0599795126d78c5c5bd9777bd7976c`;
- ISO label: `AERO7B1_20260809`;
- installer source at build: `35654eda848c023e879f6054858c2e822f5e05a0`.

It has not replaced the published August 2 asset. Because Aero7-shell advanced
from the embedded commit `a73f454` to `d2dbfad`, the August 9 image now stops
the current `verify-release.sh` gate at the intentional source-lock comparison.
A new ISO build and full gate are required after documentation and hardware
feedback are finalized.

## Automated release gate

The current source passed the available unprivileged checks:

- Python disk, package, backend, OOBE, branding, and build-safety tests;
- compiled Qt flow-state and complete-controller walkthrough tests;
- Python and Bash syntax validation;
- QML validation for every component and screen;
- Release C++/Qt build with CMake and Ninja;
- render-smoke captures at 1024×768, 1366×768, and 1920×1080;
- exact parity with the pinned shell base, Aero, and companion manifests;
- focused `plasma-desktop` payload with the broad Plasma/KDE application
  meta-packages excluded;
- embedded taskbar repair, Start-menu cache refresh, light defaults, application
  renaming, and login branding checks;
- exact pinned Aero7-shell origin, commit, and source-status digest validation;
- QEMU UEFI boot order, SPICE/QXL display, and VirtIO tablet input checks.

ShellCheck is skipped when it is not installed on the host.

## ISO inspection

The published release passed `scripts/verify-release.sh` at release time. The
gate checked:

- bootable ISO 9660, GPT, and UEFI structure;
- embedded SquashFS readability;
- normal boot entry with Plymouth arguments;
- Beta 1 identity and absence of the earlier alpha wording;
- guarded live backend and one-time autologin cleanup;
- embedded source lock and focused package manifest;
- one Aero taskbar rather than a second stock Plasma panel;
- Command Prompt, Media Player, Snipping Tool, Calculator, and Notepad branding,
  capture shortcuts, and application cache rebuild;
- Welcome/SDDM artwork and required Aero assets.

## Documentation capture and interactive VM evidence

Every installer and OOBE page was regenerated from the current Qt/QML source
with the non-destructive documentation capture mode. A clean install of the
August 8 ISO then completed OOBE and first-login repair before the desktop,
Start menu, application, lock-screen, system-menu, and authentication captures
were taken. Superseded screenshots were removed from the repository rather
than retained under alternate names.

A fresh boot of the August 8 artifact in the supported QEMU/KVM, OVMF, QXL,
SPICE, and VirtIO-tablet configuration reached the clean 1024×768 graphical
language screen. Input and rendering were responsive in this smoke run.

The immediately preceding Beta candidate completed a full fresh 40 GiB QCOW2
installation. That test covered language, welcome, license, custom install,
disk confirmation, installation, disk-first restart, installed-system Plymouth,
OOBE, finalization, Welcome, Preparing your desktop, one-time autologin, Plasma,
security/logout, clean shutdown, and a second installed-disk boot.

Verified full-flow results included:

- the DVD remained attached while OVMF selected the installed disk;
- finalization covered the whole framebuffer with no blue side leakage;
- no cursor trails, stale-page fragments, or manual Continue button appeared;
- the first desktop opened without a second reboot or password prompt;
- the second boot required the created password, proving cleanup succeeded;
- login and logout used project-owned Aero7 branding;
- `qemu-img check` found no QCOW2 errors after clean shutdown;
- PlymouthVista itself was not modified.

The August 9 candidate also completed a destructive whole-disk installation on
a Dell Latitude 3310 and reached a working Plasma desktop with zero failed
systemd units. The post-install audit is recorded under
`docs/release-evidence/2026-08-09-dell-latitude-3310.md`. Formal hardware
support remains pending because that candidate did not retain its live
installer log after reboot and its boot journal exposed non-fatal AeroShell
widget warnings. A rebuilt candidate and repeat hardware test are required.

## Recorded VM quirks

- a first-session virtual-display hotplug can briefly open Plasma Display
  Configuration; it closed normally and did not recur in prior full runs;
- QEMU's GTK frontend can show a black host window that repaints only on pointer
  movement; the launcher therefore defaults to SPICE/QXL;
- legacy VGA/input combinations can cause cursor trails, stale page fragments,
  or dropped clicks; the launcher uses QXL and a VirtIO tablet.

These are documented in the wiki and are not treated as guest installer
failures when the supported launcher configuration works.

## Build safety

The Archiso pipeline stages output atomically and does not archive the previous
image until a replacement is complete. Before SquashFS starts, it enumerates
and unmounts exact descendants of the work tree, deepest-first, and refuses to
continue if a mount remains. This prevents accidental traversal of host
pseudo-filesystems after an interrupted build.

## Release assessment

The August 9 candidate completes the tested VM flow and a first Dell hardware
flow, but it predates the measured package-progress, retained-log, Aero7 OS
identity, and lock-screen fixes. The published August 2 asset remains a private
VM-only prerelease. No artifact is approved for physical disks, production
systems, or public redistribution without a fresh build, complete release
gate, repeat retained-log hardware review, and the independent artwork rights
review described in `THIRD_PARTY.md`.
The public-release history, mark, security, and fresh-candidate gates are
tracked in `docs/PUBLIC-RELEASE-CHECKLIST.md`.
