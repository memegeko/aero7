# Pinned visual-theme sources

- PlymouthVista: `https://github.com/furkrn/PlymouthVista.git` at
  `e2b9605a7b4d649bb0e314cce8bbe9912633cfef`.
- AeroThemePlasma: `https://github.com/aeroshell-desktop/aerothemeplasma.git`
  branch `Plasma/6.7` at `6746c83e05b718cda8b28a8e25921b0d73a950f0`.
- SMOD: `https://gitgud.io/aeroshell/smod.git` at
  `f3722949cb2fd0d5cb5cb20a7f439b1b4b936ca0`.

`PlymouthVista.script` is generated from the included `.sp` source files. Its
configuration selects the Windows 7-style animation while changing the visible
startup, resume, and copyright strings to Aero7 branding.

The installer copies the SMOD Aero frame and caption-button textures and the
AeroThemePlasma back-button sprite. The three `controls/button-*.png` files are
mechanical 21×21 crops of the `btn-normal`, `btn-focused`, and `btn-pressed`
states in AeroThemePlasma's `Windows7Aero.svg`, used as scalable nine-patch
button backgrounds.
