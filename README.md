# Aero7 ISO

Aero7 ISO Beta 1 is an experimental x86-64 UEFI installer for an Arch Linux-based
Aero7 desktop. It boots into a Qt 6/QML interface inside the Cage Wayland kiosk
compositor. A normal live desktop is not installed or exposed; a recovery shell
remains available on TTY2.

The graphical flow is inspired by the pacing and hierarchy of the Windows 7
setup screenshots supplied during development. It keeps original Aero7
branding and wording, while using the AeroThemePlasma/SMOD window frame and
control artwork requested for closer visual consistency. The boot animation is
the requested PlymouthVista theme configured to display Aero7 startup text.
See `THIRD_PARTY.md` before redistributing an ISO.

## Complete installer flow

The default ISO now connects the installer and first-boot experience into one
safe walkthrough:

```text
Language -> Install now -> License -> Install type -> Disk -> Confirmation
-> Installing -> Restart -> Applying settings -> Video check -> Account
-> Password -> Updates -> Time zone -> Network -> Finalizing -> Welcome
-> Preparing desktop -> Aero7 desktop
```

On a real installation, the restart is a genuine boundary: the live ISO
finishes the disk phase, the installed system boots `aero7-oobe.service`, and
OOBE completes the account and system configuration. Simulation mode bridges
that boundary in memory so the entire experience can be tested without writing
to a disk.

## Safety status

The default build is a **VM-only real installer**. It can erase only the
disposable VirtIO disk attached by the provided QEMU runner. Real installation
is deliberately gated behind all of the following:

- a live-enabled ISO build;
- an explicit final disk confirmation;
- root execution inside the live ISO;
- a verified virtual-machine environment;
- an unmounted, writable, non-removable target whose fingerprint still matches;
- the exact destructive-operation guard token.

The live backend supports only one layout: UEFI, GPT, a 1 GiB FAT32 EFI System
Partition, an ext4 root partition, and systemd-boot. It rejects dual boot,
encryption, manual partitioning, legacy BIOS, mounted disks, and host testing.

## Host requirements

On Arch Linux:

```bash
sudo pacman -S --needed archiso cmake ninja qt6-base qt6-declarative \
  qt6-svg qt6-wayland qemu-desktop edk2-ovmf cage imagemagick shellcheck
```

`cage` is required in the generated ISO but is not needed to compile the app.
ShellCheck is optional for a prepare-only build, although `scripts/check.sh`
reports it when unavailable.

## Build and test

Compile the application, run automated tests, lint QML, and assemble a complete
Archiso profile without invoking privileged Archiso operations:

```bash
./scripts/build-iso.sh --prepare-only
```

Build the default VM-install ISO. Compilation and profile assembly deliberately
run without root; only the final Archiso phase uses sudo:

```bash
./scripts/build-iso.sh --prepare-only
sudo ./scripts/build-iso.sh --mkarchiso-only
```

The result is written to `out/aero7-beta1-YYYY.MM.DD-x86_64.iso`.

Verify the published ISO metadata, checksum, boot arguments, embedded backend,
release label, and pinned source lock without root:

```bash
./scripts/verify-release.sh
```

Launch it with a fresh, project-local QEMU disk:

```bash
./scripts/run-qemu.sh --fresh
```

`--fresh` resets the disposable VM disk and UEFI variables. It does not rebuild
the ISO; run both build phases above first whenever the source has changed.
The default launcher uses a lossless local SPICE connection through
`remote-viewer`, disables QEMU's conflicting VMware mouse, and uses a native
VirtIO tablet so pointer coordinates and click events remain aligned with the
installer framebuffer. SDL and GTK remain available through `--display` for
diagnostics.

The UEFI menu contains:

- **Aero7 Setup** — normal boot with PlymouthVista in Windows 7-style mode and
  Aero7 startup text.
- **Aero7 Setup (debug, no splash)** — verbose kernel and systemd output.

If the graphical kiosk cannot start, TTY1 shows the Cage/Qt exit code and the
last 60 log lines instead of remaining black. Recovery remains on Alt+F2; its
commands are:

```bash
journalctl -u aero7-installer --no-pager
cat /var/log/aero7-kiosk.log
```

The **Repair your computer** link on the Install screen asks for confirmation,
starts the same recovery getty, and switches to TTY2. Return with Alt+F1.

The QEMU runner also captures debug-console output in
`work/qemu/aero7-serial.log`.

To build a simulation-only ISO for visual testing, explicitly disable the live
backend:

```bash
AERO7_ENABLE_LIVE_INSTALL=0 ./scripts/build-iso.sh --prepare-only
sudo ./scripts/build-iso.sh --mkarchiso-only
./scripts/run-qemu.sh --fresh
```

Never attach a host block device to the QEMU command. The provided runner only
creates and uses `work/qemu/aero7-test.qcow2`.

## Aero7-shell integration

The disk phase installs the complete Arch/Plasma dependency set and the signed
Aero7 binary packages from the pinned repository. The exact pinned
Aero7-shell runtime is also embedded for first boot.

The signed application set includes Aero Dolphin, Aero Gwenview, Linux Control
Panel, Aero KolourPaint, the three original Aero7 gadgets, execbin, and LinVer.
WinXplorer remains available as an optional compatibility package but is not
installed by the ISO. Stock Dolphin and Gwenview are omitted from the base `pacstrap`
transaction so their Aero replacements can be installed without a package
conflict. Sevulet remains excluded because its source and redistribution license
cannot currently be audited.

The build checks the ISO package manifests against both pinned shell package
lists. During installation, pacman must then confirm every signed Aero7 package
before setup continues; the requested list is recorded at
`/var/lib/aero7/requested-aero7-packages.txt` for diagnosis.

After OOBE creates the account, Aero7-shell runs in its guarded `--image-mode`.
Its existing stages apply the Plasma theme, panel layout, wallpaper, SDDM,
Fastfetch, deferred first-login helper, management commands, backups, and final
validation. System work runs directly under the root-owned OOBE service, while
user configuration is written as the selected account. No passwordless sudo
rule is created or retained.

Before the one-time automatic login begins, OOBE also pins the light Aero color
scheme and the shell repository's default copyright-free wallpaper. This keeps
SDDM, the Welcome splash, the lock screen, and the first Plasma session visually
consistent while the deferred live Plasma setup finishes.

See [architecture.md](docs/architecture.md),
[implementation-plan.md](docs/implementation-plan.md), and
[safety.md](docs/safety.md) for details. The latest local check results are in
[validation.md](docs/validation.md).
# aero7
