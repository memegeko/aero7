# Third-party and artwork notice

- Arch Linux packages are downloaded from the configured official repositories
  and retain their respective licenses.
- Qt, KDE Plasma, Cage, systemd, the Linux kernel, and all other installed
  packages retain their upstream licenses and notices under `/usr/share/licenses`.
- Aero7 binary packages are consumed from the signed repository pinned in
  `sources.lock` and retain their upstream licenses.
- `installer/assets/aero7-background.png` is original project artwork generated
  with OpenAI's built-in image-generation tool on 2026-07-29. Prompt: an
  original abstract cobalt-to-cyan Aero7 installer background with sweeping
  light trails and bokeh; no text, logos, flags, Windows marks, Microsoft
  wallpaper motifs, recognizable flowers or birds, UI panels, or watermark.
- `installer/assets/aero7-logo-plain.png` and
  `installer/assets/aero7-logo-circle.png` are UI-sized transparent variants of
  the two AI-generated Aero7 emblems supplied by the project owner on
  2026-08-03. OpenAI's built-in image editor was instructed to preserve each
  emblem exactly while replacing only its background with a flat chroma color;
  that background was then removed and the result mechanically centered and
  downscaled. They are used by the installer and installed desktop branding.
  The older `aero7-logo-*.png` files under
  `third_party/PlymouthVista/images/` remain part of the separately requested
  Plymouth theme and were deliberately not replaced.
- `installer/assets/aero7-sddm-branding.png` is a mechanical 350x50 composition
  of the project-owner-supplied standalone 7 emblem with Aero7 text rendered in the
  bundled OFL-licensed Adwaita Sans font. It replaces the upstream SDDM and
  Plasma Welcome/logout product watermark.
- The Plymouth boot animation is based on
  [`furkrn/PlymouthVista`](https://github.com/furkrn/PlymouthVista) revision
  `e2b9605a7b4d649bb0e314cce8bbe9912633cfef`. Its software is MIT-licensed;
  its upstream README states that the bundled visual resources belong to
  Microsoft Corporation. The original license and upstream notice are retained
  under `third_party/PlymouthVista/`.
- The shipped Plymouth boot script retains the requested upstream `flag*.png`
  animation frames. Unused upstream `branding_*.png` and `authui_*.png` files
  were removed from the current tree and are not installed; its existing
  shutdown/update branding and animation artwork are intentionally preserved.
  Earlier commits still contain the removed files.
- The installer frame, caption buttons, and back-button sprite come from the
  AeroThemePlasma/SMOD projects at the revisions recorded in `sources.lock`.
  Their copied assets and the mechanical Kvantum button crops remain under the
  upstream AGPL-3.0 terms. License texts are retained as
  `third_party/AeroThemePlasma-LICENSE` and `third_party/SMOD-LICENSE`.
- `installer/assets/aero-shell/aero7-background.png` and
  `installer/assets/aero-shell/aero7-user.png` are copied from the local
  Aero7-shell repository. The wallpaper is project-owner-supplied artwork and
  the portrait is covered by that project's MIT license. They are used for the
  finished-desktop preview and first-boot account portrait. SDDM, Welcome, and
  the lock screen continue to use the separate original blue installer
  background.
- `installer/assets/loading/spinner_*.png` are the 20-pixel animated loading
  frames from the pinned PlymouthVista theme above. The installer uses them so
  its setup and first-boot transitions match the selected boot theme.
- `installer/assets/fonts/AdwaitaSans-Regular.ttf` is the OFL-1.1 licensed
  Adwaita Sans typeface from GNOME's `adwaita-fonts` project. It is embedded in
  the installer so local renders and the booted ISO use identical typography;
  its license is retained as `third_party/AdwaitaFonts-LICENSE`.
- The cursor, analog clock, disk/network/update symbols, progress artwork,
  check mark, warning symbol, and recycle-bin illustration are original
  code-native SVG/QML artwork created for this installer.

The Windows 7 screenshots supplied during development remain visual references
and are not embedded in the ISO. PlymouthVista is a separate requested
compatibility theme with an upstream Microsoft-asset notice. A publicly
distributed ISO therefore requires the distributor to review those artwork and
trademark rights independently of the open-source software licences.
