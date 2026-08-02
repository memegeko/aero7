# Validation Report — Aero7 Beta 1

## Release artifact

The Beta 1 release candidate was assembled on 2026-08-02:

`out/aero7-beta1-2026.08.02-x86_64.iso`

- byte size: `1,406,070,784`
- SHA-256: `64115bd497315a871d06786160016487eb9e3eb514fc48900c770a8d9fc6feec`
- ISO label: `AERO7B1_20260802`
- application ID: `AERO7 BETA 1 X86_64 UEFI INSTALLATION MEDIUM`

The matching checksum file is
`out/aero7-beta1-2026.08.02-x86_64.iso.sha256`.
The checksum is also recorded in version control at
`docs/checksums/SHA256SUMS`.

## Automated release gate

The current source and release image passed the available unprivileged checks:

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

`scripts/verify-release.sh` passed against the exact artifact above. It checked:

- bootable ISO 9660, GPT, and UEFI structure;
- embedded SquashFS readability;
- normal boot entry with Plymouth arguments;
- Beta 1 identity and absence of the earlier alpha wording;
- guarded live backend and one-time autologin cleanup;
- embedded source lock and focused package manifest;
- one Aero taskbar rather than a second stock Plasma panel;
- Command Prompt branding and application cache rebuild;
- Welcome/SDDM artwork and required Aero assets.

## Interactive VM evidence

A fresh boot of the August 2 artifact in the supported QEMU/KVM, OVMF, QXL,
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

The final August 2 image adds the focused Plasma package regression changes and
passes the automated embedded-image checks. A complete new end-to-end install
was not repeated after that narrow packaging change. Beta testers should report
any full-flow regression and must use a disposable VM.

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

The artifact satisfies the Beta 1 source and embedded-image gates and is ready
for private VM-only prerelease testing. It is not approved for physical disks,
production systems, or public redistribution without the independent artwork
rights review described in `THIRD_PARTY.md`.
The public-release history, mark, security, and fresh-candidate gates are
tracked in `docs/PUBLIC-RELEASE-CHECKLIST.md`.
