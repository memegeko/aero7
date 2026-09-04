#!/usr/bin/env python3
"""Pinned package integration boundary for Aero7-shell.

This intentionally does not invoke or patch aero7-shell/install.sh. The source
installer requires a normal user with sudo on a running Arch system and has no
target-root mode. This adapter installs the published signed base payload plus
the checksum-pinned Beta 2 test update set embedded in this ISO.
"""

from __future__ import annotations

import hashlib
from pathlib import Path
import re
import shutil
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


def read_local_package_manifest(path: Path) -> dict[str, str]:
    packages: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split(maxsplit=1)
        if len(fields) != 2:
            raise RuntimeError("invalid Beta 2 local package manifest entry")
        digest, relative_path = fields
        if not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise RuntimeError("invalid Beta 2 local package checksum")
        match = re.fullmatch(
            r"local-packages/([A-Za-z0-9@+_.-]+\.pkg\.tar\.zst)",
            relative_path,
        )
        if match is None:
            raise RuntimeError("invalid Beta 2 local package path")
        package_name = match.group(1)
        if package_name in packages:
            raise RuntimeError("duplicate Beta 2 local package manifest entry")
        packages[package_name] = digest
    if not packages:
        raise RuntimeError("Beta 2 local package manifest is empty")
    return packages


def read_offline_package_manifest(path: Path) -> dict[str, str]:
    packages: dict[str, str] = {}
    prefix = "offline-packages/aero7/"
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split(maxsplit=1)
        if len(fields) != 2 or not re.fullmatch(r"[0-9a-f]{64}", fields[0]):
            raise RuntimeError("invalid offline Aero7 package manifest entry")
        relative_path = fields[1]
        if not relative_path.startswith(prefix):
            raise RuntimeError("invalid offline Aero7 package path")
        package_name = relative_path.removeprefix(prefix)
        if not re.fullmatch(r"[A-Za-z0-9@+_.:-]+\.pkg\.tar\.(?:zst|xz)", package_name):
            raise RuntimeError("invalid offline Aero7 package filename")
        if package_name in packages:
            raise RuntimeError("duplicate offline Aero7 package manifest entry")
        packages[package_name] = fields[0]
    if not packages:
        raise RuntimeError("offline Aero7 package manifest is empty")
    return packages


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as package_file:
        for chunk in iter(lambda: package_file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def resolve_declared_local_packages(
        declared_names: list[str], package_files: list[Path]) -> dict[str, Path]:
    resolved: dict[str, Path] = {}
    for name in declared_names:
        if not re.fullmatch(r"[A-Za-z0-9@+_.:-]+", name):
            raise RuntimeError("invalid Beta 2 local package name")
        matches = [path for path in package_files if path.name.startswith(f"{name}-")]
        if len(matches) != 1:
            raise RuntimeError(f"Beta 2 package {name} does not resolve to exactly one file")
        resolved[name] = matches[0]
    return resolved


def read_offline_repo_manifest(path: Path) -> str:
    fields = path.read_text(encoding="utf-8").strip().split(maxsplit=1)
    expected_path = "offline-packages/aero7-offline.db.tar.gz"
    if (len(fields) != 2 or not re.fullmatch(r"[0-9a-f]{64}", fields[0])
            or fields[1] != expected_path):
        raise RuntimeError("invalid offline Aero7 repository manifest")
    return fields[0]


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
    variant_path = share_dir / "install-variant"
    variant = variant_path.read_text(encoding="utf-8").strip() if variant_path.exists() else "online"
    if variant not in {"online", "offline"}:
        raise RuntimeError("invalid Aero7 installer variant")

    # Resolve and verify the embedded Beta 2 set before pacman contacts the
    # public repository. That endpoint intentionally remains on Beta 1, so an
    # older copy must not be downloaded when its replacement is already on the
    # test ISO.
    local_package_dir = share_dir / "local-packages"
    local_names_path = share_dir / "beta2-local-package-names.txt"
    optional_names_path = share_dir / "beta2-optional-package-names.txt"
    local_manifest_path = share_dir / "beta2-local-packages.sha256"
    local_packages = sorted(local_package_dir.glob("*.pkg.tar.zst"))
    local_package_names: list[str] = []
    optional_package_names: list[str] = []
    expected_packages: dict[str, str] = {}
    if local_packages or local_names_path.exists() or local_manifest_path.exists():
        if (not local_packages or not local_names_path.is_file()
                or not local_manifest_path.is_file()):
            raise RuntimeError("Beta 2 local desktop package set is incomplete")
        local_package_names = read_packages(local_names_path)
        if optional_names_path.is_file():
            optional_package_names = read_packages(optional_names_path)
        overlap = set(local_package_names) & set(optional_package_names)
        if overlap:
            raise RuntimeError("a Beta 2 package cannot be both required and optional")
        expected_packages = read_local_package_manifest(local_manifest_path)
        actual_package_names = {package.name for package in local_packages}
        if actual_package_names != set(expected_packages):
            raise RuntimeError("Beta 2 local package files do not match the manifest")
        for local_package in local_packages:
            if sha256_file(local_package) != expected_packages[local_package.name]:
                raise RuntimeError(
                    f"Beta 2 local package checksum failed: {local_package.name}"
                )
        declared = resolve_declared_local_packages(
            local_package_names + optional_package_names, local_packages)
        if set(declared.values()) != set(local_packages):
            raise RuntimeError("Beta 2 local package manifest contains an undeclared package")

    required_local_files = resolve_declared_local_packages(
        local_package_names, local_packages) if local_packages else {}
    optional_local_files = resolve_declared_local_packages(
        optional_package_names, local_packages) if optional_package_names else {}

    embedded_names = set(local_package_names)
    repository_packages = [
        package for package in requested_packages if package not in embedded_names
    ]

    # The focused Plasma base installs Arch's libplasma first. Aero7's patched
    # aeroshell-libplasma-git package declares that package as a conflict and
    # provider, so approve only pacman's conflict-replacement question. Avoid
    # piping blanket "yes" responses: unexpected key, corruption, or package
    # removal questions must continue to fail closed.
    if variant == "online" and repository_packages:
        runner.run(
            [
                "arch-chroot",
                str(target),
                "pacman",
                "-Syy",
                "--needed",
                "--noconfirm",
                "--ask=4",
                *repository_packages,
            ]
        )
        runner.run(
            ["arch-chroot", str(target), "pacman", "-Q", "--", *repository_packages]
        )

    if variant == "offline":
        offline_package_dir = share_dir / "offline-packages/aero7"
        offline_manifest_path = share_dir / "offline-aero7-packages.sha256"
        offline_repo_source = share_dir / "offline-packages/aero7-offline.db.tar.gz"
        offline_repo_manifest = share_dir / "offline-aero7-repo.sha256"
        if (not offline_package_dir.is_dir() or not offline_manifest_path.is_file()
                or not offline_repo_source.is_file()
                or not offline_repo_manifest.is_file()):
            raise RuntimeError("offline Aero7 package bundle is missing")
        expected_offline = read_offline_package_manifest(offline_manifest_path)
        offline_packages = sorted(offline_package_dir.glob("*.pkg.tar.*"))
        if {package.name for package in offline_packages} != set(expected_offline):
            raise RuntimeError("offline Aero7 package files do not match the manifest")
        for offline_package in offline_packages:
            if sha256_file(offline_package) != expected_offline[offline_package.name]:
                raise RuntimeError(
                    f"offline Aero7 package checksum failed: {offline_package.name}"
                )
        expected_repo_hash = read_offline_repo_manifest(offline_repo_manifest)
        if sha256_file(offline_repo_source) != expected_repo_hash:
            raise RuntimeError("offline Aero7 repository database checksum failed")
        target_repo = target / "var/cache/pacman/aero7-offline"
        target_repo.mkdir(parents=True, exist_ok=True)
        for offline_package in offline_packages:
            target_package = target_repo / offline_package.name
            shutil.copy2(offline_package, target_package)
            Path(f"{target_package}.sig").unlink(missing_ok=True)
        sync_dir = target / "var/lib/pacman/sync"
        sync_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(offline_repo_source, sync_dir / "aero7-offline.db")
        offline_config = target / "etc/pacman-aero7-offline.conf"
        offline_config.write_text(
            "[options]\n"
            "Architecture = auto\n"
            "SigLevel = Required DatabaseOptional\n"
            "LocalFileSigLevel = Optional\n"
            "[aero7-offline]\n"
            "SigLevel = Optional TrustAll\n"
            "Server = file:///var/cache/pacman/aero7-offline\n",
            encoding="utf-8",
        )
        if repository_packages:
            runner.run(
                [
                    "arch-chroot",
                    str(target),
                    "pacman",
                    "--config",
                    "/etc/pacman-aero7-offline.conf",
                    "-S",
                    "--needed",
                    "--noconfirm",
                    "--ask=4",
                    *repository_packages,
                ]
            )
            runner.run(
                ["arch-chroot", str(target), "pacman", "-Q", "--", *repository_packages]
            )

    # Install every checksum-pinned local package in one transaction so
    # replacements and the new desktop meta-package are dependency-resolved
    # together.
    if optional_local_files:
        optional_cache = target / "var/cache/aero7/optional-packages"
        optional_cache.mkdir(parents=True, exist_ok=True)
        for package_name, local_package in optional_local_files.items():
            cached = optional_cache / f"{package_name}.pkg.tar.zst"
            shutil.copy2(local_package, cached)
            Path(f"{cached}.sha256").write_text(
                expected_packages[local_package.name] + "\n", encoding="ascii"
            )

    if required_local_files:
        target_cache = target / "var/cache/pacman/pkg"
        target_cache.mkdir(parents=True, exist_ok=True)
        target_packages: list[str] = []
        for local_package in required_local_files.values():
            target_package = target_cache / local_package.name
            shutil.copy2(local_package, target_package)
            # A signed Beta 1 package with the same filename may already be in
            # pacman's cache. Its detached signature no longer matches the
            # reviewed Beta 2 payload, while LocalFileSigLevel intentionally
            # permits this checksum-pinned local update set.
            Path(f"{target_package}.sig").unlink(missing_ok=True)
            target_packages.append(f"/var/cache/pacman/pkg/{local_package.name}")
        runner.run(
            [
                "arch-chroot",
                str(target),
                "pacman",
                "-U",
                "--noconfirm",
                "--ask=4",
                "--overwrite",
                "usr/bin/aero7-file-explorer",
                *target_packages,
            ]
        )
        runner.run(
            [
                "arch-chroot",
                str(target),
                "pacman",
                "-Q",
                "--",
                *dict.fromkeys(requested_packages + local_package_names),
            ]
        )

    state_dir = target / "var/lib/aero7"
    state_dir.mkdir(parents=True, exist_ok=True)
    (state_dir / "requested-aero7-packages.txt").write_text(
        "\n".join(dict.fromkeys(requested_packages + local_package_names)) + "\n",
        encoding="utf-8",
    )
