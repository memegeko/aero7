#!/usr/bin/env python3

from __future__ import annotations

import sys
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path
from unittest.mock import patch

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT / "backend"))

from aero7_install_backend import (  # noqa: E402
    CommandRunner,
    MIN_DISK_BYTES,
    SUPPORTED_LAYOUT,
    SafetyError,
    brand_plasma_look_and_feel,
    brand_sddm_themes,
    candidate_disks,
    configure_one_time_autologin,
    configure_plymouth_hold,
    ensure_shell_payload_modes,
    enable_plymouth_hook,
    enforce_light_desktop_defaults,
    enforce_execution_gate,
    fingerprint,
    partition_table,
    pacstrap_arguments,
    shell_image_mode_arguments,
    validate_oobe,
    validate_plan,
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


class DiskPlanTest(unittest.TestCase):
    def test_accepts_stable_unmounted_virtio_disk(self):
        value = disk()
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

    def test_rejects_non_virtio_path(self):
        value = disk(path="/dev/sda", kname="sda", **{"maj:min": "8:0"})
        with self.assertRaisesRegex(SafetyError, "VirtIO"):
            validate_plan(plan_for(value), value, set())

    def test_execution_gate_is_closed_by_default(self):
        with patch.dict("os.environ", {}, clear=True):
            with self.assertRaisesRegex(SafetyError, "guard token"):
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
        self.assertIn("AERO7_WALLPAPER=aero_bg_1.png", arguments)
        self.assertIn("--image-mode", arguments)
        self.assertEqual(arguments[arguments.index("--target-user") + 1], "geko")
        skipped = [
            arguments[index + 1]
            for index, value in enumerate(arguments[:-1])
            if value == "--skip-stage"
        ]
        self.assertIn("20-system-update", skipped)
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

    def test_light_desktop_defaults_are_enforced_before_login(self):
        runner = RecordingRunner()
        enforce_light_desktop_defaults("geko", runner)

        commands = [call[0] for call in runner.calls]
        joined = [" ".join(command) for command in commands]
        self.assertTrue(any("General --key ColorScheme Aero7Light" in line for line in joined))
        self.assertTrue(any("Colors:View --key BackgroundNormal 255,255,255" in line for line in joined))
        self.assertTrue(any("Colors:Complementary --key BackgroundNormal 240,240,240" in line for line in joined))
        self.assertTrue(any("plasmarc --group Theme --key name breeze-light" in line for line in joined))
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

    def test_partition_table_uses_exact_supported_sector_syntax(self):
        table = partition_table()
        self.assertIn('start=2048, size=2097152', table)
        self.assertIn('name="EFI System"', table)
        self.assertIn('name="Aero7 root"', table)
        self.assertNotIn("GiB", table)

    def test_pacstrap_uses_populated_live_keyring(self):
        arguments = pacstrap_arguments(Path("/mnt/aero7-target"), ["base", "linux"])
        self.assertEqual(arguments, ["pacstrap", "/mnt/aero7-target", "base", "linux"])
        self.assertNotIn("-K", arguments)


if __name__ == "__main__":
    unittest.main()
