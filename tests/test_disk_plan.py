#!/usr/bin/env python3

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT / "backend"))

from aero7_install_backend import (  # noqa: E402
    ADVANCED_LAYOUT,
    CommandRunner,
    EFI_SYSTEM_TYPE,
    GUARD_TOKEN,
    MIN_DISK_BYTES,
    MIN_ADVANCED_REGION_BYTES,
    ProgressPulse,
    SUPPORTED_LAYOUT,
    SafetyError,
    adjacent_free_region,
    apply_storage_action,
    aero7_partition_append_table,
    backup_partition_table,
    brand_plasma_lock_screen,
    brand_plasma_look_and_feel,
    brand_sddm_themes,
    candidate_disks,
    configure_one_time_autologin,
    configure_plymouth_hold,
    ensure_shell_payload_modes,
    enable_plymouth_hook,
    ensure_install_network,
    ensure_install_tools,
    enforce_light_desktop_defaults,
    enforce_execution_gate,
    fingerprint,
    free_regions,
    install,
    live_sources,
    nest_block_devices,
    partition_fingerprint,
    partition_path,
    partition_table,
    pacstrap_arguments,
    pacstrap_download_stage_percent,
    preserve_live_install_logs,
    prepare_advanced_target,
    required_install_commands,
    running_from_live_installer,
    shell_image_mode_arguments,
    storage_targets,
    validate_storage_action,
    validate_oobe,
    validate_plan,
    write_target_os_release,
)
from aero7_shell_adapter import configure_and_install  # noqa: E402


class RecordingRunner:
    def __init__(self):
        self.calls = []

    def run(self, argv, *, input_text=None):
        self.calls.append((argv, input_text))


def disk(**overrides):
    value = {
        "path": "/dev/vda",
        "kname": "vda",
        "type": "disk",
        "size": 40 * 1024**3,
        "model": "QEMU HARDDISK",
        "serial": "AERO7-TEST",
        "ro": False,
        "rm": False,
        "maj:min": "252:0",
        "mountpoints": [None],
        "children": [],
    }
    value.update(overrides)
    return value


def plan_for(value):
    result = fingerprint(value)
    result["layout"] = SUPPORTED_LAYOUT
    return result


def gpt_disk_with_windows(**overrides):
    sector = 512
    gib = 1024**3
    value = disk(
        size=80 * gib,
        pttype="gpt",
        **{"log-sec": sector},
        children=[
            {
                "path": "/dev/vda1",
                "kname": "vda1",
                "type": "part",
                "size": 512 * 1024**2,
                "start": 2048,
                "partn": 1,
                "fstype": "vfat",
                "parttype": EFI_SYSTEM_TYPE,
                "partuuid": "ESP-PARTUUID",
                "uuid": "ESP-UUID",
                "partlabel": "EFI System Partition",
                "mountpoints": [None],
            },
            {
                "path": "/dev/vda3",
                "kname": "vda3",
                "type": "part",
                "size": 45 * gib,
                "start": 1050624,
                "partn": 3,
                "fstype": "ntfs",
                "parttype": "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7",
                "partuuid": "WINDOWS-PARTUUID",
                "uuid": "WINDOWS-UUID",
                "label": "Windows",
                "mountpoints": [None],
            },
        ],
    )
    value.update(overrides)
    return value


def advanced_plan(value, target):
    result = dict(target)
    result.update(fingerprint(value))
    result["layout"] = ADVANCED_LAYOUT
    return result


class DiskPlanTest(unittest.TestCase):
    def test_accepts_stable_unmounted_virtio_disk(self):
        value = disk()
        validate_plan(plan_for(value), value, set())

    def test_accepts_guarded_physical_whole_disk_paths(self):
        for path, kname, maj_min in (
            ("/dev/sda", "sda", "8:0"),
            ("/dev/nvme0n1", "nvme0n1", "259:0"),
            ("/dev/mmcblk0", "mmcblk0", "179:0"),
        ):
            with self.subTest(path=path):
                value = disk(path=path, kname=kname, **{"maj:min": maj_min})
                validate_plan(plan_for(value), value, set())

    def test_rejects_unsupported_whole_disk_path(self):
        value = disk(path="/dev/loop0", kname="loop0", **{"maj:min": "7:0"})
        with self.assertRaisesRegex(SafetyError, "unsupported disk path"):
            validate_plan(plan_for(value), value, set())

    def test_candidate_filter_rejects_unsafe_devices(self):
        safe = disk()
        mounted = disk(path="/dev/vdb", kname="vdb", **{"maj:min": "252:16"}, mountpoints=["/mnt"])
        readonly = disk(path="/dev/vdc", kname="vdc", **{"maj:min": "252:32"}, ro=True)
        removable = disk(path="/dev/vdd", kname="vdd", **{"maj:min": "252:48"}, rm=True)
        small = disk(path="/dev/vde", kname="vde", **{"maj:min": "252:64"}, size=MIN_DISK_BYTES - 1)
        result = candidate_disks([safe, mounted, readonly, removable, small], set())
        self.assertEqual([item["device"] for item in result], ["/dev/vda"])

    def test_rejects_live_source(self):
        value = disk()
        with self.assertRaisesRegex(SafetyError, "live installation media"):
            validate_plan(plan_for(value), value, {"/dev/vda"})

    def test_rejects_disk_containing_the_live_source_partition(self):
        value = disk(
            children=[
                {
                    "path": "/dev/vda2",
                    "type": "part",
                    "mountpoints": [None],
                }
            ]
        )
        with self.assertRaisesRegex(SafetyError, "live installation media"):
            validate_plan(plan_for(value), value, {"/dev/vda2"})

    def test_live_sources_include_ventoy_mapper_partition_and_usb_parent(self):
        def completed(stdout="", returncode=0):
            return SimpleNamespace(stdout=stdout, stderr="", returncode=returncode)

        def fake_run(argv, **_kwargs):
            if argv[0] == "findmnt" and argv[-1] == "/run/archiso/bootmnt":
                return completed("/dev/mapper/ventoy\n")
            if argv[0] == "findmnt":
                return completed()
            if argv[0] == "lsblk":
                return completed("/dev/dm-0\n/dev/sdb1\n/dev/sdb\n")
            raise AssertionError(argv)

        with patch("aero7_install_backend.subprocess.run", side_effect=fake_run):
            sources = live_sources()
        self.assertTrue({"/dev/dm-0", "/dev/sdb1", "/dev/sdb"} <= sources)

    def test_rejects_child_mount(self):
        value = disk(children=[{"path": "/dev/vda1", "type": "part", "mountpoints": ["/boot"]}])
        with self.assertRaisesRegex(SafetyError, "mounted"):
            validate_plan(plan_for(value), value, set())

    def test_rejects_fingerprint_change(self):
        original = disk()
        changed = deepcopy(original)
        changed["serial"] = "CHANGED"
        with self.assertRaisesRegex(SafetyError, "serial"):
            validate_plan(plan_for(original), changed, set())

    def test_storage_targets_expose_guarded_partition_actions(self):
        value = gpt_disk_with_windows()
        windows = value["children"][1]
        adjacent = adjacent_free_region(value, windows)
        self.assertIsNotNone(adjacent)
        targets = storage_targets(value, 0)
        windows_target = next(
            target for target in targets
            if target.get("partition_device") == "/dev/vda3"
        )
        esp_target = next(
            target for target in targets
            if target.get("partition_device") == "/dev/vda1"
        )
        self.assertTrue(windows_target["can_delete"])
        self.assertTrue(windows_target["can_extend"])
        self.assertGreater(windows_target["adjacent_free_size_bytes"], 1024**3)
        self.assertFalse(esp_target["can_delete"])
        self.assertFalse(esp_target["can_extend"])

    def test_delete_and_extend_plans_are_fingerprint_bound(self):
        value = gpt_disk_with_windows()
        target = next(
            item for item in storage_targets(value, 0)
            if item.get("partition_device") == "/dev/vda3"
        )
        delete_plan = {**target, "action": "delete"}
        partition, actual, adjacent = validate_storage_action(
            delete_plan, value, set()
        )
        self.assertEqual(partition["path"], "/dev/vda3")
        self.assertEqual(actual["filesystem"], "ntfs")
        self.assertIsNotNone(adjacent)

        extend_plan = {**target, "action": "extend", "amount_bytes": 2 * 1024**3}
        validate_storage_action(extend_plan, value, set())
        stale = deepcopy(value)
        stale["children"][1]["size"] += 1024**3
        with self.assertRaisesRegex(SafetyError, "fingerprint changed"):
            validate_storage_action(extend_plan, stale, set())

    def test_storage_delete_runs_only_after_gate_revalidation_and_backup(self):
        value = gpt_disk_with_windows()
        target = next(
            item for item in storage_targets(value, 0)
            if item.get("partition_device") == "/dev/vda3"
        )
        plan = {**target, "action": "delete"}
        runner = RecordingRunner()
        with (
            patch("aero7_install_backend.enforce_execution_gate"),
            patch("aero7_install_backend.query_lsblk", return_value=[value]),
            patch("aero7_install_backend.live_sources", return_value=set()),
            patch("aero7_install_backend.backup_partition_table") as backup,
            patch("aero7_install_backend.shutil.which", return_value="/usr/bin/tool"),
            patch("aero7_install_backend.CommandRunner", return_value=runner),
        ):
            apply_storage_action(plan, "/dev/vda")
        backup.assert_called_once_with("/dev/vda")
        self.assertEqual(
            runner.calls[0][0], ["sfdisk", "--delete", "/dev/vda", "3"]
        )

    def test_execution_gate_is_closed_by_default(self):
        with patch.dict("os.environ", {}, clear=True):
            with self.assertRaisesRegex(SafetyError, "guard token"):
                enforce_execution_gate()

    def test_live_installer_detection_accepts_ventoy_overlay_without_bootmnt_mount(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cmdline = root / "cmdline"
            hostname = root / "hostname"
            source_lock = root / "sources.lock"
            cmdline.write_text(
                "archisobasedir=aero7 archisosearchuuid=test quiet splash\n",
                encoding="utf-8",
            )
            hostname.write_text("aero7-setup\n", encoding="utf-8")
            source_lock.write_text("aero7_shell_commit=test\n", encoding="utf-8")
            with (
                patch("aero7_install_backend.PROC_CMDLINE", cmdline),
                patch("aero7_install_backend.LIVE_HOSTNAME", hostname),
                patch("aero7_install_backend.LIVE_SOURCE_LOCK", source_lock),
                patch(
                    "aero7_install_backend.subprocess.run",
                    return_value=SimpleNamespace(stdout="overlay\n", returncode=0),
                ),
            ):
                self.assertTrue(running_from_live_installer())

    def test_live_installer_detection_rejects_installed_root(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cmdline = root / "cmdline"
            hostname = root / "hostname"
            source_lock = root / "sources.lock"
            cmdline.write_text("root=UUID=test rw\n", encoding="utf-8")
            hostname.write_text("aero7-pc\n", encoding="utf-8")
            source_lock.write_text("aero7_shell_commit=test\n", encoding="utf-8")
            with (
                patch("aero7_install_backend.PROC_CMDLINE", cmdline),
                patch("aero7_install_backend.LIVE_HOSTNAME", hostname),
                patch("aero7_install_backend.LIVE_SOURCE_LOCK", source_lock),
                patch(
                    "aero7_install_backend.subprocess.run",
                    return_value=SimpleNamespace(stdout="ext4\n", returncode=0),
                ),
            ):
                self.assertFalse(running_from_live_installer())

    def test_live_installer_detection_fails_closed_without_findmnt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cmdline = root / "cmdline"
            hostname = root / "hostname"
            source_lock = root / "sources.lock"
            cmdline.write_text("archisobasedir=aero7\n", encoding="utf-8")
            hostname.write_text("aero7-setup\n", encoding="utf-8")
            source_lock.write_text("test\n", encoding="utf-8")
            with (
                patch("aero7_install_backend.PROC_CMDLINE", cmdline),
                patch("aero7_install_backend.LIVE_HOSTNAME", hostname),
                patch("aero7_install_backend.LIVE_SOURCE_LOCK", source_lock),
                patch(
                    "aero7_install_backend.subprocess.run",
                    side_effect=FileNotFoundError("findmnt"),
                ),
            ):
                self.assertFalse(running_from_live_installer())

    def test_execution_gate_accepts_booted_aero7_media_on_physical_hardware(self):
        with (
            patch.dict(
                "os.environ", {"AERO7_ALLOW_DESTRUCTIVE": GUARD_TOKEN}, clear=True
            ),
            patch("aero7_install_backend.os.geteuid", return_value=0),
            patch("aero7_install_backend.running_from_live_installer", return_value=True),
        ):
            enforce_execution_gate()

    def test_execution_gate_rejects_copied_backend_on_installed_system(self):
        with (
            patch.dict(
                "os.environ", {"AERO7_ALLOW_DESTRUCTIVE": GUARD_TOKEN}, clear=True
            ),
            patch("aero7_install_backend.os.geteuid", return_value=0),
            patch("aero7_install_backend.running_from_live_installer", return_value=False),
        ):
            with self.assertRaisesRegex(SafetyError, "booted Aero7 installation media"):
                enforce_execution_gate()

    def test_oobe_requires_safe_account_values(self):
        valid = {
            "username": "geko",
            "computer_name": "aero7-pc",
            "password": "correct-horse",
            "update_preference": "recommended",
            "timezone": "Europe/Amsterdam",
            "network": "public",
        }
        validate_oobe(valid)
        invalid = dict(valid, username="Geko Admin")
        with self.assertRaisesRegex(SafetyError, "username"):
            validate_oobe(invalid)

    def test_plymouth_hook_is_added_once_after_udev(self):
        original = "HOOKS=(base udev autodetect modconf kms block filesystems fsck)\n"
        updated = enable_plymouth_hook(original)
        self.assertIn("HOOKS=(base udev plymouth autodetect", updated)
        self.assertEqual(enable_plymouth_hook(updated), updated)

    def test_plymouth_hold_keeps_unchanged_theme_visible(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            drop_in = configure_plymouth_hold(target)
            self.assertEqual(drop_in.stat().st_mode & 0o777, 0o644)
            self.assertEqual(
                drop_in.read_text(encoding="utf-8"),
                "[Service]\nExecStartPre=/usr/bin/sleep 6\n",
            )
            with self.assertRaises(ValueError):
                configure_plymouth_hold(target, 31)

    def test_first_boot_shell_adapter_is_guarded_and_offline(self):
        arguments = shell_image_mode_arguments("geko")
        self.assertIn("AERO7_IMAGE_MODE_GUARD=YES-I-AM-IN-AERO7-FIRST-BOOT", arguments)
        self.assertIn("AERO7_WALLPAPER=aero7-background.png", arguments)
        self.assertIn("--image-mode", arguments)
        self.assertEqual(arguments[arguments.index("--target-user") + 1], "geko")
        skipped = [
            arguments[index + 1]
            for index, value in enumerate(arguments[:-1])
            if value == "--skip-stage"
        ]
        self.assertIn("20-system-update", skipped)
        self.assertNotIn("70-aero-applications", skipped)
        self.assertIn("100-plymouth", skipped)
        self.assertIn("120-wine", skipped)

    def test_first_boot_shell_payload_restores_executable_modes(self):
        with tempfile.TemporaryDirectory() as directory:
            shell_root = Path(directory)
            executable_paths = (
                "install.sh",
                "uninstall.sh",
                "update.sh",
                "commands/aero7",
                "commands/aero7-dir",
                "commands/aero7-ipconfig",
                "commands/aero7-systeminfo",
                "commands/aero7-winver",
            )
            for relative_path in executable_paths:
                path = shell_root / relative_path
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("#!/bin/sh\n", encoding="utf-8")
                path.chmod(0o644)

            ensure_shell_payload_modes(shell_root)

            for relative_path in executable_paths:
                self.assertEqual((shell_root / relative_path).stat().st_mode & 0o777, 0o755)

    def test_sddm_branding_replaces_upstream_windows_reference(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            theme = root / "themes/sddm-theme-mod"
            assets = theme / "Assets"
            assets.mkdir(parents=True)
            main_qml = theme / "Main.qml"
            main_qml.write_text(
                'Image { source: Qt.resolvedUrl("Assets/branding-white.png") }\n',
                encoding="utf-8",
            )
            metadata = theme / "metadata.desktop"
            metadata.write_text(
                "Description=Windows 7-like theme for SDDM\n", encoding="utf-8"
            )
            (assets / "branding-white.png").write_bytes(b"upstream branding")
            (theme / "background").write_bytes(b"upstream background")
            (theme / "default-background").write_bytes(b"upstream background")
            (theme / "preview.png").write_bytes(b"upstream preview")
            branding = root / "aero7-sddm-branding.png"
            branding.write_bytes(b"aero7 branding")
            background = root / "aero7-login-background.jpg"
            background.write_bytes(b"aero7 background")

            branded = brand_sddm_themes(root / "themes", branding, background)

            self.assertEqual(branded, [theme])
            self.assertIn("Assets/aero7-branding.png", main_qml.read_text(encoding="utf-8"))
            self.assertNotIn("branding-white.png", main_qml.read_text(encoding="utf-8"))
            self.assertEqual((assets / "aero7-branding.png").read_bytes(), b"aero7 branding")
            self.assertFalse((assets / "branding-white.png").exists())
            self.assertEqual((theme / "background").read_bytes(), b"aero7 background")
            self.assertEqual((theme / "default-background").read_bytes(), b"aero7 background")
            self.assertEqual((theme / "bgtexture.jpg").read_bytes(), b"aero7 background")
            self.assertEqual((theme / "preview.png").read_bytes(), b"aero7 background")
            self.assertNotIn("Windows 7", metadata.read_text(encoding="utf-8"))

    def test_sddm_branding_refreshes_prebranded_package_theme(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            theme = root / "themes/sddm-theme-mod"
            assets = theme / "Assets"
            assets.mkdir(parents=True)
            main_qml = theme / "Main.qml"
            main_qml.write_text(
                'Image { source: Qt.resolvedUrl("Assets/aero7-branding.png") }\n',
                encoding="utf-8",
            )
            (assets / "aero7-branding.png").write_bytes(b"old branding")
            branding = root / "aero7-sddm-branding.png"
            branding.write_bytes(b"new branding")
            background = root / "aero7-login-background.jpg"
            background.write_bytes(b"new background")

            branded = brand_sddm_themes(root / "themes", branding, background)

            self.assertEqual(branded, [theme])
            self.assertEqual(
                (assets / "aero7-branding.png").read_bytes(), b"new branding"
            )
            self.assertEqual((theme / "background").read_bytes(), b"new background")

    def test_plasma_logout_branding_replaces_upstream_watermark(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            package = root / "look-and-feel/authui7"
            images = package / "contents/images"
            logout = package / "contents/logout/Logout.qml"
            splash = package / "contents/splash/Splash.qml"
            previews = package / "contents/previews"
            images.mkdir(parents=True)
            logout.parent.mkdir(parents=True)
            splash.parent.mkdir(parents=True)
            previews.mkdir(parents=True)
            (images / "watermark.png").write_bytes(b"upstream")
            (previews / "preview.png").write_bytes(b"upstream preview")
            (previews / "fullscreenpreview.jpg").write_bytes(b"upstream preview")
            watermark_qml = 'Image { source: "../images/watermark.png" }\n'
            logout.write_text(watermark_qml, encoding="utf-8")
            splash.write_text(watermark_qml, encoding="utf-8")
            metadata = package / "metadata.json"
            metadata.write_text('{"Name":"Windows 7 style"}\n', encoding="utf-8")
            branding = root / "aero7-branding.png"
            branding.write_bytes(b"aero7 branding")

            branded = brand_plasma_look_and_feel(
                root / "look-and-feel", branding
            )

            self.assertEqual(branded, [package])
            self.assertFalse((images / "watermark.png").exists())
            self.assertEqual(
                (images / "aero7-watermark.png").read_bytes(),
                b"aero7 branding",
            )
            self.assertNotIn("../images/watermark.png", logout.read_text(encoding="utf-8"))
            self.assertNotIn("../images/watermark.png", splash.read_text(encoding="utf-8"))
            self.assertIn("../images/aero7-watermark.png", logout.read_text(encoding="utf-8"))
            self.assertIn("../images/aero7-watermark.png", splash.read_text(encoding="utf-8"))
            self.assertFalse((previews / "preview.png").exists())
            self.assertFalse((previews / "fullscreenpreview.jpg").exists())
            self.assertNotIn("Windows 7", metadata.read_text(encoding="utf-8"))

    def test_plasma_lock_screen_uses_aero7_branding_and_white_button_text(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shell = root / "shells/io.gitgud.wackyideas.desktop"
            auth_qml = shell / "contents/lockscreen/AuthUI.qml"
            button_qml = shell / "contents/components/GenericButton.qml"
            branding = shell / "contents/images/branding.png"
            auth_qml.parent.mkdir(parents=True)
            button_qml.parent.mkdir(parents=True)
            branding.parent.mkdir(parents=True)
            auth_qml.write_text(
                "Image {\n"
                '        source: "../images/branding.png"\n'
                "}\n",
                encoding="utf-8",
            )
            button_qml.write_text(
                "PlasmaComponents.Label {\n"
                "        id: btnLabel\n\n"
                "        anchors.fill: parent\n"
                "}\n",
                encoding="utf-8",
            )
            branding.write_bytes(b"upstream branding")
            source = root / "aero7-branding.png"
            source.write_bytes(b"aero7 branding")

            branded = brand_plasma_lock_screen(root / "shells", source)

            self.assertEqual(branded, [shell])
            self.assertEqual(branding.read_bytes(), b"aero7 branding")
            auth_contents = auth_qml.read_text(encoding="utf-8")
            self.assertIn("fillMode: Image.PreserveAspectFit", auth_contents)
            self.assertIn("mipmap: true", auth_contents)
            self.assertIn('color: "white"', button_qml.read_text(encoding="utf-8"))

    def test_target_identity_replaces_arch_os_release_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "etc").mkdir()
            (root / "usr/lib").mkdir(parents=True)
            upstream = root / "usr/lib/os-release"
            upstream.write_text('NAME="Arch Linux"\n', encoding="utf-8")
            (root / "etc/os-release").symlink_to("../usr/lib/os-release")

            result = write_target_os_release(root)

            self.assertEqual(result, root / "etc/os-release")
            self.assertFalse(result.is_symlink())
            contents = result.read_text(encoding="utf-8")
            self.assertIn('PRETTY_NAME="Aero7 Beta 1"', contents)
            self.assertIn("ID_LIKE=arch", contents)
            self.assertEqual(upstream.read_text(encoding="utf-8"), contents)
            self.assertFalse((root / "etc/arch-release").exists())
            self.assertIn(
                'DISTRIB_DESCRIPTION="Aero7 Beta 1"',
                (root / "etc/lsb-release").read_text(encoding="utf-8"),
            )
            self.assertEqual(
                (root / "etc/aero7-release").read_text(encoding="utf-8"),
                "Aero7 Beta 1\n",
            )
            hook = root / "usr/share/libalpm/hooks/aero7-system-identity.hook"
            self.assertIn(
                "Exec = /usr/local/lib/aero7/apply-system-identity",
                hook.read_text(encoding="utf-8"),
            )
            apply_identity = root / "usr/local/lib/aero7/apply-system-identity"
            self.assertTrue(apply_identity.stat().st_mode & 0o111)

    def test_live_install_logs_are_preserved_with_private_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "target"
            installer_log = root / "aero7-installer.log"
            storage_log = root / "aero7-storage-actions.log"
            missing_log = root / "missing.log"
            installer_log.write_text("installer evidence\n", encoding="utf-8")
            storage_log.write_text("storage evidence\n", encoding="utf-8")

            preserved = preserve_live_install_logs(
                target, (installer_log, storage_log, missing_log)
            )

            self.assertEqual(
                preserved,
                [
                    target / "var/log/aero7-installer.log",
                    target / "var/log/aero7-storage-actions.log",
                ],
            )
            for path in preserved:
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_light_desktop_defaults_are_enforced_before_login(self):
        runner = RecordingRunner()
        enforce_light_desktop_defaults("geko", runner)

        commands = [call[0] for call in runner.calls]
        joined = [" ".join(command) for command in commands]
        self.assertTrue(any("General --key ColorScheme Aero7Light" in line for line in joined))
        self.assertTrue(any("Colors:View --key BackgroundNormal 255,255,255" in line for line in joined))
        self.assertTrue(any("Colors:Complementary --key BackgroundNormal 240,240,240" in line for line in joined))
        self.assertTrue(any("plasmarc --group Theme --key name Aero7" in line for line in joined))
        self.assertTrue(any("/home/geko/.config/Kvantum" in line for line in joined))
        self.assertTrue(any("Kvantum/kvantum.kvconfig --group General --key theme Windows7Aero" in line for line in joined))
        self.assertTrue(any("kwalletrc --group Wallet --key Enabled --type bool false" in line for line in joined))
        self.assertTrue(any("kwalletrc --group Wallet --key First Use --type bool false" in line for line in joined))
        self.assertFalse(any("--file kvantum.kvconfig" in line for line in joined))
        self.assertTrue(any("plasmashellrc --group PlasmaViews --group Panel 2 --key panelOpacity 2" in line for line in joined))
        self.assertTrue(all("HOME=/home/geko" in line for line in joined[1:]))
        with self.assertRaisesRegex(SafetyError, "username"):
            enforce_light_desktop_defaults("Bad User", runner)

    def test_binary_package_install_is_verified_and_recorded(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "target"
            share = root / "share"
            (target / "etc").mkdir(parents=True)
            share.mkdir()
            (target / "etc/pacman.conf").write_text("[core]\n", encoding="utf-8")
            (share / "aero7-repository.asc").write_text("test key\n", encoding="utf-8")
            (share / "aero7-packages.txt").write_text("one\ntwo\n", encoding="utf-8")
            runner = RecordingRunner()

            configure_and_install(target, runner, share)

            commands = [call[0] for call in runner.calls]
            install_call = next(
                call
                for call in runner.calls
                if call[0][2:5] == ["pacman", "-Syy", "--needed"]
            )
            self.assertIn("--noconfirm", install_call[0])
            self.assertIn("--ask=4", install_call[0])
            self.assertIsNone(install_call[1])
            self.assertIn(
                ["arch-chroot", str(target), "pacman", "-Q", "--", "one", "two"],
                commands,
            )
            self.assertEqual(
                (target / "var/lib/aero7/requested-aero7-packages.txt").read_text(
                    encoding="utf-8"
                ),
                "one\ntwo\n",
            )

    def test_first_desktop_login_is_temporary_and_uses_aero_session(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            sessions = root / "usr/share/wayland-sessions"
            sessions.mkdir(parents=True)
            (sessions / "plasma.desktop").write_text("[Desktop Entry]\n", encoding="utf-8")
            (sessions / "aerothemeplasma.desktop").write_text(
                "[Desktop Entry]\n", encoding="utf-8"
            )
            config = root / "etc/sddm.conf.d/10-aero7-first-login.conf"
            systemd = root / "etc/systemd/system"

            session = configure_one_time_autologin("geko", config, sessions, systemd)

            self.assertEqual(session, "aerothemeplasma.desktop")
            self.assertEqual(config.stat().st_mode & 0o777, 0o644)
            self.assertEqual(
                config.read_text(encoding="utf-8"),
                "[Autologin]\n"
                "User=geko\n"
                "Session=aerothemeplasma.desktop\n"
                "Relogin=false\n",
            )
            service = systemd / "aero7-first-login-cleanup.service"
            timer = systemd / "aero7-first-login-cleanup.timer"
            self.assertEqual(service.stat().st_mode & 0o777, 0o644)
            self.assertIn(
                f"ExecStart=/usr/bin/rm -f {config}",
                service.read_text(encoding="utf-8"),
            )
            self.assertIn(
                "ExecStartPost=/usr/bin/systemctl disable aero7-first-login-cleanup.timer",
                service.read_text(encoding="utf-8"),
            )
            self.assertEqual(timer.stat().st_mode & 0o777, 0o644)
            self.assertIn("OnActiveSec=45s", timer.read_text(encoding="utf-8"))
            self.assertIn("Persistent=false", timer.read_text(encoding="utf-8"))
            with self.assertRaisesRegex(SafetyError, "username"):
                configure_one_time_autologin("Bad User", config, sessions, systemd)

    def test_command_failure_reports_recent_log_output(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = CommandRunner(Path(directory) / "installer.log")
            with self.assertRaisesRegex(RuntimeError, "diagnostic detail"):
                runner.run(["/bin/sh", "-c", "printf 'diagnostic detail\\n'; exit 7"])

    def test_progress_pulse_emits_monotonic_stage_and_overall_percentages(self):
        with patch("aero7_install_backend.event") as emit:
            pulse = ProgressPulse("Installing the base system", 28, 53)
            pulse.emit()
            pulse.advance()
            pulse.complete()

        payloads = [call.kwargs for call in emit.call_args_list]
        self.assertEqual(
            [payload["stage_percent"] for payload in payloads], [0, 5, 100]
        )
        self.assertEqual([payload["percent"] for payload in payloads], [28, 29, 53])
        self.assertTrue(
            all(payload["stage"] == "Installing the base system" for payload in payloads)
        )

    def test_command_runner_heartbeats_during_long_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            pulses = []
            runner = CommandRunner(Path(directory) / "installer.log")
            with runner.progress_heartbeat(
                lambda: pulses.append("pulse"), interval=0.02
            ):
                runner.run(
                    [sys.executable, "-c", "import time; time.sleep(0.08)"]
                )

        self.assertGreaterEqual(len(pulses), 2)

    def test_heartbeat_command_failure_reports_the_real_exit_code(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = CommandRunner(Path(directory) / "installer.log")
            with self.assertRaisesRegex(
                RuntimeError, "command failed with exit code 9"
            ):
                with runner.progress_heartbeat(lambda: None, interval=0.02):
                    runner.run(
                        [
                            "/bin/sh",
                            "-c",
                            "printf 'pacstrap diagnostic\\n'; exit 9",
                        ]
                    )

    def test_partition_table_uses_exact_supported_sector_syntax(self):
        table = partition_table()
        self.assertIn('start=2048, size=2097152', table)
        self.assertIn('name="EFI System"', table)
        self.assertIn('name="Aero7 root"', table)
        self.assertNotIn("GiB", table)

    def test_partition_path_supports_virtio_sata_and_nvme(self):
        self.assertEqual(partition_path("/dev/vda", 3), "/dev/vda3")
        self.assertEqual(partition_path("/dev/sda", 3), "/dev/sda3")
        self.assertEqual(partition_path("/dev/nvme0n1", 3), "/dev/nvme0n1p3")
        self.assertEqual(partition_path("/dev/mmcblk0", 3), "/dev/mmcblk0p3")

    def test_storage_inventory_lists_system_windows_and_unallocated_space(self):
        value = gpt_disk_with_windows()
        targets = storage_targets(value, 0)

        self.assertEqual(targets[0]["type"], "System")
        windows = next(item for item in targets if item.get("filesystem") == "ntfs")
        self.assertEqual(windows["display_name"], "Disk 0 Partition 3: Windows")
        self.assertTrue(windows["can_shrink"])
        unallocated = [item for item in targets if item["target_kind"] == "free"]
        self.assertEqual(len(unallocated), 1)
        self.assertGreater(
            unallocated[0]["region_size_bytes"], MIN_ADVANCED_REGION_BYTES
        )
        self.assertTrue(unallocated[0]["can_install"])

    def test_flat_lsblk_rows_are_reconstructed_under_their_parent_disk(self):
        rows = [
            {"path": "/dev/vda", "kname": "vda", "pkname": None, "type": "disk"},
            {
                "path": "/dev/vda1",
                "kname": "vda1",
                "pkname": "vda",
                "type": "part",
            },
        ]
        nested = nest_block_devices(rows)
        self.assertEqual(len(nested), 1)
        self.assertEqual(nested[0]["path"], "/dev/vda")
        self.assertEqual(nested[0]["children"][0]["path"], "/dev/vda1")

    def test_advanced_free_space_plan_requires_the_exact_unchanged_gap(self):
        value = gpt_disk_with_windows()
        target = next(
            item
            for item in storage_targets(value, 0)
            if item["target_kind"] == "free"
        )
        plan = advanced_plan(value, target)
        validate_plan(plan, value, set())

        changed = deepcopy(value)
        changed["children"].append(
            {
                "path": "/dev/vda4",
                "type": "part",
                "size": 1024**3,
                "start": target["start_sector"],
                "partn": 4,
                "mountpoints": [None],
            }
        )
        with self.assertRaisesRegex(SafetyError, "unallocated region changed"):
            validate_plan(plan, changed, set())

    def test_new_partition_size_may_leave_part_of_the_gap_unallocated(self):
        value = gpt_disk_with_windows()
        target = next(
            item for item in storage_targets(value, 0)
            if item["target_kind"] == "free"
        )
        requested = 20 * 1024**3
        plan = advanced_plan(
            value, {**target, "install_region_size_bytes": requested}
        )
        validate_plan(plan, value, set())
        runner = RecordingRunner()
        with patch(
            "aero7_install_backend.append_aero7_partitions",
            return_value=("/dev/vda4", "/dev/vda5"),
        ) as append:
            prepare_advanced_target(plan, value, runner)
        expected_end = target["start_sector"] + requested // 512 - 1
        append.assert_called_once_with(
            "/dev/vda", target["start_sector"], expected_end, 512, runner
        )

        oversized = dict(
            plan, install_region_size_bytes=target["region_size_bytes"] + 1024**3
        )
        with self.assertRaisesRegex(SafetyError, "larger than"):
            validate_plan(oversized, value, set())

    def test_advanced_mode_rejects_non_gpt_disks_and_the_efi_partition(self):
        value = gpt_disk_with_windows()
        free = next(
            item
            for item in storage_targets(value, 0)
            if item["target_kind"] == "free"
        )
        nongpt = deepcopy(value)
        nongpt["pttype"] = "dos"
        with self.assertRaisesRegex(SafetyError, "requires a GPT disk"):
            validate_plan(advanced_plan(nongpt, free), nongpt, set())

        esp = value["children"][0]
        esp_target = {
            **partition_fingerprint(esp, value),
            "target_kind": "reuse_partition",
        }
        with self.assertRaisesRegex(SafetyError, "EFI System Partition"):
            validate_plan(advanced_plan(value, esp_target), value, set())

    def test_ntfs_shrink_plan_keeps_windows_and_releases_enough_space(self):
        value = gpt_disk_with_windows()
        windows = value["children"][1]
        target = {
            **partition_fingerprint(windows, value),
            "target_kind": "shrink_ntfs",
            "shrink_size_bytes": 28 * 1024**3,
        }
        plan = advanced_plan(value, target)
        validate_plan(plan, value, set())

        too_small = dict(plan, shrink_size_bytes=35 * 1024**3)
        with self.assertRaisesRegex(SafetyError, "release at least 17 GiB"):
            validate_plan(too_small, value, set())

    def test_ntfs_filesystem_is_shrunk_before_partition_boundary_moves(self):
        value = gpt_disk_with_windows()
        windows = value["children"][1]
        plan = advanced_plan(
            value,
            {
                **partition_fingerprint(windows, value),
                "target_kind": "shrink_ntfs",
                "shrink_size_bytes": 28 * 1024**3,
            },
        )
        runner = RecordingRunner()
        with patch(
            "aero7_install_backend.append_aero7_partitions",
            return_value=("/dev/vda4", "/dev/vda5"),
        ):
            esp, root = prepare_advanced_target(plan, value, runner)

        self.assertEqual((esp, root), ("/dev/vda4", "/dev/vda5"))
        commands = [call[0] for call in runner.calls]
        real_resize = next(
            index
            for index, command in enumerate(commands)
            if command[:2] == ["ntfsresize", "--no-progress-bar"]
        )
        partition_resize = next(
            index for index, command in enumerate(commands) if command[0] == "parted"
        )
        self.assertLess(real_resize, partition_resize)
        self.assertEqual(commands[0], ["ntfsresize", "--check", "/dev/vda3"])
        self.assertIn("--no-action", commands[1])
        self.assertTrue(
            all(
                "--force" not in command
                for command in commands
                if command[0] == "ntfsresize"
            )
        )

    def test_shrink_preflight_requires_ntfs_tools_before_disk_changes(self):
        plan = {"target_kind": "shrink_ntfs"}
        self.assertIn("ntfsresize", required_install_commands(plan))
        self.assertIn("parted", required_install_commands(plan))
        with patch(
            "aero7_install_backend.shutil.which",
            side_effect=lambda name: None if name == "ntfsresize" else f"/usr/bin/{name}",
        ):
            with self.assertRaisesRegex(SafetyError, "ntfsresize.*not changed"):
                ensure_install_tools(plan)

    def test_advanced_partition_table_backup_is_private_and_restorable(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "before.sfdisk"
            dump = "label: gpt\n/dev/vda1 : start=2048, size=1048576\n"
            result = SimpleNamespace(returncode=0, stdout=dump, stderr="")
            with patch("aero7_install_backend.subprocess.run", return_value=result) as run:
                written = backup_partition_table("/dev/vda", destination)

            self.assertEqual(written, destination)
            self.assertEqual(destination.read_text(encoding="utf-8"), dump)
            self.assertEqual(destination.stat().st_mode & 0o777, 0o600)
            self.assertEqual(run.call_args.args[0], ["sfdisk", "--dump", "/dev/vda"])

    def test_advanced_install_stops_if_partition_table_backup_fails(self):
        result = SimpleNamespace(returncode=1, stdout="", stderr="read failure")
        with patch("aero7_install_backend.subprocess.run", return_value=result):
            with self.assertRaisesRegex(SafetyError, "disk was not changed"):
                backup_partition_table("/dev/vda", Path("/tmp/not-written.sfdisk"))

    def test_partition_append_table_reserves_one_gib_for_efi(self):
        sector = 512
        start = 2048
        end = start + (20 * 1024**3 // sector) - 1
        table, esp_start, root_start = aero7_partition_append_table(
            start, end, sector
        )
        self.assertEqual(esp_start, 2048)
        self.assertEqual(root_start - esp_start, 1024**3 // sector)
        self.assertIn('name="Aero7 EFI"', table)
        self.assertIn('name="Aero7 root"', table)

    @unittest.skipUnless(shutil.which("sfdisk"), "sfdisk is not installed")
    def test_real_sfdisk_append_preserves_existing_dual_boot_partitions(self):
        with tempfile.NamedTemporaryFile(suffix=".raw") as fixture:
            fixture.truncate(40 * 1024**3)
            existing = (
                "label: gpt\n"
                "unit: sectors\n\n"
                "start=2048, size=1048576, "
                f"type={EFI_SYSTEM_TYPE}, name=\"Existing EFI\"\n"
                "start=1050624, size=16777216, "
                "type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7, "
                "name=\"Windows\"\n"
            )
            subprocess.run(
                ["sfdisk", fixture.name],
                input=existing,
                text=True,
                capture_output=True,
                check=True,
            )
            table, esp_start, root_start = aero7_partition_append_table(
                17827840, 83886046, 512
            )
            for extra in (("--no-act",), ()):
                subprocess.run(
                    [
                        "sfdisk",
                        *extra,
                        "--append",
                        "--wipe",
                        "never",
                        "--wipe-partitions",
                        "never",
                        fixture.name,
                    ],
                    input=table,
                    text=True,
                    capture_output=True,
                    check=True,
                )
            result = subprocess.run(
                ["sfdisk", "--json", fixture.name],
                check=True,
                capture_output=True,
                text=True,
            )
            partitions = json.loads(result.stdout)["partitiontable"]["partitions"]

        self.assertEqual(len(partitions), 4)
        self.assertEqual((partitions[0]["start"], partitions[0]["size"]), (2048, 1048576))
        self.assertEqual(
            (partitions[1]["start"], partitions[1]["size"]),
            (1050624, 16777216),
        )
        self.assertEqual(partitions[2]["start"], esp_start)
        self.assertEqual(partitions[3]["start"], root_start)

    def test_pacstrap_uses_populated_live_keyring(self):
        arguments = pacstrap_arguments(Path("/mnt/aero7-target"), ["base", "linux"])
        self.assertEqual(arguments, ["pacstrap", "/mnt/aero7-target", "base", "linux"])
        self.assertNotIn("-K", arguments)

    def test_pacstrap_progress_uses_downloaded_cache_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "installer.log"
            cache = root / "cache"
            cache.mkdir()
            log.write_text(
                "Total Download Size: 100.00 MiB\n:: Retrieving packages...\n",
                encoding="utf-8",
            )
            with (cache / "package.pkg.tar.zst.part").open("wb") as package:
                package.truncate(25 * 1024**2)

            self.assertEqual(pacstrap_download_stage_percent(log, cache), 22)

            with (cache / "package.pkg.tar.zst.part").open("r+b") as package:
                package.truncate(120 * 1024**2)
            self.assertEqual(pacstrap_download_stage_percent(log, cache), 90)

    def test_pacstrap_progress_waits_for_pacman_total(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "installer.log"
            cache = root / "cache"
            cache.mkdir()
            log.write_text("resolving dependencies...\n", encoding="utf-8")
            self.assertIsNone(pacstrap_download_stage_percent(log, cache))

    def test_network_preflight_rejects_a_disconnected_vm(self):
        with patch(
            "aero7_install_backend.subprocess.run",
            return_value=SimpleNamespace(returncode=1, stdout=""),
        ) as run:
            with self.assertRaisesRegex(SafetyError, "target disk was not changed"):
                ensure_install_network(timeout=7)

        self.assertEqual(
            run.call_args.args[0],
            ["nm-online", "--quiet", "--timeout", "7"],
        )

    def test_network_preflight_reports_dns_failure(self):
        results = [
            SimpleNamespace(returncode=0, stdout=""),
            SimpleNamespace(returncode=2, stdout=""),
            SimpleNamespace(returncode=2, stdout=""),
        ]
        with patch("aero7_install_backend.subprocess.run", side_effect=results):
            with self.assertRaisesRegex(SafetyError, "DNS could not resolve"):
                ensure_install_network()

    def test_network_preflight_accepts_a_resolvable_package_mirror(self):
        results = [
            SimpleNamespace(returncode=0, stdout=""),
            SimpleNamespace(returncode=0, stdout="95.216.195.133 STREAM host\n"),
        ]
        with patch("aero7_install_backend.subprocess.run", side_effect=results):
            ensure_install_network()

    def test_install_checks_network_before_creating_a_command_runner(self):
        value = disk()
        with (
            patch("aero7_install_backend.enforce_execution_gate"),
            patch("aero7_install_backend.query_lsblk", return_value=[value]),
            patch("aero7_install_backend.live_sources", return_value=set()),
            patch(
                "aero7_install_backend.ensure_install_network",
                side_effect=SafetyError("offline before wipe"),
            ),
            patch("aero7_install_backend.CommandRunner") as runner,
        ):
            with self.assertRaisesRegex(SafetyError, "offline before wipe"):
                install(plan_for(value), "/dev/vda")

        runner.assert_not_called()


if __name__ == "__main__":
    unittest.main()
