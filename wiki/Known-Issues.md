# Known Issues

## Beta 1 limitations

- Installation execution is still VM-only. Development builds now expose
  guided advanced targets for preservation testing.
- Only x86-64 UEFI is supported.
- Internet access is required for Arch and Aero7 package downloads.
- Delete, Extend, encryption, free-form manual partitioning, offline
  installation, legacy BIOS, and physical-hardware execution are unavailable.
- Advanced mode currently installs its own Aero7 ESP. Existing firmware boot
  entries are preserved, so another OS may be selected through the firmware
  boot menu rather than the Aero7 systemd-boot menu.
- Language and regional choices are limited to the currently validated flow.

## Display and input

QEMU's legacy standard VGA output can miss wlroots damage updates, leaving mouse
trails or fragments of a previous page. Some GTK/Cairo combinations have also
shown a black window that repaints only when the pointer moves. Use QXL through
SPICE and a VirtIO tablet, as documented in
[System Requirements](System-Requirements.md).

The host SPICE viewer may print harmless GTK minimum-size or automount-inhibitor
warnings. These do not indicate a guest installer failure.

## First desktop session

Plasma may briefly react to a virtual display hotplug and open Display
Configuration on unusual host display changes. Close it normally. The Aero7
first-login helper also repairs duplicate panels, light colors, application
branding, and menu indexing once per account.

## Packaging

Beta 1 consumes current Arch packages during installation. A future incompatible
upstream package can therefore affect an old ISO even when the ISO itself has
not changed. Report the installer log and date when filing a package failure.

## Artwork and redistribution

The requested PlymouthVista compatibility theme retains upstream animation
frames whose README attributes visual resources to Microsoft Corporation.
Anyone redistributing the ISO publicly must independently review the rights and
notices described in [Credits and Licensing](Credits-and-Licensing.md).
