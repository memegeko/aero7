# Aero7 Support

Aero7 Beta 1 is a community test release, not a production operating system.
Support is limited to the configuration in the
[support matrix](wiki/System-Requirements.md): x86-64 UEFI, QEMU/KVM, and a
disposable VirtIO target disk.

Before reporting a problem:

1. Read the [troubleshooting guide](wiki/Troubleshooting.md) and
   [known issues](wiki/Known-Issues.md).
2. Reproduce it with the current launcher and a fresh VM disk.
3. Collect the installer log and the exact ISO checksum.
4. Remove passwords, tokens, hostnames, and personal information.

Use the GitHub bug-report form for reproducible problems and GitHub Discussions
for general questions. Security-sensitive problems must follow
[`SECURITY.md`](SECURITY.md), not the public issue tracker.

Physical-hardware installation, dual boot, encryption, legacy BIOS, manual
partitioning, unsupported hypervisors, and data recovery are outside Beta 1's
support scope.
