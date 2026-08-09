# Public Release Readiness

## Current decision

**Public redistribution is blocked.** The source repository, Wiki, and Beta 1
release must remain private until every blocking review below is cleared and
recorded. This is a release-control decision, not a replacement of the current
Plymouth theme.

The current theme and Git history are intentionally retained. Removing unused
files from the latest tree does not remove copies from earlier commits.

## Blocking reviews

- [x] Record the project owner's decision to use PlymouthVista under its
  distributed MIT license. Frames 56-104 and the final mark are reproducible
  Aero7 project artwork. The exact decision is in
  `docs/release-evidence/2026-08-09-plymouth-license-decision.md`.
- [x] Review the current Aero7 marks and shipping Plymouth frame sequence. The
  release uses the project-owner-supplied standalone 7 identity, and the legacy
  logo backup files have been removed from the public tree.
- [ ] Confirm that the redistribution decision covers the full Git history,
  release attachments, screenshots, Wiki, and ISO—not only the latest tree.
- [ ] During an explicitly approved visibility transition, enable GitHub private
  vulnerability reporting immediately and verify the Security tab report path
  before announcing or linking the public release. GitHub does not expose this
  external reporting setting while the repository is private.
- [x] Rebuild the candidate ISO after all approved release-source changes and
  record its passing image gate.
- [ ] Run `./scripts/check.sh`, `./scripts/verify-release.sh`, and a complete
  `./scripts/run-qemu.sh --fresh` installation plus second boot.
- [x] Update the checksum, file size, validation report, release notes, and Wiki
  so they all identify the exact candidate.
- [ ] Run `./scripts/check-public-release.sh` and require a passing result.
- [ ] Ask the project owner for a final, explicit confirmation before changing
  repository visibility or publishing the release.

## Non-blocking public-project preparation

- [x] Contributor, conduct, support, and security policies are versioned.
- [x] Structured bug and feature templates are versioned.
- [x] Pull-request safety and licensing checklist is versioned.
- [x] Source CI checks the pinned Aero7-shell revision.
- [x] Dependency updates are configured for GitHub Actions.
- [x] Beta 1 checksum is recorded in the repository.
- [x] Unused upstream Plymouth login and product-branding bitmaps were removed
  from the current tree.
- [x] The upstream four-pane reveal was replaced by a reproducible Aero7 glow,
  settle, and breathing loop while preserving the selected Plymouth theme.
- [x] Installer, OOBE, desktop, application, system-menu, lock-screen, and
  authentication screenshots were regenerated from the current source and a
  clean installed VM; superseded screenshots were removed.
- [x] Record the first successful Dell Latitude 3310 installation and
  post-install audit under `docs/release-evidence/`.
- [x] Scan the tracked tree for credentials, local network addresses, signing
  key transfers, generated images, VM disks, and obsolete artwork backups.
- [ ] Repeat the Dell installation with the final release artifact, archive the
  retained installer log, and review the boot journal for the hardware record.

## Approval record

The machine-readable status is in `config/public-release.conf`. Set a review to
`cleared` only after evidence is saved under `docs/release-evidence/` or linked
from a short record there. Do not commit confidential agreements; record the
date, reviewer, scope, and a private document reference instead.

No script changes GitHub visibility or publishes a release automatically.
