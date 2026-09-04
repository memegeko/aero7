# Aero7 Beta 2 release candidate notes

## Publication status

The Beta 2 source, package definitions, documentation, and wiki content are
prepared for public review. The online and offline ISO files are deliberately
not part of this source publication. Beta 1 remains the current downloadable
release until both Beta 2 images complete the remaining installation and
graphical acceptance gates.

## Planned media

Beta 2 is prepared as two installation images built from the same guarded
installer and pinned package set:

- **Offline ISO — recommended.** Embeds the complete package dependency closure
  and a checksum-pinned local pacman repository. It installs without internet
  and avoids mirror/download delays on slower hardware.
- **Online ISO.** Smaller download that retrieves the current Arch and Aero7
  packages during installation. It requires a stable internet connection for
  the complete package phase.

Both variants retain the normal signed repositories for updates after setup.

## Desktop and application changes

- Ships the dedicated Aero7 Desktop Wayland session, with AeroThemePlasma
  available as a fallback session.
- Applies the factory taskbar layout and a clean desktop containing only the
  Recycle Bin on a fresh account.
- Keeps the corrected Aero7 Professional branding on SDDM and the Plasma lock
  screen, including session selection and login accessibility controls.
- Uses Windows-style `Meta+Shift+S` rectangular screenshots: selection closes,
  the PNG is saved, image data is copied to the clipboard, and the notification
  opens the saved file.
- Removes user-facing desktop edit mode and aligns taskbar, Start, desktop, and
  context-menu behavior with the Aero7 shell contract.
- Embeds approved AeroThemePlasma icon-pack resources in Aero7 applications so
  their identity does not change with the global icon theme.
- Updates File Explorer naming, icon, Wayland identity, taskbar pinning, Recycle
  Bin settings, Libraries, Computer, common dialogs, and Linux-mount filtering.
- Includes the 45-item Control Panel layout and Linux-backed Screen Resolution,
  networking, power, sound, users, updates, programs, and administration pages.
- Renames the maintained device application and package to
  `aero7-device-manager`, while preserving `linux-devmgmt` compatibility for
  upgrades.

## Optional features

**Turn Aero7 features on or off** is searchable from Start and available from
Control Panel's Programs category and Programs and Features page. It reports
real package/service state and supports install, remove, repair, verification,
retained-data explanations, and audited Polkit authorization.

Programs Center Beta is optional and absent on a fresh installation. Both media
variants retain its checksum-verified package locally, allowing it to be
enabled, removed, and enabled again without internet. Other optional features
and their backends are documented in the
[Optional Features guide](../wiki/Optional-Features.md).

## Installer and diagnostic changes

- Adds strict local-package manifests and dependency-closure validation.
- Adds a complete offline package repository preparation path.
- Improves online package failure reporting and safely stops without leaving a
  partially configured target.
- Creates `Aero7 Physical Install Logs` on the installed user's desktop with
  installer, boot, hardware, package, service, display-manager, and session
  diagnostics plus a SHA-256 manifest and privacy notice.
- Keeps passwords, network connection profiles, personal documents, browser
  data, and full core-memory images out of the collected folder.

## Candidate component versions

| Component | Candidate package |
| --- | --- |
| Aero7 Desktop | `0.2.0-26` |
| Aero7 File Explorer | `25.12.3-33` |
| Aero7 Control Panel | `0.1.0-38` |
| Aero7 Device Manager | `2.2.1.r1.g6d080f8-1` |
| Aero7 Computer Management | `0.2.0.r20.g6d7fe79-1` |
| Aero7 Gadgets | `3.0.0-3` |
| Aero7 Internet Explorer compatibility | `0.1.0-5` |
| AeroThemePlasma Desktop | `6.7.0_742.r9c2d850-38` |
| Programs Center Beta | `0.1.0.r12.g0405a2e-1`, optional |

## Release gates

Source checks, package-manifest checks, optional-feature helper tests, and
installer unit tests are required before the source push. The following remain
release blockers for the ISO files:

- fresh installation from the final online image;
- fresh installation from the final offline image with networking unavailable;
- reboot, OOBE, SDDM, lock-screen, and second-login verification;
- taskbar, Start, File Explorer, Control Panel, screenshot, optional-feature,
  multi-monitor, and recovery-path acceptance;
- final image verification, sizes, SHA-256 checksums, and release-page upload.

No Beta 2 ISO should be announced as available until these checks are recorded.

The signed package builder must produce and validate these exact recipe versions
before the final online and offline ISO manifests are refreshed. Older packages
in a developer's local test cache are not release artifacts.
