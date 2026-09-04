#!/usr/bin/env python3
"""Narrow, fail-closed privileged backend for the Aero7 ISO.

Simulation is implemented in the Qt frontend. This process is used only for
read-only disk discovery or an explicitly live-enabled disposable VM install.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import time
from contextlib import contextmanager
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable, Iterable, Iterator

from aero7_shell_adapter import configure_and_install


MIN_DISK_BYTES = 16 * 1024**3
MIN_ROOT_BYTES = 16 * 1024**3
ADVANCED_ESP_BYTES = 1024**3
MIN_ADVANCED_REGION_BYTES = MIN_ROOT_BYTES + ADVANCED_ESP_BYTES
GUARD_TOKEN = "YES-I-AM-IN-AERO7-INSTALLER"
SUPPORTED_LAYOUT = "uefi-gpt-esp-ext4"
ADVANCED_LAYOUT = "uefi-gpt-preserve-esp-ext4"
EFI_SYSTEM_TYPE = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
LINUX_ROOT_X86_64_TYPE = "4f68bce3-e8cd-4db1-96e7-fbcaf984b709"
INSTALL_STAGES = (
    "Preparing disk",
    "Copying system files",
    "Installing the base system",
    "Installing Aero7 features",
    "Configuring the bootloader",
    "Applying system settings",
    "Preparing first boot",
)
PROC_CMDLINE = Path("/proc/cmdline")
LIVE_HOSTNAME = Path("/etc/hostname")
LIVE_SOURCE_LOCK = Path("/usr/share/aero7/sources.lock")
PACKAGE_MIRROR_HOSTS = (
    "geo.mirror.pkgbuild.com",
    "fastly.mirror.pkgbuild.com",
)
AERO7_SHARE_DIR = Path("/usr/share/aero7")
INSTALL_VARIANT_FILE = AERO7_SHARE_DIR / "install-variant"
OFFLINE_BASE_PACKAGE_DIR = AERO7_SHARE_DIR / "offline-packages/base"
OFFLINE_BASE_MANIFEST = AERO7_SHARE_DIR / "offline-base-packages.sha256"
TARGET_ROOT = Path("/mnt/aero7-target")
PARTITION_TABLE_BACKUP = Path("/var/log/aero7-partition-table-before.sfdisk")
INSTALLER_LOG = Path("/var/log/aero7-installer.log")
STORAGE_ACTIONS_LOG = Path("/var/log/aero7-storage-actions.log")
IMAGE_MODE_GUARD = "YES-I-AM-IN-AERO7-FIRST-BOOT"
SHELL_INSTALLER = Path("/usr/local/lib/aero7-shell-installer/install.sh")
SDDM_BRANDING = Path("/usr/share/aero7/branding/aero7-sddm-branding.png")
SDDM_BACKGROUND = Path("/usr/share/aero7/branding/aero7-login-background.jpg")
FIRST_LOGIN_CONFIG = Path("/etc/sddm.conf.d/10-aero7-first-login.conf")
FIRST_LOGIN_CLEANUP_TIMER = "aero7-first-login-cleanup.timer"
DIAGNOSTIC_COLLECTOR = Path("/usr/lib/aero7/aero7-collect-logs")
DIAGNOSTIC_USER_FILE = Path("/var/lib/aero7/diagnostics-user")
DIAGNOSTIC_SYSTEM_TIMER = "aero7-diagnostic-collect.timer"
DIAGNOSTIC_USER_UNITS = (
    "aero7-diagnostic-session.service",
    "aero7-diagnostic-session.timer",
)
PLYMOUTH_HOLD_SECONDS = 6
SHELL_EXECUTABLES = (
    "install.sh",
    "uninstall.sh",
    "update.sh",
    "commands/aero7",
    "commands/aero7-dir",
    "commands/aero7-ipconfig",
    "commands/aero7-systeminfo",
    "commands/aero7-winver",
)


class SafetyError(RuntimeError):
    """A fail-closed safety validation error."""


def event(kind: str, **fields: Any) -> None:
    print(json.dumps({"type": kind, **fields}, separators=(",", ":")), flush=True)


@dataclass
class ProgressPulse:
    """Emit monotonic progress while a blocking installation stage is active."""

    stage: str
    overall_start: int
    overall_end: int
    stage_start: int = 0
    stage_end: int = 100
    stage_percent: int = field(init=False)

    def __post_init__(self) -> None:
        if not 0 <= self.overall_start <= self.overall_end <= 100:
            raise ValueError("overall progress range is invalid")
        if not 0 <= self.stage_start < self.stage_end <= 100:
            raise ValueError("stage progress range is invalid")
        self.stage_percent = self.stage_start

    def emit(self, stage_percent: int | None = None) -> None:
        if stage_percent is not None:
            self.stage_percent = max(
                self.stage_percent,
                min(self.stage_end, stage_percent),
            )
        span = self.stage_end - self.stage_start
        fraction = (self.stage_percent - self.stage_start) / span
        overall = round(
            self.overall_start
            + (self.overall_end - self.overall_start) * fraction
        )
        event(
            "progress",
            stage=self.stage,
            percent=overall,
            stage_percent=self.stage_percent,
        )

    def advance(self) -> None:
        if self.stage_percent >= self.stage_end - 1:
            return
        remaining = self.stage_end - self.stage_percent
        self.emit(min(self.stage_end - 1, self.stage_percent + max(1, remaining // 18)))

    def complete(self) -> None:
        self.emit(self.stage_end)


def human_size(value: int) -> str:
    return f"{value / 1024**3:.1f} GiB"


def normalized_mountpoints(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [value] if value else []
    return [str(item) for item in value if item]


def flatten_devices(nodes: Iterable[dict[str, Any]]) -> Iterable[dict[str, Any]]:
    for node in nodes:
        yield node
        yield from flatten_devices(node.get("children", []))


def nest_block_devices(nodes: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    """Normalize lsblk output into a tree even when PKNAME flattens JSON rows."""
    flattened: list[dict[str, Any]] = []
    for source in flatten_devices(nodes):
        item = {key: value for key, value in source.items() if key != "children"}
        item["children"] = []
        flattened.append(item)

    by_kname = {
        str(item.get("kname")): item
        for item in flattened
        if item.get("kname")
    }
    roots: list[dict[str, Any]] = []
    for item in flattened:
        parent = by_kname.get(str(item.get("pkname") or ""))
        if parent is None:
            roots.append(item)
        else:
            parent["children"].append(item)
    return roots


def device_has_mounts(node: dict[str, Any]) -> bool:
    return any(normalized_mountpoints(item.get("mountpoints")) for item in flatten_devices([node]))


def disk_contains_source(node: dict[str, Any], sources: set[str]) -> bool:
    excluded = {str(Path(path).resolve()) for path in sources}
    for item in flatten_devices([node]):
        path = str(item.get("path") or "")
        if path and str(Path(path).resolve()) in excluded:
            return True
    return False


def live_sources() -> set[str]:
    """Return live-media devices and every physical ancestor.

    Ventoy commonly mounts a device-mapper node backed by a partition on the
    USB stick. Recording only the mapper node would allow its parent disk to
    appear as an installation candidate on hardware that reports USB media as
    non-removable. Reverse lsblk traversal closes that gap.
    """
    result: set[str] = set()
    for mountpoint in ("/run/archiso/bootmnt", "/boot", "/"):
        completed = subprocess.run(
            ["findmnt", "-n", "-o", "SOURCE", mountpoint],
            check=False,
            capture_output=True,
            text=True,
        )
        source = completed.stdout.strip()
        if not source.startswith("/dev/"):
            continue
        resolved = str(Path(source).resolve())
        result.add(resolved)
        ancestry = subprocess.run(
            [
                "lsblk",
                "--inverse",
                "--noheadings",
                "--paths",
                "--output",
                "PATH",
                resolved,
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        for device in ancestry.stdout.splitlines():
            device = device.strip()
            if device.startswith("/dev/"):
                result.add(str(Path(device).resolve()))
    return result


def query_lsblk() -> list[dict[str, Any]]:
    fields = (
        "PATH,KNAME,PKNAME,TYPE,SIZE,START,PARTN,MODEL,SERIAL,RO,RM,"
        "MAJ:MIN,MOUNTPOINTS,TRAN,FSTYPE,FSAVAIL,FSUSE%,LABEL,PARTLABEL,"
        "PARTTYPE,PARTUUID,UUID,LOG-SEC,PTTYPE"
    )
    completed = subprocess.run(
        ["lsblk", "--json", "--bytes", "--output", fields],
        check=True,
        capture_output=True,
        text=True,
    )
    return nest_block_devices(json.loads(completed.stdout).get("blockdevices", []))


def fingerprint(node: dict[str, Any]) -> dict[str, Any]:
    size = int(node.get("size") or 0)
    return {
        "device": str(node.get("path") or ""),
        "kname": str(node.get("kname") or ""),
        "model": str(node.get("model") or "Unknown disk").strip(),
        "serial": str(node.get("serial") or "").strip(),
        "size": human_size(size),
        "size_bytes": size,
        "maj_min": str(node.get("maj:min") or ""),
        "pttype": str(node.get("pttype") or ""),
    }


def supported_disk_path(path: str) -> bool:
    return bool(
        re.fullmatch(
            r"/dev/(?:vd[a-z]|sd[a-z]|nvme\d+n\d+|mmcblk\d+)", path
        )
    )


def align_up(value: int, alignment: int) -> int:
    if alignment <= 0:
        raise ValueError("alignment must be positive")
    return ((value + alignment - 1) // alignment) * alignment


def partition_fingerprint(node: dict[str, Any], disk_node: dict[str, Any]) -> dict[str, Any]:
    sector_size = int(disk_node.get("log-sec") or 512)
    size_bytes = int(node.get("size") or 0)
    return {
        "partition_device": str(node.get("path") or ""),
        "partition_number": int(node.get("partn") or 0),
        "partition_start_sector": int(node.get("start") or 0),
        "partition_size_sectors": size_bytes // sector_size,
        "partition_size_bytes": size_bytes,
        "partition_partuuid": str(node.get("partuuid") or ""),
        "partition_uuid": str(node.get("uuid") or ""),
        "partition_type": str(node.get("parttype") or "").lower(),
        "filesystem": str(node.get("fstype") or "").lower(),
        "label": str(node.get("label") or ""),
        "partlabel": str(node.get("partlabel") or ""),
    }


def free_regions(disk_node: dict[str, Any]) -> list[dict[str, int]]:
    """Return aligned, unallocated GPT ranges without modifying the disk."""
    sector_size = int(disk_node.get("log-sec") or 512)
    if sector_size <= 0:
        raise SafetyError("disk reports an invalid logical sector size")
    alignment = max(1, (1024 * 1024) // sector_size)
    total_sectors = int(disk_node.get("size") or 0) // sector_size
    if total_sectors <= alignment + 34:
        return []

    partitions: list[tuple[int, int]] = []
    for child in flatten_devices(disk_node.get("children", [])):
        if child.get("type") != "part":
            continue
        start = int(child.get("start") or 0)
        length = int(child.get("size") or 0) // sector_size
        if start > 0 and length > 0:
            partitions.append((start, start + length))
    partitions.sort()

    cursor = alignment
    usable_end = max(cursor, total_sectors - 34)
    regions: list[dict[str, int]] = []
    for start, end_exclusive in partitions:
        gap_start = align_up(cursor, alignment)
        gap_end = min(start, usable_end)
        if gap_end > gap_start:
            regions.append(
                {
                    "start_sector": gap_start,
                    "end_sector": gap_end - 1,
                    "size_sectors": gap_end - gap_start,
                    "size_bytes": (gap_end - gap_start) * sector_size,
                }
            )
        cursor = max(cursor, end_exclusive)

    gap_start = align_up(cursor, alignment)
    if usable_end > gap_start:
        regions.append(
            {
                "start_sector": gap_start,
                "end_sector": usable_end - 1,
                "size_sectors": usable_end - gap_start,
                "size_bytes": (usable_end - gap_start) * sector_size,
            }
        )
    return regions


def adjacent_free_region(
    disk_node: dict[str, Any], partition: dict[str, Any]
) -> dict[str, int] | None:
    """Return unallocated sectors immediately following a partition."""
    sector_size = int(disk_node.get("log-sec") or 512)
    alignment = max(1, (1024 * 1024) // sector_size)
    partition_start = int(partition.get("start") or 0)
    partition_sectors = int(partition.get("size") or 0) // sector_size
    if partition_start <= 0 or partition_sectors <= 0:
        return None
    first_sector = partition_start + partition_sectors
    expected_aligned_start = align_up(first_sector, alignment)
    for region in free_regions(disk_node):
        if region["start_sector"] != expected_aligned_start:
            continue
        size_sectors = region["end_sector"] - first_sector + 1
        if size_sectors <= 0:
            return None
        return {
            "start_sector": first_sector,
            "end_sector": region["end_sector"],
            "size_sectors": size_sectors,
            "size_bytes": size_sectors * sector_size,
        }
    return None


def storage_targets(disk_node: dict[str, Any], disk_index: int) -> list[dict[str, Any]]:
    disk_info = fingerprint(disk_node)
    disk_device = disk_info["device"]
    targets: list[dict[str, Any]] = []
    for child in flatten_devices(disk_node.get("children", [])):
        if child.get("type") != "part":
            continue
        part = partition_fingerprint(child, disk_node)
        filesystem = part["filesystem"]
        part_type = part["partition_type"]
        name = part["label"] or part["partlabel"]
        adjacent = adjacent_free_region(disk_node, child)
        if part_type == EFI_SYSTEM_TYPE:
            description = name or "EFI System Partition"
            row_type = "System"
        elif filesystem == "ntfs":
            description = name or "Windows NTFS"
            row_type = "Primary"
        else:
            description = name or (filesystem.upper() if filesystem else "Partition")
            row_type = "Primary"
        targets.append(
            {
                **disk_info,
                **part,
                "target_kind": "partition",
                "disk_device": disk_device,
                "disk_index": disk_index,
                "display_name": (
                    f"Disk {disk_index} Partition {part['partition_number']}: {description}"
                ),
                "size": human_size(part["partition_size_bytes"]),
                "free_space": "—",
                "type": row_type,
                "can_shrink": filesystem == "ntfs",
                "can_format": (
                    part_type != EFI_SYSTEM_TYPE
                    and part["partition_size_bytes"] >= MIN_ADVANCED_REGION_BYTES
                ),
                "can_delete": part_type != EFI_SYSTEM_TYPE,
                "can_extend": (
                    part_type != EFI_SYSTEM_TYPE
                    and filesystem in {"ntfs", "ext4"}
                    and adjacent is not None
                    and adjacent["size_bytes"] >= 1024**3
                ),
                "adjacent_free_start_sector": (
                    adjacent["start_sector"] if adjacent else 0
                ),
                "adjacent_free_end_sector": (
                    adjacent["end_sector"] if adjacent else 0
                ),
                "adjacent_free_size_bytes": (
                    adjacent["size_bytes"] if adjacent else 0
                ),
            }
        )

    for region_index, region in enumerate(free_regions(disk_node)):
        targets.append(
            {
                **disk_info,
                "start_sector": region["start_sector"],
                "end_sector": region["end_sector"],
                "size_sectors": region["size_sectors"],
                "region_size_bytes": region["size_bytes"],
                "target_kind": "free",
                "disk_device": disk_device,
                "disk_index": disk_index,
                "region_index": region_index,
                "display_name": f"Disk {disk_index} Unallocated Space",
                "size": human_size(region["size_bytes"]),
                "free_space": human_size(region["size_bytes"]),
                "type": "",
                "can_install": region["size_bytes"] >= MIN_ADVANCED_REGION_BYTES,
            }
        )
    return targets


def candidate_disks(nodes: list[dict[str, Any]], excluded_sources: set[str] | None = None) -> list[dict[str, Any]]:
    excluded = {str(Path(path).resolve()) for path in (excluded_sources or set())}
    candidates: list[dict[str, Any]] = []
    for disk_index, node in enumerate(nodes):
        path = str(node.get("path") or "")
        if node.get("type") != "disk" or not path.startswith("/dev/"):
            continue
        if not supported_disk_path(path):
            continue
        try:
            resolved = str(Path(path).resolve())
        except OSError:
            continue
        if resolved in excluded or disk_contains_source(node, excluded):
            continue
        if bool(node.get("ro")) or bool(node.get("rm")):
            continue
        if int(node.get("size") or 0) < MIN_DISK_BYTES:
            continue
        if device_has_mounts(node):
            continue
        item = fingerprint(node)
        item.update(
            {
                "target_kind": "disk",
                "disk_device": path,
                "disk_index": disk_index,
                "display_name": f"Disk {disk_index}: {item['model']}",
                "free_space": item["size"],
                "type": "",
                "targets": storage_targets(node, disk_index),
            }
        )
        candidates.append(item)
    return candidates


def find_disk(nodes: list[dict[str, Any]], device: str) -> dict[str, Any] | None:
    wanted = str(Path(device).resolve())
    for node in nodes:
        if node.get("type") != "disk":
            continue
        path = str(node.get("path") or "")
        if path and str(Path(path).resolve()) == wanted:
            return node
    return None


def find_partition(disk_node: dict[str, Any], device: str) -> dict[str, Any] | None:
    wanted = str(Path(device).resolve())
    for node in flatten_devices(disk_node.get("children", [])):
        if node.get("type") != "part":
            continue
        path = str(node.get("path") or "")
        if path and str(Path(path).resolve()) == wanted:
            return node
    return None


def validate_plan(plan: dict[str, Any], current: dict[str, Any], excluded_sources: set[str]) -> None:
    layout = str(plan.get("layout") or "")
    if layout not in {SUPPORTED_LAYOUT, ADVANCED_LAYOUT}:
        raise SafetyError("unsupported disk layout")
    if current.get("type") != "disk":
        raise SafetyError("selected target is not a whole disk")
    device = str(plan.get("device") or "")
    if not supported_disk_path(device):
        raise SafetyError("installation target uses an unsupported disk path")
    if disk_contains_source(current, excluded_sources):
        raise SafetyError("selected disk contains the live installation media")
    if bool(current.get("ro")):
        raise SafetyError("selected disk is read-only")
    if bool(current.get("rm")):
        raise SafetyError("selected disk is removable")
    if device_has_mounts(current):
        raise SafetyError("selected disk or one of its partitions is mounted")
    if int(current.get("size") or 0) < MIN_DISK_BYTES:
        raise SafetyError("selected disk is smaller than 16 GiB")

    actual = fingerprint(current)
    for key in ("device", "kname", "model", "serial", "size_bytes", "maj_min", "pttype"):
        if plan.get(key) != actual.get(key):
            raise SafetyError(f"disk fingerprint changed: {key}")

    if layout == SUPPORTED_LAYOUT:
        return
    if str(current.get("pttype") or "").lower() != "gpt":
        raise SafetyError("advanced installation currently requires a GPT disk")

    target_kind = str(plan.get("target_kind") or "")
    if target_kind == "free":
        expected = {
            "start_sector": int(plan.get("start_sector") or 0),
            "end_sector": int(plan.get("end_sector") or 0),
            "size_sectors": int(plan.get("size_sectors") or 0),
            "size_bytes": int(plan.get("region_size_bytes") or 0),
        }
        if expected["size_bytes"] < MIN_ADVANCED_REGION_BYTES:
            raise SafetyError("selected unallocated space is smaller than 17 GiB")
        if expected not in free_regions(current):
            raise SafetyError("selected unallocated region changed before installation")
        requested_bytes = int(
            plan.get("install_region_size_bytes") or expected["size_bytes"]
        )
        sector_size = int(current.get("log-sec") or 512)
        if requested_bytes < MIN_ADVANCED_REGION_BYTES:
            raise SafetyError("new Aero7 target is smaller than 17 GiB")
        if requested_bytes > expected["size_bytes"]:
            raise SafetyError("new Aero7 target is larger than the selected free space")
        if requested_bytes % sector_size:
            raise SafetyError("new Aero7 target size is not sector-aligned")
        requested_end = (
            expected["start_sector"] + requested_bytes // sector_size - 1
        )
        aero7_partition_append_table(
            expected["start_sector"],
            requested_end,
            sector_size,
        )
        return

    if target_kind not in {"reuse_partition", "shrink_ntfs"}:
        raise SafetyError("advanced target action is unsupported")
    partition_device = str(plan.get("partition_device") or "")
    partition = find_partition(current, partition_device)
    if partition is None:
        raise SafetyError("selected partition disappeared before installation")
    if device_has_mounts(partition):
        raise SafetyError("selected partition is mounted")
    actual_partition = partition_fingerprint(partition, current)
    for key in (
        "partition_device",
        "partition_number",
        "partition_start_sector",
        "partition_size_sectors",
        "partition_size_bytes",
        "partition_partuuid",
        "partition_uuid",
        "partition_type",
        "filesystem",
    ):
        if plan.get(key) != actual_partition.get(key):
            raise SafetyError(f"partition fingerprint changed: {key}")
    if actual_partition["partition_type"] == EFI_SYSTEM_TYPE:
        raise SafetyError("the EFI System Partition cannot be used as an Aero7 root target")

    if target_kind == "reuse_partition":
        if actual_partition["partition_size_bytes"] < MIN_ADVANCED_REGION_BYTES:
            raise SafetyError("selected partition is smaller than 17 GiB")
        aero7_partition_append_table(
            actual_partition["partition_start_sector"],
            actual_partition["partition_start_sector"]
            + actual_partition["partition_size_sectors"]
            - 1,
            int(current.get("log-sec") or 512),
        )
        return

    if actual_partition["filesystem"] != "ntfs":
        raise SafetyError("only NTFS partitions can use the Windows shrink action")
    new_size_bytes = int(plan.get("shrink_size_bytes") or 0)
    sector_size = int(current.get("log-sec") or 512)
    if new_size_bytes % sector_size:
        raise SafetyError("requested Windows size is not sector-aligned")
    released_bytes = actual_partition["partition_size_bytes"] - new_size_bytes
    if new_size_bytes < MIN_ROOT_BYTES:
        raise SafetyError("the Windows partition must remain at least 16 GiB")
    if released_bytes < MIN_ADVANCED_REGION_BYTES:
        raise SafetyError("shrinking must release at least 17 GiB for Aero7")
    new_end = (
        actual_partition["partition_start_sector"]
        + new_size_bytes // sector_size
        - 1
    )
    aero7_partition_append_table(
        align_up(new_end + 1, max(1, (1024 * 1024) // sector_size)),
        actual_partition["partition_start_sector"]
        + actual_partition["partition_size_sectors"]
        - 1,
        sector_size,
    )


def running_from_live_installer() -> bool:
    """Return true only for the booted Aero7 Archiso environment.

    The destructive token prevents accidental direct invocation, while this
    check prevents a copied backend and token from being used on an installed
    system. Direct-written media and Ventoy GRUB2 mode expose the live ISO in
    different ways, so use immutable live-root evidence rather than requiring
    `/run/archiso/bootmnt` itself to be a mount point.
    """
    try:
        cmdline = PROC_CMDLINE.read_text(
            encoding="utf-8", errors="replace"
        ).split()
        hostname = LIVE_HOSTNAME.read_text(
            encoding="utf-8", errors="replace"
        ).strip()
    except OSError:
        return False
    try:
        root_filesystem = subprocess.run(
            ["findmnt", "--noheadings", "--output", "FSTYPE", "/"],
            check=False,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except OSError:
        return False
    return (
        "archisobasedir=aero7" in cmdline
        and hostname == "aero7-setup"
        and LIVE_SOURCE_LOCK.is_file()
        and root_filesystem == "overlay"
    )


def enforce_execution_gate() -> None:
    if os.environ.get("AERO7_ALLOW_DESTRUCTIVE") != GUARD_TOKEN:
        raise SafetyError("destructive guard token is absent")
    if os.geteuid() != 0:
        raise SafetyError("real installation backend must run as root inside the ISO")
    if not running_from_live_installer():
        raise SafetyError("real installation must run from booted Aero7 installation media")


def required_install_commands(plan: dict[str, Any]) -> tuple[str, ...]:
    """Return every external command that must exist before disk changes begin."""
    commands = [
        "arch-chroot",
        "blkid",
        "genfstab",
        "mkfs.ext4",
        "mkfs.fat",
        "mount",
        "pacstrap",
        "sfdisk",
        "sync",
        "udevadm",
        "umount",
        "wipefs",
    ]
    if str(plan.get("target_kind") or "") == "shrink_ntfs":
        commands.extend(("ntfsresize", "parted"))
    return tuple(sorted(set(commands)))


def ensure_install_tools(plan: dict[str, Any]) -> None:
    missing = [name for name in required_install_commands(plan) if shutil.which(name) is None]
    if missing:
        raise SafetyError(
            "required installer tools are missing: " + ", ".join(missing)
            + ". The target disk was not changed"
        )


def backup_partition_table(
    device: str, destination: Path = PARTITION_TABLE_BACKUP
) -> Path:
    """Save a restorable sfdisk dump before an advanced layout is changed."""
    completed = subprocess.run(
        ["sfdisk", "--dump", device],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0 or not completed.stdout.strip():
        detail = completed.stderr.strip()
        message = "could not back up the existing partition table; the disk was not changed"
        if detail:
            message += f": {detail[-500:]}"
        raise SafetyError(message)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(completed.stdout, encoding="utf-8")
    destination.chmod(0o600)
    return destination


def load_plan(path: Path) -> dict[str, Any]:
    if path.is_symlink():
        raise SafetyError("plan file must not be a symbolic link")
    info = path.stat()
    if info.st_mode & (stat.S_IRWXG | stat.S_IRWXO):
        raise SafetyError("plan file permissions are too broad")
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SafetyError("plan must be a JSON object")
    return data


@dataclass
class CommandRunner:
    log_path: Path
    _heartbeat: Callable[[], None] | None = field(default=None, init=False, repr=False)
    _heartbeat_interval: float = field(default=5.0, init=False, repr=False)

    @contextmanager
    def progress_heartbeat(
        self, callback: Callable[[], None], *, interval: float = 5.0
    ) -> Iterator[None]:
        if interval <= 0:
            raise ValueError("heartbeat interval must be positive")
        previous_callback = self._heartbeat
        previous_interval = self._heartbeat_interval
        self._heartbeat = callback
        self._heartbeat_interval = interval
        try:
            yield
        finally:
            self._heartbeat = previous_callback
            self._heartbeat_interval = previous_interval

    def run(
        self,
        argv: list[str],
        *,
        input_text: str | None = None,
        ok_returncodes: tuple[int, ...] = (0,),
    ) -> None:
        if not argv or not all(isinstance(item, str) and item for item in argv):
            raise RuntimeError("invalid command argument array")
        if not ok_returncodes or not all(
            isinstance(code, int) and code >= 0 for code in ok_returncodes
        ):
            raise RuntimeError("invalid accepted return codes")
        with self.log_path.open("a", encoding="utf-8") as log:
            log.write("+ " + " ".join(repr(item) for item in argv) + "\n")
            if self._heartbeat is None:
                completed = subprocess.run(
                    argv,
                    input=input_text,
                    text=True,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    check=False,
                )
                returncode = completed.returncode
            else:
                process = subprocess.Popen(
                    argv,
                    stdin=subprocess.PIPE if input_text is not None else None,
                    text=True,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                )
                if input_text is not None and process.stdin is not None:
                    try:
                        process.stdin.write(input_text)
                        process.stdin.close()
                    except BrokenPipeError:
                        pass
                while True:
                    try:
                        returncode = process.wait(timeout=self._heartbeat_interval)
                        break
                    except subprocess.TimeoutExpired:
                        self._heartbeat()
                if returncode in ok_returncodes:
                    self._heartbeat()
        if returncode not in ok_returncodes:
            try:
                recent_lines = self.log_path.read_text(
                    encoding="utf-8", errors="replace"
                ).splitlines()[-8:]
                detail = " | ".join(line.strip() for line in recent_lines if line.strip())
            except OSError:
                detail = ""
            message = f"command failed with exit code {returncode}: {argv[0]}"
            if detail:
                message += f" ({detail[-900:]})"
            raise RuntimeError(message)


def validate_storage_action(
    plan: dict[str, Any], current: dict[str, Any], excluded_sources: set[str]
) -> tuple[dict[str, Any], dict[str, Any], dict[str, int] | None]:
    """Revalidate a partition maintenance request against the live disk."""
    action = str(plan.get("action") or "")
    if action not in {"delete", "extend"}:
        raise SafetyError("unsupported storage action")
    if current.get("type") != "disk":
        raise SafetyError("selected storage target is not a disk")
    device = str(plan.get("device") or "")
    if not supported_disk_path(device):
        raise SafetyError("storage action uses an unsupported disk path")
    if str(current.get("pttype") or "").lower() != "gpt":
        raise SafetyError("advanced storage actions currently require a GPT disk")
    if disk_contains_source(current, excluded_sources):
        raise SafetyError("selected disk contains the live installation media")
    if bool(current.get("ro")) or bool(current.get("rm")):
        raise SafetyError("selected disk is read-only or removable")
    if device_has_mounts(current):
        raise SafetyError("selected disk or one of its partitions is mounted")

    actual_disk = fingerprint(current)
    for key in ("device", "kname", "model", "serial", "size_bytes", "maj_min", "pttype"):
        if plan.get(key) != actual_disk.get(key):
            raise SafetyError(f"disk fingerprint changed: {key}")

    partition = find_partition(current, str(plan.get("partition_device") or ""))
    if partition is None:
        raise SafetyError("selected partition disappeared")
    actual_partition = partition_fingerprint(partition, current)
    for key in (
        "partition_device",
        "partition_number",
        "partition_start_sector",
        "partition_size_sectors",
        "partition_size_bytes",
        "partition_partuuid",
        "partition_uuid",
        "partition_type",
        "filesystem",
    ):
        if plan.get(key) != actual_partition.get(key):
            raise SafetyError(f"partition fingerprint changed: {key}")
    if actual_partition["partition_type"] == EFI_SYSTEM_TYPE:
        raise SafetyError("the EFI System Partition cannot be changed here")

    adjacent = adjacent_free_region(current, partition)
    if action == "delete":
        return partition, actual_partition, adjacent

    if actual_partition["filesystem"] not in {"ntfs", "ext4"}:
        raise SafetyError("only NTFS and ext4 partitions can currently be extended")
    if adjacent is None:
        raise SafetyError("the adjacent unallocated space is no longer available")
    for key, plan_key in (
        ("start_sector", "adjacent_free_start_sector"),
        ("end_sector", "adjacent_free_end_sector"),
        ("size_bytes", "adjacent_free_size_bytes"),
    ):
        if int(plan.get(plan_key) or 0) != adjacent[key]:
            raise SafetyError("adjacent unallocated space changed before extending")
    amount_bytes = int(plan.get("amount_bytes") or 0)
    sector_size = int(current.get("log-sec") or 512)
    if amount_bytes < 1024**3:
        raise SafetyError("extend amount must be at least 1 GiB")
    if amount_bytes > adjacent["size_bytes"]:
        raise SafetyError("extend amount exceeds adjacent unallocated space")
    if amount_bytes % sector_size:
        raise SafetyError("extend amount is not sector-aligned")
    return partition, actual_partition, adjacent


def apply_storage_action(plan: dict[str, Any], confirm_device: str) -> None:
    """Execute one guarded partition maintenance action from live media."""
    enforce_execution_gate()
    if confirm_device != plan.get("device"):
        raise SafetyError("final confirmation does not match the selected device")
    current = find_disk(query_lsblk(), confirm_device)
    if current is None:
        raise SafetyError("selected disk disappeared before the storage action")
    partition, actual, adjacent = validate_storage_action(
        plan, current, live_sources()
    )
    action = str(plan["action"])
    required = {"sfdisk", "udevadm"}
    if action == "extend":
        required.add("parted")
        if actual["filesystem"] == "ntfs":
            required.add("ntfsresize")
        else:
            required.update({"e2fsck", "resize2fs"})
    missing = sorted(command for command in required if shutil.which(command) is None)
    if missing:
        raise SafetyError(
            "required storage tools are missing: " + ", ".join(missing)
            + ". The disk was not changed"
        )

    backup_partition_table(confirm_device)
    runner = CommandRunner(STORAGE_ACTIONS_LOG)
    partition_path_value = str(actual["partition_device"])
    partition_number = str(actual["partition_number"])
    if action == "delete":
        runner.run(["sfdisk", "--delete", confirm_device, partition_number])
        runner.run(["udevadm", "settle"])
        event("status", message="Partition deleted; rescanning disks")
        return

    assert adjacent is not None
    sector_size = int(current.get("log-sec") or 512)
    amount_sectors = int(plan["amount_bytes"]) // sector_size
    new_end = (
        int(actual["partition_start_sector"])
        + int(actual["partition_size_sectors"])
        + amount_sectors
        - 1
    )
    if new_end > adjacent["end_sector"]:
        raise SafetyError("calculated partition boundary exceeds free space")

    if actual["filesystem"] == "ntfs":
        runner.run(["ntfsresize", "--check", partition_path_value])
    else:
        runner.run(
            ["e2fsck", "-f", "-p", partition_path_value],
            ok_returncodes=(0, 1),
        )
    runner.run(
        [
            "parted",
            "--script",
            confirm_device,
            "unit",
            "s",
            "resizepart",
            partition_number,
            f"{new_end}s",
        ]
    )
    runner.run(["udevadm", "settle"])
    if actual["filesystem"] == "ntfs":
        runner.run(["ntfsresize", "--no-action", partition_path_value])
        runner.run(["ntfsresize", "--no-progress-bar", partition_path_value])
    else:
        runner.run(["resize2fs", partition_path_value])
    event("status", message="Partition extended; rescanning disks")


def validate_driver_path(path: Path) -> Path:
    """Accept only a regular kernel module selected from mounted media."""
    if path.is_symlink():
        raise SafetyError("storage driver must not be a symbolic link")
    resolved = path.resolve(strict=True)
    allowed_roots = tuple(
        Path(root).resolve()
        for root in ("/run/media", "/run/archiso/bootmnt", "/mnt", "/media")
    )
    if not any(resolved == root or root in resolved.parents for root in allowed_roots):
        raise SafetyError("storage driver must be loaded from mounted installation media")
    if not resolved.is_file():
        raise SafetyError("storage driver is not a regular file")
    if resolved.stat().st_size <= 0 or resolved.stat().st_size > 128 * 1024**2:
        raise SafetyError("storage driver has an invalid file size")
    if not re.search(r"\.ko(?:\.xz|\.zst)?$", resolved.name):
        raise SafetyError("storage driver must be a .ko, .ko.xz, or .ko.zst module")
    return resolved


def load_storage_driver(path: Path) -> None:
    enforce_execution_gate()
    source = validate_driver_path(path)
    required = ("depmod", "modinfo", "modprobe")
    missing = [command for command in required if shutil.which(command) is None]
    if missing:
        raise SafetyError("required driver tools are missing: " + ", ".join(missing))
    kernel = os.uname().release
    vermagic = subprocess.run(
        ["modinfo", "-F", "vermagic", str(source)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    if kernel not in vermagic:
        raise SafetyError("storage driver was built for a different kernel")
    destination = Path("/usr/lib/modules") / kernel / "updates/aero7" / source.name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    runner = CommandRunner(STORAGE_ACTIONS_LOG)
    runner.run(["depmod", "-a"])
    module_name = re.sub(r"\.ko(?:\.xz|\.zst)?$", "", source.name).replace("-", "_")
    runner.run(["modprobe", module_name])
    event("status", message=f"Storage driver {module_name} loaded")


def partition_path(device: str, number: int) -> str:
    if not supported_disk_path(device):
        raise SafetyError("unsupported partition device path")
    separator = "p" if device[-1].isdigit() else ""
    return f"{device}{separator}{number}"


def partition_table() -> str:
    # The MVP accepts only QEMU VirtIO disks, whose logical sector size is
    # 512 bytes. Keep the ESP size in exact sectors because util-linux 2.42
    # rejects binary-size suffixes while parsing an sfdisk sector-unit script.
    return (
        "label: gpt\n"
        "unit: sectors\n\n"
        "start=2048, size=2097152, "
        "type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name=\"EFI System\"\n"
        "type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709, name=\"Aero7 root\"\n"
    )


def aero7_partition_append_table(
    start_sector: int, end_sector: int, sector_size: int
) -> tuple[str, int, int]:
    if sector_size <= 0:
        raise SafetyError("invalid logical sector size")
    alignment = max(1, (1024 * 1024) // sector_size)
    esp_sectors = align_up(ADVANCED_ESP_BYTES // sector_size, alignment)
    esp_start = align_up(start_sector, alignment)
    root_start = align_up(esp_start + esp_sectors, alignment)
    root_sectors = end_sector - root_start + 1
    if root_sectors * sector_size < MIN_ROOT_BYTES:
        raise SafetyError("selected region cannot fit the Aero7 EFI and root partitions")
    table = (
        f"start={esp_start}, size={esp_sectors}, type={EFI_SYSTEM_TYPE}, "
        'name="Aero7 EFI"\n'
        f"start={root_start}, size={root_sectors}, type={LINUX_ROOT_X86_64_TYPE}, "
        'name="Aero7 root"\n'
    )
    return table, esp_start, root_start


def wait_for_partitions_at_starts(
    device: str, starts: tuple[int, int], timeout: float = 15.0
) -> tuple[str, str]:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        disk_node = find_disk(query_lsblk(), device)
        if disk_node is not None:
            by_start = {
                int(node.get("start") or 0): str(node.get("path") or "")
                for node in flatten_devices(disk_node.get("children", []))
                if node.get("type") == "part"
            }
            paths = tuple(by_start.get(start, "") for start in starts)
            if all(path and Path(path).is_block_device() for path in paths):
                return paths[0], paths[1]
        time.sleep(0.25)
    raise RuntimeError("new Aero7 partition devices did not appear in time")


def append_aero7_partitions(
    device: str,
    start_sector: int,
    end_sector: int,
    sector_size: int,
    runner: CommandRunner,
) -> tuple[str, str]:
    table, esp_start, root_start = aero7_partition_append_table(
        start_sector, end_sector, sector_size
    )
    runner.run(
        [
            "sfdisk",
            "--no-act",
            "--append",
            "--wipe",
            "never",
            "--wipe-partitions",
            "never",
            device,
        ],
        input_text=table,
    )
    runner.run(
        ["sfdisk", "--append", "--wipe", "never", "--wipe-partitions", "never", device],
        input_text=table,
    )
    runner.run(["udevadm", "settle"])
    return wait_for_partitions_at_starts(device, (esp_start, root_start))


def prepare_advanced_target(
    plan: dict[str, Any], current: dict[str, Any], runner: CommandRunner
) -> tuple[str, str]:
    device = str(plan["device"])
    sector_size = int(current.get("log-sec") or 512)
    target_kind = str(plan["target_kind"])

    if target_kind == "free":
        start_sector = int(plan["start_sector"])
        requested_bytes = int(
            plan.get("install_region_size_bytes") or plan["region_size_bytes"]
        )
        end_sector = start_sector + requested_bytes // sector_size - 1
    elif target_kind == "reuse_partition":
        start_sector = int(plan["partition_start_sector"])
        size_sectors = int(plan["partition_size_sectors"])
        end_sector = start_sector + size_sectors - 1
        runner.run(
            ["sfdisk", "--delete", device, str(plan["partition_number"])]
        )
        runner.run(["udevadm", "settle"])
    elif target_kind == "shrink_ntfs":
        partition = str(plan["partition_device"])
        number = int(plan["partition_number"])
        start_sector = int(plan["partition_start_sector"])
        original_sectors = int(plan["partition_size_sectors"])
        final_partition_bytes = int(plan["shrink_size_bytes"])
        final_partition_sectors = final_partition_bytes // sector_size
        if final_partition_sectors <= 0:
            raise SafetyError("invalid requested Windows partition size")
        filesystem_bytes = final_partition_bytes - 16 * 1024**2
        if filesystem_bytes <= 0:
            raise SafetyError("invalid requested NTFS filesystem size")

        runner.run(["ntfsresize", "--check", partition])
        runner.run(
            [
                "ntfsresize",
                "--no-action",
                "--size",
                str(filesystem_bytes),
                partition,
            ]
        )
        runner.run(
            [
                "ntfsresize",
                "--no-progress-bar",
                "--size",
                str(filesystem_bytes),
                partition,
            ]
        )
        new_end = start_sector + final_partition_sectors - 1
        runner.run(
            [
                "parted",
                "--script",
                device,
                "unit",
                "s",
                "resizepart",
                str(number),
                f"{new_end}s",
            ]
        )
        runner.run(["udevadm", "settle"])
        start_sector = align_up(new_end + 1, max(1, (1024 * 1024) // sector_size))
        end_sector = int(plan["partition_start_sector"]) + original_sectors - 1
    else:
        raise SafetyError("unsupported advanced target action")

    esp, root = append_aero7_partitions(
        device, start_sector, end_sector, sector_size, runner
    )
    runner.run(["wipefs", "--all", "--force", esp])
    runner.run(["wipefs", "--all", "--force", root])
    runner.run(["mkfs.fat", "-F", "32", "-n", "AERO7_ESP", esp])
    runner.run(["mkfs.ext4", "-F", "-L", "AERO7_ROOT", root])
    return esp, root


def install_variant(path: Path = INSTALL_VARIANT_FILE) -> str:
    try:
        variant = path.read_text(encoding="utf-8").strip()
    except FileNotFoundError:
        variant = "online"
    if variant not in {"online", "offline"}:
        raise SafetyError(f"unsupported installer variant: {variant or 'empty'}")
    return variant


def verified_offline_package_files(
    package_dir: Path = OFFLINE_BASE_PACKAGE_DIR,
    manifest_path: Path = OFFLINE_BASE_MANIFEST,
    manifest_prefix: str = "offline-packages/base/",
) -> list[Path]:
    if not package_dir.is_dir() or not manifest_path.is_file():
        raise SafetyError("the offline package bundle is missing")
    expected: dict[str, str] = {}
    for raw in manifest_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split(maxsplit=1)
        if len(fields) != 2 or not re.fullmatch(r"[0-9a-f]{64}", fields[0]):
            raise SafetyError("the offline package manifest is invalid")
        relative_path = fields[1]
        if not relative_path.startswith(manifest_prefix):
            raise SafetyError("the offline package manifest contains an unsafe path")
        package_name = relative_path.removeprefix(manifest_prefix)
        if not re.fullmatch(r"[A-Za-z0-9@+_.:-]+\.pkg\.tar\.(?:zst|xz)", package_name):
            raise SafetyError("the offline package manifest contains an invalid package")
        if package_name in expected:
            raise SafetyError("the offline package manifest contains a duplicate")
        expected[package_name] = fields[0]
    if not expected:
        raise SafetyError("the offline package manifest is empty")
    actual = {path.name for path in package_dir.glob("*.pkg.tar.*")}
    if actual != set(expected):
        raise SafetyError("the offline package files do not match their manifest")
    package_files: list[Path] = []
    for package_name, expected_hash in expected.items():
        package_path = package_dir / package_name
        digest = hashlib.sha256()
        with package_path.open("rb") as package_file:
            for chunk in iter(lambda: package_file.read(1024 * 1024), b""):
                digest.update(chunk)
        if digest.hexdigest() != expected_hash:
            raise SafetyError(f"offline package checksum failed: {package_name}")
        package_files.append(package_path)
    return package_files


def pacstrap_arguments(
    target: Path,
    packages: Iterable[str],
    offline_packages: Iterable[Path] | None = None,
) -> list[str]:
    # Keep pacstrap's documented default: copy the live environment's fully
    # initialized signing keyring into the target before package installation.
    if offline_packages is not None:
        return ["pacstrap", "-U", str(target), *(str(path) for path in offline_packages)]
    return ["pacstrap", str(target), *packages]


def pacstrap_download_stage_percent(log_path: Path, cache_path: Path) -> int | None:
    """Measure pacstrap download progress from pacman's total and cache files.

    Pacman does not expose structured progress to pacstrap. Its log does expose
    the transaction's total download size, while completed and partial package
    files accumulate in the target cache. Reserve the final ten percent for
    signature verification, extraction, and package hooks.
    """
    try:
        log_text = log_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    matches = re.findall(
        r"Total Download Size:\s+([0-9]+(?:\.[0-9]+)?)\s+(KiB|MiB|GiB)",
        log_text,
    )
    if not matches:
        return None
    amount, unit = matches[-1]
    multiplier = {
        "KiB": 1024,
        "MiB": 1024**2,
        "GiB": 1024**3,
    }[unit]
    total_bytes = float(amount) * multiplier
    if total_bytes <= 0:
        return None
    try:
        downloaded_bytes = sum(
            entry.stat().st_size for entry in cache_path.iterdir() if entry.is_file()
        )
    except OSError:
        return None
    return min(90, max(0, int(downloaded_bytes * 90 / total_bytes)))


def ensure_install_network(timeout: int = 45) -> None:
    """Fail before disk changes when the network cannot reach package mirrors."""
    if timeout <= 0:
        raise ValueError("network timeout must be positive")

    connected = subprocess.run(
        ["nm-online", "--quiet", "--timeout", str(timeout)],
        check=False,
        capture_output=True,
        text=True,
    )
    if connected.returncode != 0:
        raise SafetyError(
            "no usable network connection was detected. Connect the VM network "
            "adapter, make sure Link up and DHCP are enabled, then restart Setup. "
            "The target disk was not changed"
        )

    for host in PACKAGE_MIRROR_HOSTS:
        try:
            resolved = subprocess.run(
                ["getent", "ahostsv4", host],
                check=False,
                capture_output=True,
                text=True,
                timeout=5,
            )
        except subprocess.TimeoutExpired:
            continue
        if resolved.returncode == 0 and resolved.stdout.strip():
            return

    raise SafetyError(
        "the network is connected, but DNS could not resolve the Arch package "
        "mirrors. Check the VM DNS and gateway settings, then restart Setup. "
        "The target disk was not changed"
    )


def wait_for_partitions(paths: Iterable[str], timeout: float = 15.0) -> None:
    deadline = time.monotonic() + timeout
    pending = list(paths)
    while time.monotonic() < deadline:
        if all(Path(path).is_block_device() for path in pending):
            return
        time.sleep(0.25)
    raise RuntimeError("partition devices did not appear in time")


def copy_payload(target: Path) -> None:
    payloads = {
        Path("/usr/bin/aero7-installer"): target / "usr/bin/aero7-installer",
        Path("/usr/lib/aero7/aero7-install-backend"): target / "usr/lib/aero7/aero7-install-backend",
        Path("/usr/lib/aero7/aero7_shell_adapter.py"): target / "usr/lib/aero7/aero7_shell_adapter.py",
        Path("/usr/lib/aero7/aero7-kiosk-launch"): target / "usr/lib/aero7/aero7-kiosk-launch",
        DIAGNOSTIC_COLLECTOR: target / DIAGNOSTIC_COLLECTOR.relative_to("/"),
        Path("/usr/lib/systemd/system/aero7-diagnostic-collect.service"): target / "usr/lib/systemd/system/aero7-diagnostic-collect.service",
        Path("/usr/lib/systemd/system/aero7-diagnostic-collect.timer"): target / "usr/lib/systemd/system/aero7-diagnostic-collect.timer",
        Path("/usr/lib/systemd/user/aero7-diagnostic-session.service"): target / "usr/lib/systemd/user/aero7-diagnostic-session.service",
        Path("/usr/lib/systemd/user/aero7-diagnostic-session.timer"): target / "usr/lib/systemd/user/aero7-diagnostic-session.timer",
        Path("/etc/systemd/journald.conf.d/50-aero7-test-logging.conf"): target / "etc/systemd/journald.conf.d/50-aero7-test-logging.conf",
        Path("/usr/share/aero7/sources.lock"): target / "usr/share/aero7/sources.lock",
        Path("/usr/share/aero7/oobe/aero7-oobe.service"): target / "etc/systemd/system/aero7-oobe.service",
        SDDM_BRANDING: target / SDDM_BRANDING.relative_to("/"),
        SDDM_BACKGROUND: target / SDDM_BACKGROUND.relative_to("/"),
    }
    for source, destination in payloads.items():
        if not source.is_file():
            raise RuntimeError(f"required installed-system payload is missing: {source}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)

    shell_source = Path("/usr/share/aero7/source")
    shell_target = target / SHELL_INSTALLER.parent.relative_to("/")
    if not (shell_source / "install.sh").is_file():
        raise RuntimeError(f"Aero7-shell source payload is missing: {shell_source}")
    shutil.copytree(shell_source, shell_target, symlinks=True, dirs_exist_ok=True)
    ensure_shell_payload_modes(shell_target)


def ensure_shell_payload_modes(shell_root: Path) -> None:
    """Restore executable modes normalized by Archiso's airootfs overlay."""
    for relative_path in SHELL_EXECUTABLES:
        executable = shell_root / relative_path
        if not executable.is_file():
            raise RuntimeError(f"Aero7-shell executable payload is missing: {executable}")
        executable.chmod(0o755)


def brand_sddm_themes(
    themes_root: Path = Path("/usr/share/sddm/themes"),
    branding_source: Path = SDDM_BRANDING,
    background_source: Path = SDDM_BACKGROUND,
) -> list[Path]:
    """Replace upstream login branding and background with Aero7 artwork."""
    if not branding_source.is_file():
        raise RuntimeError(f"Aero7 SDDM branding is missing: {branding_source}")
    if not background_source.is_file():
        raise RuntimeError(f"Aero7 SDDM background is missing: {background_source}")
    if not themes_root.is_dir():
        return []

    branded: list[Path] = []
    for main_qml in sorted(themes_root.glob("*/Main.qml")):
        contents = main_qml.read_text(encoding="utf-8")
        upstream_reference = "Assets/branding-white.png"
        branded_reference = "Assets/aero7-branding.png"
        if (upstream_reference not in contents
                and branded_reference not in contents):
            continue
        assets = main_qml.parent / "Assets"
        assets.mkdir(parents=True, exist_ok=True)
        destination = assets / "aero7-branding.png"
        shutil.copy2(branding_source, destination)
        main_qml.write_text(
            contents.replace(upstream_reference, branded_reference),
            encoding="utf-8",
        )
        (assets / "branding-white.png").unlink(missing_ok=True)
        for background_name in (
            "background", "default-background", "bgtexture.jpg", "preview.png"
        ):
            shutil.copy2(background_source, main_qml.parent / background_name)
        metadata = main_qml.parent / "metadata.desktop"
        if metadata.is_file():
            metadata.write_text(
                metadata.read_text(encoding="utf-8").replace(
                    "Windows 7-like", "Aero7-inspired"
                ),
                encoding="utf-8",
            )
        branded.append(main_qml.parent)
    return branded


def brand_plasma_look_and_feel(
    themes_root: Path = Path("/usr/share/plasma/look-and-feel"),
    branding_source: Path = SDDM_BRANDING,
) -> list[Path]:
    """Replace the upstream logout/splash watermark with Aero7 branding.

    AeroThemePlasma's authui7 package ships a bitmap product watermark and
    screenshots that are inappropriate for an Aero7 release. Keep its layout
    and controls, point every QML watermark reference at project-owned artwork,
    remove the unused upstream bitmap/previews, and sanitize the visible
    package metadata.
    """
    if not branding_source.is_file():
        raise RuntimeError(f"Aero7 look-and-feel branding is missing: {branding_source}")
    if not themes_root.is_dir():
        return []

    branded: list[Path] = []
    for package_root in sorted(path for path in themes_root.iterdir() if path.is_dir()):
        contents_root = package_root / "contents"
        images = contents_root / "images"
        upstream_watermark = images / "watermark.png"
        if not upstream_watermark.is_file():
            continue

        qml_files = sorted(contents_root.glob("**/*.qml"))
        referenced = [
            qml
            for qml in qml_files
            if "../images/watermark.png" in qml.read_text(encoding="utf-8")
        ]
        if not referenced:
            continue

        destination = images / "aero7-watermark.png"
        shutil.copy2(branding_source, destination)
        for qml in referenced:
            qml.write_text(
                qml.read_text(encoding="utf-8").replace(
                    "../images/watermark.png", "../images/aero7-watermark.png"
                ),
                encoding="utf-8",
            )
        upstream_watermark.unlink()

        previews = contents_root / "previews"
        for preview_name in ("preview.png", "fullscreenpreview.jpg"):
            (previews / preview_name).unlink(missing_ok=True)

        metadata = package_root / "metadata.json"
        if metadata.is_file():
            metadata.write_text(
                metadata.read_text(encoding="utf-8").replace("Windows 7", "Aero7"),
                encoding="utf-8",
            )
        branded.append(package_root)
    return branded


def brand_plasma_lock_screen(
    shells_root: Path = Path("/usr/share/plasma/shells"),
    branding_source: Path = SDDM_BRANDING,
) -> list[Path]:
    """Apply Aero7 branding and readable labels to AeroShell lock screens."""
    if not branding_source.is_file():
        raise RuntimeError(f"Aero7 lock-screen branding is missing: {branding_source}")
    if not shells_root.is_dir():
        return []

    branded: list[Path] = []
    for shell_root in sorted(path for path in shells_root.iterdir() if path.is_dir()):
        contents_root = shell_root / "contents"
        auth_qml = contents_root / "lockscreen/AuthUI.qml"
        button_qml = contents_root / "components/GenericButton.qml"
        branding = contents_root / "images/branding.png"
        if not auth_qml.is_file() or not button_qml.is_file() or not branding.is_file():
            continue
        auth_contents = auth_qml.read_text(encoding="utf-8")
        branding_marker = '        source: "../images/branding.png"\n'
        if branding_marker not in auth_contents:
            continue

        shutil.copy2(branding_source, branding)
        if "        fillMode: Image.PreserveAspectFit\n" not in auth_contents:
            auth_contents = auth_contents.replace(
                branding_marker,
                branding_marker
                + "        width: Math.min(350, parent.width - 40)\n"
                + "        height: width / 7\n"
                + "        fillMode: Image.PreserveAspectFit\n"
                + "        smooth: true\n"
                + "        mipmap: true\n",
                1,
            )
            auth_qml.write_text(auth_contents, encoding="utf-8")
        button_contents = button_qml.read_text(encoding="utf-8")
        label_marker = """        id: btnLabel

        anchors.fill: parent
"""
        if label_marker not in button_contents:
            raise RuntimeError(
                f"AeroShell lock-screen button layout changed unexpectedly: {button_qml}"
            )
        if "        color: \"white\"\n" not in button_contents:
            button_contents = button_contents.replace(
                label_marker,
                """        id: btnLabel
        color: "white"

        anchors.fill: parent
""",
                1,
            )
            button_qml.write_text(button_contents, encoding="utf-8")
        branded.append(shell_root)
    return branded


def write_target_os_release(target: Path) -> Path:
    """Install a durable Aero7 system identity while retaining Arch lineage."""
    os_release_contents = (
        'NAME="Aero7"\n'
        'PRETTY_NAME="Aero7 Beta 2 Test"\n'
        "ID=aero7\n"
        "ID_LIKE=arch\n"
        'VERSION="Beta 2 Test"\n'
        'VERSION_ID="0.2.0-beta.2-test"\n'
        "VERSION_CODENAME=beta\n"
        "VARIANT_ID=beta\n"
        "BUILD_ID=rolling\n"
        'ANSI_COLOR="38;2;23;147;209"\n'
        'HOME_URL="https://github.com/aero7-open-project/aero7"\n'
        'DOCUMENTATION_URL="https://github.com/aero7-open-project/aero7/wiki"\n'
        'SUPPORT_URL="https://github.com/aero7-open-project/aero7/issues"\n'
        'BUG_REPORT_URL="https://github.com/aero7-open-project/aero7/issues"\n'
        "LOGO=aero7\n"
    )
    lsb_release_contents = (
        "DISTRIB_ID=Aero7\n"
        "DISTRIB_RELEASE=0.2.0-beta.2-test\n"
        "DISTRIB_CODENAME=beta\n"
        'DISTRIB_DESCRIPTION="Aero7 Beta 2 Test"\n'
    )

    identity_root = target / "usr/share/aero7/identity"
    identity_root.mkdir(parents=True, exist_ok=True)
    identity_files = {
        "os-release": os_release_contents,
        "lsb-release": lsb_release_contents,
        "aero7-release": "Aero7 Beta 2 Test\n",
        "issue": "Aero7 Beta 2 Test \\r (\\l)\n",
        "issue.net": "Aero7 Beta 2 Test\n",
    }
    for name, contents in identity_files.items():
        path = identity_root / name
        path.write_text(contents, encoding="utf-8")
        path.chmod(0o644)

    apply_identity = target / "usr/local/lib/aero7/apply-system-identity"
    apply_identity.parent.mkdir(parents=True, exist_ok=True)
    apply_identity.write_text(
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        'identity_root="/usr/share/aero7/identity"\n'
        "rm -f /etc/os-release /usr/lib/os-release /etc/arch-release\n"
        'install -Dm0644 "$identity_root/os-release" /etc/os-release\n'
        'install -Dm0644 "$identity_root/os-release" /usr/lib/os-release\n'
        'install -Dm0644 "$identity_root/lsb-release" /etc/lsb-release\n'
        'install -Dm0644 "$identity_root/aero7-release" /etc/aero7-release\n'
        'install -Dm0644 "$identity_root/issue" /etc/issue\n'
        'install -Dm0644 "$identity_root/issue.net" /etc/issue.net\n',
        encoding="utf-8",
    )
    apply_identity.chmod(0o755)

    hook = target / "usr/share/libalpm/hooks/aero7-system-identity.hook"
    hook.parent.mkdir(parents=True, exist_ok=True)
    hook.write_text(
        "[Trigger]\n"
        "Operation = Install\n"
        "Operation = Upgrade\n"
        "Type = Path\n"
        "Target = usr/lib/os-release\n"
        "Target = etc/arch-release\n\n"
        "[Action]\n"
        "Description = Restoring Aero7 system identity...\n"
        "When = PostTransaction\n"
        "Exec = /usr/local/lib/aero7/apply-system-identity\n",
        encoding="utf-8",
    )
    hook.chmod(0o644)

    for destination in (
        target / "etc/os-release",
        target / "usr/lib/os-release",
    ):
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.is_symlink() or destination.exists():
            destination.unlink()
        destination.write_text(os_release_contents, encoding="utf-8")
        destination.chmod(0o644)
    compatibility_destinations = {
        target / "etc/lsb-release": lsb_release_contents,
        target / "etc/aero7-release": "Aero7 Beta 2 Test\n",
        target / "etc/issue": "Aero7 Beta 2 Test \\r (\\l)\n",
        target / "etc/issue.net": "Aero7 Beta 2 Test\n",
    }
    for destination, contents in compatibility_destinations.items():
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(contents, encoding="utf-8")
        destination.chmod(0o644)
    (target / "etc/arch-release").unlink(missing_ok=True)
    return target / "etc/os-release"


def preserve_live_install_logs(
    target: Path,
    sources: Iterable[Path] | None = None,
) -> list[Path]:
    """Copy live-media diagnostics into the installed system before unmount."""
    capture_live_system = sources is None
    if sources is None:
        sources = (
            INSTALLER_LOG,
            STORAGE_ACTIONS_LOG,
            PARTITION_TABLE_BACKUP,
        )
    destination_root = target / "var/log"
    destination_root.mkdir(parents=True, exist_ok=True)
    preserved: list[Path] = []
    for source in sources:
        if not source.is_file():
            continue
        destination = destination_root / source.name
        shutil.copy2(source, destination)
        destination.chmod(0o600)
        preserved.append(destination)
    if capture_live_system:
        captures = (
            (
                "aero7-live-media-journal.log",
                ["journalctl", "--boot=0", "--no-pager", "-o", "short-precise"],
            ),
            ("aero7-live-media-dmesg.log", ["dmesg", "--ctime"]),
            (
                "aero7-live-media-installer-service.log",
                ["systemctl", "status", "aero7-installer.service", "--no-pager"],
            ),
        )
        for name, argv in captures:
            destination = destination_root / name
            with destination.open("w", encoding="utf-8") as output:
                try:
                    subprocess.run(
                        argv,
                        check=False,
                        stdout=output,
                        stderr=subprocess.STDOUT,
                        text=True,
                    )
                except OSError as error:
                    output.write(f"Could not capture {' '.join(argv)}: {error}\n")
            destination.chmod(0o600)
            preserved.append(destination)
    return preserved


def configure_one_time_autologin(
    username: str,
    config_path: Path = FIRST_LOGIN_CONFIG,
    session_root: Path = Path("/usr/share/wayland-sessions"),
    systemd_root: Path = Path("/etc/systemd/system"),
) -> str:
    """Prepare SDDM for the first desktop handoff only.

    A self-disabling systemd timer removes this drop-in after SDDM has read it,
    so the first desktop opens without asking for the password while later
    boots return to the normal greeter.
    """
    if not re.fullmatch(r"[a-z_][a-z0-9_-]{1,30}", username):
        raise SafetyError("invalid username for first-login autologin")

    candidates = (
        "aero7.desktop",
        "aero7-safe.desktop",
        "aerothemeplasma.desktop",
        "aerothemeplasmawayland.desktop",
        "plasma.desktop",
    )
    session = next((name for name in candidates if (session_root / name).is_file()), "")
    if not session:
        raise RuntimeError("no supported Aero7/Plasma Wayland session is installed")

    config_path.parent.mkdir(parents=True, exist_ok=True)
    config_path.write_text(
        "[Autologin]\n"
        f"User={username}\n"
        f"Session={session}\n"
        "Relogin=false\n",
        encoding="utf-8",
    )
    config_path.chmod(0o644)

    systemd_root.mkdir(parents=True, exist_ok=True)
    cleanup_service = systemd_root / "aero7-first-login-cleanup.service"
    cleanup_service.write_text(
        "[Unit]\n"
        "Description=Remove Aero7 one-time automatic login\n\n"
        "[Service]\n"
        "Type=oneshot\n"
        f"ExecStart=/usr/bin/rm -f {config_path}\n"
        f"ExecStartPost=/usr/bin/systemctl disable {FIRST_LOGIN_CLEANUP_TIMER}\n",
        encoding="utf-8",
    )
    cleanup_service.chmod(0o644)

    cleanup_timer = systemd_root / FIRST_LOGIN_CLEANUP_TIMER
    cleanup_timer.write_text(
        "[Unit]\n"
        "Description=Expire Aero7 one-time automatic login\n\n"
        "[Timer]\n"
        "OnActiveSec=45s\n"
        "AccuracySec=1s\n"
        "Persistent=false\n"
        "Unit=aero7-first-login-cleanup.service\n\n"
        "[Install]\n"
        "WantedBy=timers.target\n",
        encoding="utf-8",
    )
    cleanup_timer.chmod(0o644)
    return session


def configure_diagnostic_logging(
    username: str,
    state_path: Path = DIAGNOSTIC_USER_FILE,
) -> Path:
    """Bind automatic physical-install diagnostics to the OOBE account."""
    if not re.fullmatch(r"[a-z_][a-z0-9_-]{1,30}", username):
        raise SafetyError("invalid diagnostic username")
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(username + "\n", encoding="utf-8")
    state_path.chmod(0o600)
    return state_path


def enable_plymouth_hook(contents: str) -> str:
    updated_lines: list[str] = []
    hooks_found = False
    for line in contents.splitlines():
        match = re.match(r"^(HOOKS=\()([^)]*)(\).*)$", line)
        if not match:
            updated_lines.append(line)
            continue
        hooks_found = True
        hooks = match.group(2).split()
        if "plymouth" not in hooks:
            insert_at = hooks.index("udev") + 1 if "udev" in hooks else 1
            hooks.insert(insert_at, "plymouth")
        updated_lines.append(f"{match.group(1)}{' '.join(hooks)}{match.group(3)}")
    if not hooks_found:
        raise RuntimeError("could not find HOOKS in the target mkinitcpio configuration")
    return "\n".join(updated_lines) + "\n"


def configure_plymouth_hold(
    target: Path, seconds: int = PLYMOUTH_HOLD_SECONDS
) -> Path:
    """Keep the unchanged Plymouth theme visible long enough to complete."""
    if not 0 <= seconds <= 30:
        raise ValueError("Plymouth hold duration must be between 0 and 30 seconds")
    drop_in = (
        target
        / "etc/systemd/system/plymouth-quit.service.d/aero7-hold.conf"
    )
    drop_in.parent.mkdir(parents=True, exist_ok=True)
    drop_in.write_text(
        f"[Service]\nExecStartPre=/usr/bin/sleep {seconds}\n",
        encoding="utf-8",
    )
    drop_in.chmod(0o644)
    return drop_in


def configure_target_plymouth(target: Path, runner: CommandRunner) -> None:
    theme_source = Path("/usr/share/plymouth/themes/PlymouthVista")
    theme_target = target / "usr/share/plymouth/themes/PlymouthVista"
    if not (theme_source / "PlymouthVista.plymouth").is_file():
        raise RuntimeError("the pinned PlymouthVista payload is missing from the live image")
    shutil.copytree(theme_source, theme_target, symlinks=True, dirs_exist_ok=True)

    plymouth_conf = target / "etc/plymouth/plymouthd.conf"
    plymouth_conf.parent.mkdir(parents=True, exist_ok=True)
    plymouth_conf.write_text("[Daemon]\nTheme=PlymouthVista\nShowDelay=0\n", encoding="utf-8")
    configure_plymouth_hold(target)

    mkinitcpio = target / "etc/mkinitcpio.conf"
    contents = mkinitcpio.read_text(encoding="utf-8")
    mkinitcpio.write_text(enable_plymouth_hook(contents), encoding="utf-8")
    runner.run(["arch-chroot", str(target), "mkinitcpio", "-P"])


def shell_image_mode_arguments(username: str) -> list[str]:
    arguments = [
        "env",
        f"AERO7_IMAGE_MODE_GUARD={IMAGE_MODE_GUARD}",
        "AERO7_WALLPAPER=aero7-background.png",
        str(SHELL_INSTALLER),
        "--backend-run",
        "--image-mode",
        "--target-user",
        username,
        "--non-interactive",
        "--yes",
        "--plain",
        "--quiet",
        "--resume",
        "--no-reboot",
        "--binary-packages",
        "--replace-layout",
    ]
    for stage in (
        "20-system-update",
        "30-base-dependencies",
        "50-yay",
        "55-binary-repository",
        "60-aeroshell",
        "100-plymouth",
        "120-wine",
    ):
        arguments.extend(("--skip-stage", stage))
    return arguments


def enforce_light_desktop_defaults(username: str, runner: CommandRunner) -> None:
    """Pin a light Aero palette before the first graphical login starts.

    The shell installer also schedules a live Plasma theme pass. These static
    settings prevent the global look-and-feel package from showing a dark
    Dolphin window while that first-login pass waits for plasmashell.
    """
    if not re.fullmatch(r"[a-z_][a-z0-9_-]{1,30}", username):
        raise SafetyError("invalid username for desktop defaults")

    home = f"/home/{username}"
    config_home = f"{home}/.config"
    runner.run(
        ["install", "-d", "-m", "0755", "-o", username, "-g", username,
         config_home, f"{config_home}/kdedefaults", f"{config_home}/Kvantum"]
    )
    command_prefix = [
        "runuser", "--user", username, "--", "env", f"HOME={home}",
        f"XDG_CONFIG_HOME={config_home}", "kwriteconfig6",
    ]

    light_values = {
        "Colors:Button": {
            "BackgroundAlternate": "227,227,227",
            "BackgroundNormal": "240,240,240",
            "ForegroundNormal": "0,0,0",
        },
        "Colors:Complementary": {
            "BackgroundAlternate": "247,247,247",
            "BackgroundNormal": "240,240,240",
            "ForegroundNormal": "0,0,0",
        },
        "Colors:View": {
            "BackgroundAlternate": "247,247,247",
            "BackgroundNormal": "255,255,255",
            "ForegroundNormal": "0,0,0",
        },
        "Colors:Window": {
            "BackgroundAlternate": "227,227,227",
            "BackgroundNormal": "240,240,240",
            "ForegroundNormal": "0,0,0",
        },
    }
    settings: list[tuple[str, str, str, str]] = [
        ("kdeglobals", "General", "ColorScheme", "Aero7Light"),
        ("kdeglobals", "General", "AccentColor", "0,0,0,0"),
        ("kdeglobals", "General", "accentColorFromWallpaper", "false"),
        ("kdeglobals", "KDE", "LookAndFeelPackage", "authui7"),
        ("kdeglobals", "KDE", "widgetStyle", "kvantum"),
        ("plasmarc", "Theme", "name", "Aero7"),
        ("Kvantum/kvantum.kvconfig", "General", "theme", "Windows7Aero"),
        (f"{config_home}/kdedefaults/kdeglobals", "General", "ColorScheme", "Aero7Light"),
        (f"{config_home}/kdedefaults/kdeglobals", "KDE", "LookAndFeelPackage", "authui7"),
        (f"{config_home}/kdedefaults/plasmarc", "Theme", "name", "Aero7"),
    ]
    for group, values in light_values.items():
        for key, value in values.items():
            settings.append(("kdeglobals", group, key, value))
            settings.append(
                (f"{config_home}/kdedefaults/kdeglobals", group, key, value)
            )

    for file_name, group, key, value in settings:
        runner.run(
            [*command_prefix, "--file", file_name, "--group", group,
             "--key", key, value]
        )

    for key in ("Enabled", "First Use"):
        runner.run(
            [*command_prefix, "--file", "kwalletrc", "--group", "Wallet",
             "--key", key, "--type", "bool", "false"]
        )

    for file_name in (
        "plasmashellrc",
        f"{config_home}/kdedefaults/plasmashellrc",
    ):
        runner.run(
            [*command_prefix, "--file", file_name,
             "--group", "PlasmaViews", "--group", "Panel 2",
             "--key", "panelOpacity", "2"]
        )


def install(plan: dict[str, Any], confirm_device: str) -> None:
    enforce_execution_gate()
    if confirm_device != plan.get("device"):
        raise SafetyError("final confirmation does not match the selected device")

    nodes = query_lsblk()
    current = find_disk(nodes, confirm_device)
    if current is None:
        raise SafetyError("selected disk disappeared before installation")
    validate_plan(plan, current, live_sources())

    variant = install_variant()
    offline_base_packages: list[Path] | None = None
    if variant == "offline":
        # Validate every embedded package before wipefs/sfdisk. A damaged or
        # incomplete offline image must fail while the selected disk is intact.
        offline_base_packages = verified_offline_package_files()
    else:
        # The normal ISO retrieves the base system from signed Arch mirrors.
        # Verify connectivity before changing the selected disk.
        ensure_install_network()
    ensure_install_tools(plan)

    log_path = INSTALLER_LOG
    log_path.parent.mkdir(parents=True, exist_ok=True)
    runner = CommandRunner(log_path)
    device = confirm_device
    mounted = False
    partition_backup: Path | None = None

    if plan.get("layout") == ADVANCED_LAYOUT:
        partition_backup = backup_partition_table(device)

    try:
        copying_disk = ProgressPulse(
            INSTALL_STAGES[0], 2, 17, stage_start=0, stage_end=65
        )
        copying_disk.emit()
        if plan.get("layout") == SUPPORTED_LAYOUT:
            esp = partition_path(device, 1)
            root = partition_path(device, 2)
            runner.run(["wipefs", "--all", "--force", device])
            copying_disk.emit(10)
            runner.run(
                ["sfdisk", "--wipe", "always", device], input_text=partition_table()
            )
            copying_disk.emit(25)
            runner.run(["udevadm", "settle"])
            copying_disk.emit(35)
            wait_for_partitions((esp, root))
            copying_disk.emit(45)
            runner.run(["mkfs.fat", "-F", "32", "-n", "AERO7_ESP", esp])
            copying_disk.emit(55)
            runner.run(["mkfs.ext4", "-F", "-L", "AERO7_ROOT", root])
        else:
            copying_disk.emit(10)
            esp, root = prepare_advanced_target(plan, current, runner)
            copying_disk.emit(55)
        copying_disk.complete()

        copying_files = ProgressPulse(
            INSTALL_STAGES[1], 18, 27, stage_start=65, stage_end=100
        )
        copying_files.emit()

        TARGET_ROOT.mkdir(parents=True, exist_ok=True)
        runner.run(["mount", root, str(TARGET_ROOT)])
        mounted = True
        if partition_backup is not None:
            installed_backup = TARGET_ROOT / "var/log/aero7-partition-table-before.sfdisk"
            installed_backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(partition_backup, installed_backup)
        copying_files.emit(82)
        (TARGET_ROOT / "boot").mkdir(parents=True, exist_ok=True)
        runner.run(["mount", esp, str(TARGET_ROOT / "boot")])
        copying_files.complete()

        expanding = ProgressPulse(INSTALL_STAGES[2], 28, 53)
        expanding.emit()
        package_file = Path("/usr/share/aero7/base-packages.txt")
        packages = [
            line.strip()
            for line in package_file.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
        package_cache = TARGET_ROOT / "var/cache/pacman/pkg"

        def update_expanding_progress() -> None:
            measured = pacstrap_download_stage_percent(log_path, package_cache)
            if measured is None:
                expanding.advance()
            elif measured > expanding.stage_percent:
                expanding.emit(measured)
            elif measured >= 90:
                # Downloading is complete. Continue pulsing during signature
                # checks, extraction, initramfs generation, and package hooks.
                expanding.advance()
            else:
                # Re-emit unchanged measured progress as a liveness heartbeat.
                expanding.emit()

        with runner.progress_heartbeat(update_expanding_progress):
            runner.run(
                pacstrap_arguments(TARGET_ROOT, packages, offline_base_packages)
            )
        if offline_base_packages is not None:
            runner.run(
                ["arch-chroot", str(TARGET_ROOT), "pacman", "-Q", "--", *packages]
            )
        fstab = subprocess.run(
            ["genfstab", "-U", str(TARGET_ROOT)], check=True, capture_output=True, text=True
        ).stdout
        (TARGET_ROOT / "etc/fstab").write_text(fstab, encoding="utf-8")
        expanding.complete()

        features = ProgressPulse(INSTALL_STAGES[3], 54, 71)
        features.emit()
        with runner.progress_heartbeat(features.advance):
            configure_and_install(TARGET_ROOT, runner, AERO7_SHARE_DIR)
        features.complete()

        updates_boot = ProgressPulse(
            INSTALL_STAGES[4], 72, 83, stage_start=0, stage_end=45
        )
        updates_boot.emit()
        with runner.progress_heartbeat(updates_boot.advance):
            runner.run(["arch-chroot", str(TARGET_ROOT), "bootctl", "install"])
        partuuid = subprocess.run(
            ["blkid", "-s", "PARTUUID", "-o", "value", root],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        loader = TARGET_ROOT / "boot/loader"
        (loader / "entries").mkdir(parents=True, exist_ok=True)
        (loader / "loader.conf").write_text("default aero7.conf\ntimeout 3\neditor no\n", encoding="utf-8")
        (loader / "entries/aero7.conf").write_text(
            "title Aero7\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\n"
            f"options root=PARTUUID={partuuid} rw quiet splash plymouth.ignore-serial-consoles\n",
            encoding="utf-8",
        )
        updates_boot.complete()

        updates_settings = ProgressPulse(
            INSTALL_STAGES[5], 84, 95, stage_start=45, stage_end=100
        )
        updates_settings.emit()
        (TARGET_ROOT / "etc/hostname").write_text("aero7-pc\n", encoding="utf-8")
        write_target_os_release(TARGET_ROOT)
        locale = TARGET_ROOT / "etc/locale.gen"
        locale.write_text(locale.read_text(encoding="utf-8").replace("#en_US.UTF-8 UTF-8", "en_US.UTF-8 UTF-8"), encoding="utf-8")
        with runner.progress_heartbeat(updates_settings.advance):
            runner.run(["arch-chroot", str(TARGET_ROOT), "locale-gen"])
            (TARGET_ROOT / "etc/locale.conf").write_text("LANG=en_US.UTF-8\n", encoding="utf-8")
            copy_payload(TARGET_ROOT)
            updates_settings.advance()
            configure_target_plymouth(TARGET_ROOT, runner)
            runner.run(["arch-chroot", str(TARGET_ROOT), "systemctl", "enable", "NetworkManager.service"])
            runner.run(["arch-chroot", str(TARGET_ROOT), "systemctl", "enable", "ufw.service"])
            runner.run(["arch-chroot", str(TARGET_ROOT), "systemctl", "disable", "sddm.service"])
            runner.run(["arch-chroot", str(TARGET_ROOT), "systemctl", "enable", "aero7-oobe.service"])
        updates_settings.complete()

        completing = ProgressPulse(INSTALL_STAGES[6], 96, 100)
        completing.emit()
        (TARGET_ROOT / "var/lib/aero7").mkdir(parents=True, exist_ok=True)
        (TARGET_ROOT / "var/lib/aero7/install-source").write_text(
            "binary-packages-pinned\nfull-shell-stage-adapter=ready\n", encoding="utf-8"
        )
        completing.emit(35)
        with runner.progress_heartbeat(completing.advance):
            runner.run(["sync"])
        completing.complete()
    finally:
        if mounted:
            try:
                preserve_live_install_logs(TARGET_ROOT)
            except OSError as error:
                print(
                    f"warning: could not preserve live installer logs: {error}",
                    file=sys.stderr,
                    flush=True,
                )
            subprocess.run(["umount", "-R", str(TARGET_ROOT)], check=False)


def validate_oobe(plan: dict[str, Any]) -> None:
    username = str(plan.get("username") or "")
    hostname = str(plan.get("computer_name") or "")
    password = str(plan.get("password") or "")
    timezone = str(plan.get("timezone") or "")
    if not re.fullmatch(r"[a-z_][a-z0-9_-]{1,30}", username):
        raise SafetyError("invalid username")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]{0,62}", hostname):
        raise SafetyError("invalid computer name")
    if len(password) < 8 or "\n" in password or ":" in password:
        raise SafetyError("password does not meet OOBE requirements")
    if plan.get("update_preference") not in {"recommended", "notify", "manual"}:
        raise SafetyError("invalid update preference")
    if plan.get("network") not in {"wired", "skip", "home", "work", "public"}:
        raise SafetyError("invalid network choice")
    zone = (Path("/usr/share/zoneinfo") / timezone).resolve()
    if not zone.is_file() or Path("/usr/share/zoneinfo") not in zone.parents:
        raise SafetyError("invalid timezone")


def finalize_oobe(plan: dict[str, Any]) -> None:
    if os.geteuid() != 0:
        raise SafetyError("OOBE finalization must run as root")
    validate_oobe(plan)
    username = str(plan["username"])
    password = str(plan["password"])
    runner = CommandRunner(Path("/var/log/aero7-oobe.log"))
    state_dir = Path("/var/lib/aero7")
    state_dir.mkdir(parents=True, exist_ok=True)
    pending_user = state_dir / "pending-user"
    account_exists = subprocess.run(
        ["id", username], check=False, capture_output=True
    ).returncode == 0
    if account_exists:
        pending_name = pending_user.read_text(encoding="utf-8").strip() if pending_user.is_file() else ""
        if pending_name != username:
            raise SafetyError("requested user already exists")
    else:
        pending_user.write_text(username + "\n", encoding="utf-8")
        pending_user.chmod(0o600)

    event("progress", stage="Creating your account", percent=16)
    if not account_exists:
        runner.run(["useradd", "--create-home", "--groups", "wheel,audio,video,storage", "--shell", "/bin/bash", username])
    runner.run(["chpasswd"], input_text=f"{username}:{password}\n")
    sudoers = Path("/etc/sudoers.d/10-aero7-wheel")
    sudoers.write_text("%wheel ALL=(ALL:ALL) ALL\n", encoding="utf-8")
    sudoers.chmod(0o440)

    event("progress", stage="Applying your settings", percent=46)
    Path("/etc/hostname").write_text(str(plan["computer_name"]) + "\n", encoding="utf-8")
    zone = Path("/usr/share/zoneinfo") / str(plan["timezone"])
    localtime = Path("/etc/localtime")
    localtime.unlink(missing_ok=True)
    localtime.symlink_to(zone)
    runner.run(["hwclock", "--systohc"])

    settings = Path("/etc/aero7")
    settings.mkdir(parents=True, exist_ok=True)
    (settings / "update-preference.conf").write_text(
        f"preference={plan['update_preference']}\n", encoding="utf-8"
    )

    event("progress", stage="Preparing the Aero7 desktop", percent=62)
    if not SHELL_INSTALLER.is_file():
        raise RuntimeError(f"Aero7-shell image installer is missing: {SHELL_INSTALLER}")
    runner.run(shell_image_mode_arguments(username))
    brand_sddm_themes()
    brand_plasma_look_and_feel()
    brand_plasma_lock_screen()
    enforce_light_desktop_defaults(username, runner)
    configure_one_time_autologin(username)
    configure_diagnostic_logging(username)
    runner.run(["systemctl", "daemon-reload"])
    runner.run(["systemctl", "enable", "--now", FIRST_LOGIN_CLEANUP_TIMER])
    runner.run(["systemctl", "enable", "--now", DIAGNOSTIC_SYSTEM_TIMER])
    runner.run(["systemctl", "--global", "enable", *DIAGNOSTIC_USER_UNITS])
    runner.run([str(DIAGNOSTIC_COLLECTOR), "--system"])

    event("progress", stage="Preparing the Aero7 desktop", percent=92)
    avatar_source = Path("/usr/share/aero7-shell/avatars/aero7-user.png")
    if avatar_source.is_file():
        icon = Path("/var/lib/AccountsService/icons") / username
        account = Path("/var/lib/AccountsService/users") / username
        icon.parent.mkdir(parents=True, exist_ok=True)
        account.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(avatar_source, icon)
        account.write_text(f"[User]\nIcon={icon}\n", encoding="utf-8")

    marker = state_dir / "oobe-complete"
    marker.write_text(f"user={username}\n", encoding="utf-8")
    pending_user.unlink(missing_ok=True)
    runner.run(["systemctl", "disable", "aero7-oobe.service"])
    runner.run(["systemctl", "enable", "sddm.service"])
    event("progress", stage="Preparing the Aero7 desktop", percent=100)


def make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    list_parser = sub.add_parser("list-disks", help="list safe candidate disks")
    list_parser.add_argument("--json", action="store_true", required=True)

    validate_parser = sub.add_parser("validate-plan", help="revalidate a plan without modifying disks")
    validate_parser.add_argument("--plan", type=Path, required=True)

    install_parser = sub.add_parser("install", help="perform the guarded live-media install")
    install_parser.add_argument("--plan", type=Path, required=True)
    install_parser.add_argument("--confirm-device", required=True)
    install_parser.add_argument("--execute", action="store_true")

    storage_parser = sub.add_parser(
        "storage-action", help="perform a guarded advanced partition action"
    )
    storage_parser.add_argument("--plan", type=Path, required=True)
    storage_parser.add_argument("--confirm-device", required=True)
    storage_parser.add_argument("--execute", action="store_true")

    driver_parser = sub.add_parser(
        "load-driver", help="load a trusted storage kernel module from mounted media"
    )
    driver_parser.add_argument("--path", type=Path, required=True)
    driver_parser.add_argument("--execute", action="store_true")

    oobe_parser = sub.add_parser("oobe-finalize", help="apply first-boot account settings")
    oobe_parser.add_argument("--plan", type=Path, required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = make_parser().parse_args(argv)
    try:
        if args.command == "list-disks":
            print(json.dumps(candidate_disks(query_lsblk(), live_sources())))
        elif args.command == "validate-plan":
            plan = load_plan(args.plan)
            current = find_disk(query_lsblk(), str(plan.get("device") or ""))
            if current is None:
                raise SafetyError("selected disk is absent")
            validate_plan(plan, current, live_sources())
            event("status", message="disk plan is valid")
        elif args.command == "install":
            if not args.execute:
                raise SafetyError("--execute is required for real installation")
            install(load_plan(args.plan), args.confirm_device)
        elif args.command == "storage-action":
            if not args.execute:
                raise SafetyError("--execute is required for a storage action")
            apply_storage_action(load_plan(args.plan), args.confirm_device)
        elif args.command == "load-driver":
            if not args.execute:
                raise SafetyError("--execute is required to load a storage driver")
            load_storage_driver(args.path)
        elif args.command == "oobe-finalize":
            finalize_oobe(load_plan(args.plan))
        return 0
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError, RuntimeError) as error:
        event("status", message=f"Stopped safely: {error}")
        print(f"aero7 backend: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
