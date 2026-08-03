# Troubleshooting

## The VM boots back into the ISO after installation

Put the VirtIO hard disk before the virtual DVD in UEFI boot order. The provided
launcher uses disk `bootindex=1` and DVD `bootindex=2`, so an empty disk falls
through to setup and a completed disk wins after restart.

## Black screen that repaints when the mouse moves

This is normally a host QEMU display frontend problem, not a frozen installer.
Use QXL with SPICE and disable host-side image compression. Avoid standard VGA,
GTK/Cairo, or virtio-vga combinations that reproduce stale damage or scan-out
issues with this Cage/wlroots stack.

## Mouse moves but clicks do not work

Attach a VirtIO tablet and use SPICE. Remove competing emulated VMware or PS/2
tablet devices if the pointer coordinates or button events are duplicated.

## No graphical installer

1. Boot **Aero7 Setup (debug, no splash)**.
2. Switch to TTY2 with Alt+F2.
3. Run the commands in [Recovery and Logs](Recovery-and-Logs.md).
4. Check whether Cage, Qt, QXL, or package-mirror errors appear.

## No disk appears

Beta 1 lists only safe targets. Check that the disk:

- is a whole VirtIO block disk such as `/dev/vda`;
- is at least 16 GiB;
- is writable and non-removable;
- has no mounted partition;
- is not the live ISO source;
- is inside a supported DMI-identified virtual machine.

## Package installation fails

The installer downloads the signed Arch base system during installation. If
the log contains `Could not resolve host` for an Arch mirror, the live system
does not have working DNS. Make sure the virtual machine has a connected
network adapter, its link is up, and the network provides DHCP and DNS.

Current builds check both connectivity and mirror DNS before repartitioning the
selected disk. The live image connects NetworkManager to systemd-resolved so
DHCP-provided DNS servers are available to package tools. If that preflight
still fails, Setup stops with a specific recovery message and does not modify
the target disk. Do not bypass signature checks. Include the failing package
name and the end of the log in a bug report.

## OOBE does not reach the desktop

Open TTY2 and check `aero7-oobe.service`, SDDM, the shell adapter log, and the
first-login state. See [Recovery and Logs](Recovery-and-Logs.md). Avoid manually
enabling permanent
autologin; the normal first-login setting is deliberately temporary.

## Report a useful bug

Open an [Aero7 issue](https://github.com/memegeko/aero7/issues/new) with:

- exact ISO filename and SHA-256;
- QEMU version and launch settings;
- the page where the problem appeared;
- a screenshot;
- relevant logs with passwords or private network data removed.
