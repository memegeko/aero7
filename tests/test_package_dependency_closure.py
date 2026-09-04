#!/usr/bin/env python3
"""Validate that the embedded Beta 2 transaction is dependency-complete."""

from __future__ import annotations

import hashlib
from pathlib import Path
import re
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]


def dependency_name(value: str) -> str:
    return re.split(r"[<>=]", value, maxsplit=1)[0]


def read_list(path: Path) -> list[str]:
    return [
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]


def manifest_packages(path: Path) -> list[Path]:
    packages: list[Path] = []
    for line in read_list(path):
        fields = line.split(maxsplit=1)
        if len(fields) != 2:
            raise AssertionError(f"invalid package manifest entry: {line}")
        packages.append(ROOT / fields[1])
    return packages


def package_metadata(path: Path) -> dict[str, list[str]]:
    text = subprocess.check_output(
        ["bsdtar", "-xOf", str(path), ".PKGINFO"],
        text=True,
        stderr=subprocess.DEVNULL,
    )
    metadata: dict[str, list[str]] = {}
    for line in text.splitlines():
        if " = " not in line:
            continue
        key, value = line.split(" = ", maxsplit=1)
        metadata.setdefault(key, []).append(value)
    return metadata


def capabilities(metadata: dict[str, list[str]]) -> set[str]:
    return {metadata["pkgname"][0]} | {
        dependency_name(value) for value in metadata.get("provides", [])
    }


class PackageDependencyClosureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        bundle_manifests = (
            ROOT / "config/offline-base-packages.sha256",
            ROOT / "config/offline-aero7-packages.sha256",
        )
        missing_bundle_files = [
            path
            for manifest in bundle_manifests
            for path in manifest_packages(manifest)
            if not path.is_file()
        ]
        if missing_bundle_files:
            raise unittest.SkipTest(
                "generated offline package bundle is not present; "
                "run scripts/prepare-offline-packages.sh before validating its closure"
            )

        cls.base = [
            (path, package_metadata(path))
            for path in manifest_packages(ROOT / "config/offline-base-packages.sha256")
        ]
        cls.aero7 = [
            (path, package_metadata(path))
            for path in manifest_packages(ROOT / "config/offline-aero7-packages.sha256")
        ]
        cls.local = [
            (path, package_metadata(path))
            for path in manifest_packages(ROOT / "config/beta2-local-packages.sha256")
        ]

    def test_local_transaction_dependencies_are_satisfied(self) -> None:
        base_capabilities = set().union(
            *(capabilities(metadata) for _, metadata in self.base)
        )
        required_local_names = set(read_list(ROOT / "config/beta2-local-package-names.txt"))
        optional_local_names = set(read_list(ROOT / "config/beta2-optional-package-names.txt"))
        manifest_local_names = {metadata["pkgname"][0] for _, metadata in self.local}
        self.assertEqual(
            manifest_local_names,
            required_local_names | optional_local_names,
            "every embedded package must be declared required or optional",
        )
        self.assertFalse(
            required_local_names & optional_local_names,
            "an embedded package cannot be both required and optional",
        )
        required_local = [
            item for item in self.local if item[1]["pkgname"][0] in required_local_names
        ]
        optional_local = [
            item for item in self.local if item[1]["pkgname"][0] in optional_local_names
        ]
        required_local_capabilities = set().union(
            *(capabilities(metadata) for _, metadata in required_local)
        )
        providers: dict[str, list[tuple[Path, dict[str, list[str]]]]] = {}
        for path, metadata in self.aero7:
            for capability in capabilities(metadata):
                providers.setdefault(capability, []).append((path, metadata))

        requested = read_list(ROOT / "config/aero7-packages.txt")
        embedded = required_local_names
        queue = [package for package in requested if package not in embedded]
        selected: dict[str, tuple[Path, dict[str, list[str]]]] = {}
        unresolved: list[str] = []
        while queue:
            dependency = queue.pop(0)
            name = dependency_name(dependency)
            if name in base_capabilities or name in required_local_capabilities or name in selected:
                continue
            choices = providers.get(name, [])
            if not choices:
                unresolved.append(dependency)
                continue
            choices.sort(
                key=lambda item: (
                    item[1]["pkgname"][0] == name,
                    item[0].name,
                )
            )
            chosen = choices[-1]
            for capability in capabilities(chosen[1]):
                selected[capability] = chosen
            queue.extend(chosen[1].get("depend", []))

        self.assertEqual([], unresolved, "repository package transaction is incomplete")
        installed = base_capabilities | required_local_capabilities | set(selected)
        missing: dict[str, list[str]] = {}
        for _, metadata in required_local:
            package_missing = [
                dependency
                for dependency in metadata.get("depend", [])
                if dependency_name(dependency) not in installed
            ]
            if package_missing:
                missing[metadata["pkgname"][0]] = package_missing
        self.assertEqual({}, missing, "embedded package transaction has missing dependencies")

        optional_capabilities = set().union(
            *(capabilities(metadata) for _, metadata in optional_local)
        )
        optional_available = installed | optional_capabilities
        optional_missing: dict[str, list[str]] = {}
        for _, metadata in optional_local:
            missing_dependencies = [
                dependency
                for dependency in metadata.get("depend", [])
                if dependency_name(dependency) not in optional_available
            ]
            if missing_dependencies:
                optional_missing[metadata["pkgname"][0]] = missing_dependencies
        self.assertEqual(
            {}, optional_missing,
            "locally retained optional packages have missing dependencies",
        )

    def test_internet_explorer_uses_approved_icon_pack_asset(self) -> None:
        package = next(
            path
            for path, metadata in self.local
            if metadata["pkgname"][0] == "aero7-internet-explorer"
        )
        icon = subprocess.check_output(
            [
                "bsdtar",
                "-xOf",
                str(package),
                "usr/share/icons/hicolor/256x256/apps/aero7-internet-explorer.png",
            ]
        )
        self.assertEqual(
            "b3fd991c7718a876e06f3ae42e9b5a0eb25cf5876ad01d581fdff99851e4f98e",
            hashlib.sha256(icon).hexdigest(),
        )


if __name__ == "__main__":
    unittest.main()
