#!/usr/bin/env python3
"""Pinned signed-package integration boundary for Aero7-shell.

This intentionally does not invoke or patch aero7-shell/install.sh. The source
installer requires a normal user with sudo on a running Arch system and has no
target-root mode. This adapter installs only the published signed binary payload.
"""

from __future__ import annotations

from pathlib import Path
from typing import Protocol


FINGERPRINT = "72C79ABBBBE96446DD3324042694BFE1090F4FD6"
REPOSITORY = "https://memegeko.github.io/aero7-repo/$arch"


class Runner(Protocol):
    def run(self, argv: list[str], *, input_text: str | None = None) -> None: ...


def read_packages(path: Path) -> list[str]:
    packages: list[str] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line and not line.startswith("#"):
            packages.append(line)
    if not packages:
        raise RuntimeError("Aero7 package allowlist is empty")
    return packages


def configure_and_install(target: Path, runner: Runner, share_dir: Path) -> None:
    key_source = share_dir / "aero7-repository.asc"
    package_source = share_dir / "aero7-packages.txt"
    if not key_source.is_file():
        raise RuntimeError(f"Pinned Aero7 repository key is missing: {key_source}")

    key_target = target / "usr/share/aero7/aero7-repository.asc"
    key_target.parent.mkdir(parents=True, exist_ok=True)
    key_target.write_bytes(key_source.read_bytes())

    pacman_conf = target / "etc/pacman.conf"
    stanza = (
        "\n# Added by Aero7 ISO from the pinned sources.lock configuration.\n"
        "[aero7]\n"
        "SigLevel = Required DatabaseRequired\n"
        f"Server = {REPOSITORY}\n"
    )
    existing = pacman_conf.read_text(encoding="utf-8")
    if "\n[aero7]\n" not in existing:
        pacman_conf.write_text(existing.rstrip() + "\n" + stanza, encoding="utf-8")

    runner.run(["arch-chroot", str(target), "pacman-key", "--init"])
    runner.run(["arch-chroot", str(target), "pacman-key", "--populate", "archlinux"])
    runner.run(
        ["arch-chroot", str(target), "pacman-key", "--add", "/usr/share/aero7/aero7-repository.asc"]
    )
    runner.run(["arch-chroot", str(target), "pacman-key", "--lsign-key", FINGERPRINT])
    requested_packages = read_packages(package_source)
    runner.run(
        [
            "arch-chroot",
            str(target),
            "pacman",
            "-Syy",
            "--needed",
            *requested_packages,
        ],
        input_text="y\n" * 128,
    )
    # pacman can return success when every transaction completed, but verify
    # the exact allowlist as a separate release gate. A partial Aero desktop is
    # less useful than a clear installation error with a diagnostic log.
    runner.run(
        ["arch-chroot", str(target), "pacman", "-Q", "--", *requested_packages]
    )
    state_dir = target / "var/lib/aero7"
    state_dir.mkdir(parents=True, exist_ok=True)
    (state_dir / "requested-aero7-packages.txt").write_text(
        "\n".join(requested_packages) + "\n", encoding="utf-8"
    )
