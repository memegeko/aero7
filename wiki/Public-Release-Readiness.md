# Public Release Readiness

## Current status

The Plymouth MIT-license decision, current-tree branding review, ISO rebuild,
checksum, and source/image validation are recorded. The remaining release work
is a clean-history decision, private vulnerability reporting, and an exact
fresh-install/second-boot result.

## Required before publishing

- review the Aero7 marks and the full Git history, release files,
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
