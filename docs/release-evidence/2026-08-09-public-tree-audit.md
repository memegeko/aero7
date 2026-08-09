# Public-tree and current-branding audit — 2026-08-09

## Public-tree result

The tracked `beta` tree was checked for local absolute paths, private network
addresses, the temporary test password used during development, GitHub tokens,
private-key material, signing-key transfer filenames, generated ISO/VM images,
logs, and common editor backup files. No credential or private signing material
was found in the current tracked tree.

Three unused rollback images under
`installer/assets/legacy-logo-backups/` were removed. `.gitignore` now excludes
future artwork backups, local release artifacts, secrets directories, signing
key transfers, environment files, private key formats, partial downloads, and
editor/OS temporary files in addition to the existing build, Archiso work, ISO,
VM disk, firmware, cache, and log rules.

## Current-branding result

The complete shipping Plymouth frame set was sampled from the beginning,
light-orb convergence, Aero7 reveal, settle, and final loop. Frames 56-104 show
the standalone Aero7 7 emblem. The current tree contains no legacy product
logo, `base.png`, `branding_*.png`, or `authui_*.png` file. Product branding in
the installer, SDDM, Welcome, lock/logout UI, desktop, and Plymouth uses the
project-owner-supplied Aero7 identity.

The advertised `beta` branch and Beta 1 tag history were subsequently rewritten
to remove the obsolete artwork paths while preserving all 82 existing
development commits and the exact release tree.
