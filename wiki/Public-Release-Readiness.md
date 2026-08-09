# Public Release Readiness

## Current status

**Blocked for public redistribution.** Beta 1 remains a private test release.
The current Plymouth theme and repository history are intentionally
retained; no public release is approved merely because source or ISO tests pass.

## Required before publishing

- obtain and record a valid basis to redistribute the retained PlymouthVista
  animation frames;
- review the four-pane Aero7 marks and the full Git history, release files,
  screenshots, and Wiki for artwork and trademark risk;
- during an explicitly approved visibility transition, enable and test GitHub
  private vulnerability reporting before announcing the public release;
- rebuild the exact candidate ISO;
- pass source checks, embedded-image verification, a fresh full installation,
  and a second installed-system boot;
- update the checksum, size, release notes, validation report, and Wiki;
- receive a final explicit approval from the project owner before changing
  visibility or publishing the release.

The machine-readable gate is `config/public-release.conf` and is checked with
`./scripts/check-public-release.sh`. The repository's
`docs/PUBLIC-RELEASE-CHECKLIST.md` contains the authoritative detailed list and
approval-record rules.
