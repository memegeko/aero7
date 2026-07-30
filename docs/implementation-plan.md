# First vertical-slice implementation plan

1. Preserve and pin the read-only Aero7-shell clone, including its clean Git
   state, origin, and exact commit.
2. Build one scalable Qt 6/QML application with separate installer and OOBE
   state machines. Use a 1024×768 design canvas that scales uniformly to
   1366×768 and 1920×1080.
3. Keep simulation mode as the default. Provide a small privileged Python
   backend whose destructive path is VM-gated, fingerprinted, revalidated, and
   restricted to the documented GPT/ESP/ext4/systemd-boot layout.
4. Assemble an Archiso profile that starts Cage and the installer directly on
   TTY1, keeps a recovery getty on TTY2, and includes no live Plasma session.
5. Install a first-boot Cage/OOBE service in the target. OOBE creates the real
   user, configures hostname/time/update preference, then disables itself and
   enables SDDM without leaving a setup account or sudo exception.
6. Exercise flow transitions and disk-plan validation automatically; run CMake,
   CTest, Python tests, qmllint, Bash syntax checks, and ShellCheck when present.
7. Build the ISO when privileged Archiso execution is authorized, then boot it
   only with the disposable QCOW2 disk created by `scripts/run-qemu.sh`.

The vertical slice is complete when the simulation ISO boots directly into the
full graphical flow and the real backend can install onto a disposable QEMU
disk under its explicit safety gates. Full Aero7-shell per-user configuration
remains blocked until a safe post-OOBE adapter is validated.

## Current milestone

The safe simulation now exercises the complete installer-to-desktop state
sequence, including the simulated restart handoff and all first-boot transition
pages. A compiled controller test supplies valid form data and walks the same
path automatically. Enabling and validating the real destructive backend is a
separate milestone and is not implied by completion of the visual flow.
