# Aero7 Beta 2 release candidate

## Current status

Beta 2 source, package definitions, documentation, and wiki pages are ready for
review. The Beta 2 ISO files are not published yet. Beta 1 remains the current
download while the last fresh-install and graphical acceptance checks are
completed.

## Choose the offline image when it is released

The offline ISO is the recommended Beta 2 installer. It contains the complete
package set, works without internet during setup, and is normally much faster
and more reliable on slower laptops. The online ISO is smaller but needs a
stable connection for the complete package installation. Both use the normal
signed repositories for later updates.

## Highlights

- Aero7 Desktop Wayland session with AeroThemePlasma fallback
- Clean factory desktop and Windows 7-inspired taskbar layout
- Corrected SDDM and lock-screen branding with accessibility and session menus
- Windows-style rectangular screenshots on `Meta+Shift+S`
- Stable embedded Aero7 application icons across global icon-theme changes
- File Explorer identity, taskbar pinning, Recycle Bin settings, Libraries,
  Computer, common dialogs, and mount filtering improvements
- 45-item Control Panel and native Linux-backed settings pages
- Searchable **Turn Aero7 features on or off** manager
- Optional Programs Center Beta retained locally for offline enable/remove
- Renamed `aero7-device-manager` package with upgrade compatibility
- Persistent, privacy-scoped physical-install diagnostic folder on the desktop
- Separate online and complete offline installation paths

The full candidate package versions, technical changes, and release gate are in
the repository's
[Beta 2 release notes](https://github.com/aero7-open-project/aero7/blob/beta/docs/BETA2-RELEASE-NOTES.md).

## Still required before ISO publication

Both final images need a fresh install, reboot/OOBE/login verification, desktop
interaction checks, failure/recovery checks, final embedded-content validation,
and published SHA-256 sidecars. Until that evidence exists, no Beta 2 ISO link
or checksum is official.
