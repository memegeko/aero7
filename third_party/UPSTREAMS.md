# Pinned visual-theme sources

- PlymouthVista: `https://github.com/furkrn/PlymouthVista.git` at
  `e2b9605a7b4d649bb0e314cce8bbe9912633cfef`.
- AeroThemePlasma: `https://github.com/aeroshell-desktop/aerothemeplasma.git`
  branch `Plasma/6.7` at `6746c83e05b718cda8b28a8e25921b0d73a950f0`.
- SMOD: `https://gitgud.io/aeroshell/smod.git` at
  `f3722949cb2fd0d5cb5cb20a7f439b1b4b936ca0`.

The Aero7 tree retains only the pinned Plymouth runtime, its MIT license, the
animation frames used by the ISO, and the reproducible Aero7 frame generator.
Unused upstream install/configuration documentation and an incomplete compiler
wrapper were deliberately omitted. `THIRD_PARTY.md` records the retained asset
provenance and redistribution caveat.

The installer copies the SMOD Aero frame and caption-button textures and the
AeroThemePlasma back-button sprite. The three `controls/button-*.png` files are
mechanical 21×21 crops of the `btn-normal`, `btn-focused`, and `btn-pressed`
states in AeroThemePlasma's `Windows7Aero.svg`, used as scalable nine-patch
button backgrounds.
