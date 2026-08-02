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
- `installer/assets/aero7-logo-plain.png` and the two `aero7-logo-*.png` files
  under `third_party/PlymouthVista/images/` are derived from AI-generated images
  supplied by the project owner on 2026-07-29. OpenAI's built-in image editor
  isolated the supplied marks on a chroma-key background; the background was
  then removed mechanically. The plain mark is used by the installer and the
  circular mark is used as the finished desktop's Start badge. At the project
  owner's request, the existing animated Plymouth boot sequence is retained
  instead of replacing it with the static circular mark.
- `installer/assets/aero7-sddm-branding.png` is a mechanical 350x50 composition
  of that project-owner-supplied plain mark with Aero7 text rendered in the
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
  were removed from the current tree and are not installed; shutdown/update
  branding uses the project-owner-supplied plain Aero7 mark and the project's
  original Aero7 background. Earlier commits still contain the removed files.
- The installer frame, caption buttons, and back-button sprite come from the
  AeroThemePlasma/SMOD projects at the revisions recorded in `sources.lock`.
  Their copied assets and the mechanical Kvantum button crops remain under the
  upstream AGPL-3.0 terms. License texts are retained as
  `third_party/AeroThemePlasma-LICENSE` and `third_party/SMOD-LICENSE`.
- `installer/assets/aero-shell/aero_bg_1.png` and
  `installer/assets/aero-shell/aero7-user.png` are copied from the local
  Aero7-shell repository and are covered by that project's MIT license. They
  are used for the finished-desktop preview and first-boot account portrait.
  The build mechanically converts `aero_bg_1.png` to JPEG for the SDDM,
  Welcome, and lock-screen backgrounds; no separate wallpaper is introduced.
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
