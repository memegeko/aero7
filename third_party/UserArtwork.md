# Project-owner-supplied Aero7 artwork

The project owner supplied two AI-generated Aero7 logo images on 2026-07-29:
one plain four-pane mark and one circular glass variant. OpenAI's built-in image
editor was used in background-extraction mode to place each existing mark on a
flat magenta chroma key. The standard imagegen transparency helper then removed
that key without installing software on the host.

Project outputs:

- `installer/assets/aero7-logo-plain.png`
- `installer/assets/aero7-logo-circle.png`
- `third_party/PlymouthVista/images/aero7-logo-plain.png`
- `third_party/PlymouthVista/images/aero7-logo-circle.png`

Final image-editing prompt intent: isolate the supplied mark; preserve its pane
or circular-glass design; remove only the original background and exterior glow;
add no text, watermark, shadow, or extra branding.
