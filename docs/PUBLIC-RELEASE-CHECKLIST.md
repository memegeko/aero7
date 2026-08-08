# Public Release Readiness

## Current decision

**Public redistribution is blocked.** The source repository, Wiki, and Beta 1
release must remain private until every blocking review below is cleared and
recorded. This is a release-control decision, not a replacement of the current
Plymouth theme.

The current theme and Git history are intentionally retained. Removing unused
files from the latest tree does not remove copies from earlier commits.

## Blocking reviews

- [ ] Obtain written permission or another documented legal basis to publicly
  redistribute the retained PlymouthVista light-orb frames 0-55, or replace
  them with project-owned artwork. Frames 56-104 and the final mark are now
  reproducible Aero7 project artwork, but the upstream notice still applies to
  the retained opening frames.
- [ ] Review the current four-pane Aero7 marks for trademark and confusingly
  similar design risk. The temporary blue “A” mark is not used.
- [ ] Confirm that the redistribution decision covers the full Git history,
  release attachments, screenshots, Wiki, and ISO—not only the latest tree.
- [ ] During an explicitly approved visibility transition, enable GitHub private
  vulnerability reporting immediately and verify the Security tab report path
  before announcing or linking the public release. GitHub does not expose this
  external reporting setting while the repository is private.
- [ ] Rebuild the candidate ISO after all approved release-source changes.
- [ ] Run `./scripts/check.sh`, `./scripts/verify-release.sh`, and a complete
  `./scripts/run-qemu.sh --fresh` installation plus second boot.
- [ ] Update the checksum, file size, validation report, release notes, and Wiki
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
- [ ] Review and archive the current real-hardware test logs and explicitly
  record the result before describing physical hardware as supported.

## Approval record

The machine-readable status is in `config/public-release.conf`. Set a review to
`cleared` only after evidence is saved under `docs/release-evidence/` or linked
from a short record there. Do not commit confidential agreements; record the
date, reviewer, scope, and a private document reference instead.

No script changes GitHub visibility or publishes a release automatically.
