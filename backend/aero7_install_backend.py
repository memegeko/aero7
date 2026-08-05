#!/usr/bin/env python3
"""Narrow, fail-closed privileged backend for the Aero7 ISO.

Simulation is implemented in the Qt frontend. This process is used only for
read-only disk discovery or an explicitly live-enabled disposable VM install.
"""

from __future__ import annotations

import argparse
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
GUARD_TOKEN = "YES-I-AM-IN-A-DISPOSABLE-AERO7-VM"
SUPPORTED_LAYOUT = "uefi-gpt-esp-ext4"
INSTALL_STAGES = (
    "Preparing disk",
    "Copying system files",
    "Installing the base system",
    "Installing Aero7 features",
    "Configuring the bootloader",
    "Applying system settings",
    "Preparing first boot",
)
VM_MARKERS = ("qemu", "kvm", "virtualbox", "vmware")
PACKAGE_MIRROR_HOSTS = (
    "geo.mirror.pkgbuild.com",
    "fastly.mirror.pkgbuild.com",
)
TARGET_ROOT = Path("/mnt/aero7-target")
IMAGE_MODE_GUARD = "YES-I-AM-IN-AERO7-FIRST-BOOT"
SHELL_INSTALLER = Path("/usr/local/lib/aero7-shell-installer/install.sh")
SDDM_BRANDING = Path("/usr/share/aero7/branding/aero7-sddm-branding.png")
SDDM_BACKGROUND = Path("/usr/share/aero7/branding/aero7-login-background.jpg")
FIRST_LOGIN_CONFIG = Path("/etc/sddm.conf.d/10-aero7-first-login.conf")
FIRST_LOGIN_CLEANUP_TIMER = "aero7-first-login-cleanup.timer"
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


def device_has_mounts(node: dict[str, Any]) -> bool:
    return any(normalized_mountpoints(item.get("mountpoints")) for item in flatten_devices([node]))


def live_sources() -> set[str]:
    result: set[str] = set()
    for mountpoint in ("/run/archiso/bootmnt", "/boot", "/"):
        completed = subprocess.run(
            ["findmnt", "-n", "-o", "SOURCE", mountpoint],
            check=False,
            capture_output=True,
            text=True,
        )
        source = completed.stdout.strip()
        if source.startswith("/dev/"):
            result.add(str(Path(source).resolve()))
    return result


def query_lsblk() -> list[dict[str, Any]]:
    fields = "PATH,KNAME,TYPE,SIZE,MODEL,SERIAL,RO,RM,MAJ:MIN,MOUNTPOINTS,TRAN"
    completed = subprocess.run(
        ["lsblk", "--json", "--bytes", "--output", fields],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(completed.stdout).get("blockdevices", [])


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
    }


def candidate_disks(nodes: list[dict[str, Any]], excluded_sources: set[str] | None = None) -> list[dict[str, Any]]:
    excluded = {str(Path(path).resolve()) for path in (excluded_sources or set())}
    candidates: list[dict[str, Any]] = []
    for node in nodes:
        path = str(node.get("path") or "")
        if node.get("type") != "disk" or not path.startswith("/dev/"):
            continue
        if not re.fullmatch(r"/dev/vd[a-z]", path):
            continue
        try:
            resolved = str(Path(path).resolve())
        except OSError:
            continue
        if resolved in excluded:
            continue
        if bool(node.get("ro")) or bool(node.get("rm")):
            continue
        if int(node.get("size") or 0) < MIN_DISK_BYTES:
            continue
        if device_has_mounts(node):
            continue
        candidates.append(fingerprint(node))
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


def validate_plan(plan: dict[str, Any], current: dict[str, Any], excluded_sources: set[str]) -> None:
    if plan.get("layout") != SUPPORTED_LAYOUT:
        raise SafetyError("unsupported disk layout")
    if current.get("type") != "disk":
        raise SafetyError("selected target is not a whole disk")
    device = str(plan.get("device") or "")
    if not re.fullmatch(r"/dev/vd[a-z]", device):
        raise SafetyError("MVP live installs accept only a QEMU VirtIO /dev/vdX disk")
    if str(Path(device).resolve()) in {str(Path(item).resolve()) for item in excluded_sources}:
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
    for key in ("device", "kname", "model", "serial", "size_bytes", "maj_min"):
        if plan.get(key) != actual.get(key):
            raise SafetyError(f"disk fingerprint changed: {key}")


def read_dmi() -> str:
    values: list[str] = []
    for path in (Path("/sys/class/dmi/id/product_name"), Path("/sys/class/dmi/id/sys_vendor")):
        try:
            values.append(path.read_text(encoding="utf-8", errors="replace").strip())
        except OSError:
            pass
    return " ".join(values).lower()


def enforce_execution_gate() -> None:
    if os.environ.get("AERO7_ALLOW_DESTRUCTIVE") != GUARD_TOKEN:
        raise SafetyError("destructive guard token is absent")
    if os.geteuid() != 0:
        raise SafetyError("real installation backend must run as root inside the ISO")
    dmi = read_dmi()
    if not any(marker in dmi for marker in VM_MARKERS):
        raise SafetyError("real installation is restricted to a recognized virtual machine")


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

    def run(self, argv: list[str], *, input_text: str | None = None) -> None:
        if not argv or not all(isinstance(item, str) and item for item in argv):
            raise RuntimeError("invalid command argument array")
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
                if returncode == 0:
                    self._heartbeat()
        if returncode != 0:
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


def partition_path(device: str, number: int) -> str:
    if not re.fullmatch(r"/dev/vd[a-z]", device):
        raise SafetyError("partition naming is implemented only for QEMU VirtIO disks")
    return f"{device}{number}"


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


def pacstrap_arguments(target: Path, packages: Iterable[str]) -> list[str]:
    # Keep pacstrap's documented default: copy the live environment's fully
    # initialized signing keyring into the target before package installation.
    return ["pacstrap", str(target), *packages]


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
        if upstream_reference not in contents:
            continue
        assets = main_qml.parent / "Assets"
        assets.mkdir(parents=True, exist_ok=True)
        destination = assets / "aero7-branding.png"
        shutil.copy2(branding_source, destination)
        main_qml.write_text(
            contents.replace(upstream_reference, "Assets/aero7-branding.png"),
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
        "70-aero-applications",
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
         config_home, f"{config_home}/kdedefaults"]
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
        ("kvantum.kvconfig", "General", "theme", "Windows7Aero"),
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

    # This ISO retrieves the base system from signed Arch mirrors. Verify
    # connectivity before wipefs/sfdisk so missing DHCP or DNS cannot destroy
    # the selected disk and only then reveal that installation cannot proceed.
    ensure_install_network()

    log_path = Path("/var/log/aero7-installer.log")
    log_path.parent.mkdir(parents=True, exist_ok=True)
    runner = CommandRunner(log_path)
    device = confirm_device
    esp = partition_path(device, 1)
    root = partition_path(device, 2)
    mounted = False

    try:
        copying_disk = ProgressPulse(
            INSTALL_STAGES[0], 2, 17, stage_start=0, stage_end=65
        )
        copying_disk.emit()
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
        copying_disk.complete()

        copying_files = ProgressPulse(
            INSTALL_STAGES[1], 18, 27, stage_start=65, stage_end=100
        )
        copying_files.emit()

        TARGET_ROOT.mkdir(parents=True, exist_ok=True)
        runner.run(["mount", root, str(TARGET_ROOT)])
        mounted = True
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
        with runner.progress_heartbeat(expanding.advance):
            runner.run(pacstrap_arguments(TARGET_ROOT, packages))
        fstab = subprocess.run(
            ["genfstab", "-U", str(TARGET_ROOT)], check=True, capture_output=True, text=True
        ).stdout
        (TARGET_ROOT / "etc/fstab").write_text(fstab, encoding="utf-8")
        expanding.complete()

        features = ProgressPulse(INSTALL_STAGES[3], 54, 71)
        features.emit()
        with runner.progress_heartbeat(features.advance):
            configure_and_install(TARGET_ROOT, runner, Path("/usr/share/aero7"))
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
        locale = TARGET_ROOT / "etc/locale.gen"
        locale.write_text(locale.read_text(encoding="utf-8").replace("#en_US.UTF-8 UTF-8", "en_US.UTF-8 UTF-8"), encoding="utf-8")
        with runner.progress_heartbeat(updates_settings.advance):
            runner.run(["arch-chroot", str(TARGET_ROOT), "locale-gen"])
            (TARGET_ROOT / "etc/locale.conf").write_text("LANG=en_US.UTF-8\n", encoding="utf-8")
            copy_payload(TARGET_ROOT)
            updates_settings.advance()
            configure_target_plymouth(TARGET_ROOT, runner)
            runner.run(["arch-chroot", str(TARGET_ROOT), "systemctl", "enable", "NetworkManager.service"])
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
    enforce_light_desktop_defaults(username, runner)
    configure_one_time_autologin(username)
    runner.run(["systemctl", "daemon-reload"])
    runner.run(["systemctl", "enable", "--now", FIRST_LOGIN_CLEANUP_TIMER])

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

    install_parser = sub.add_parser("install", help="perform the guarded VM-only install")
    install_parser.add_argument("--plan", type=Path, required=True)
    install_parser.add_argument("--confirm-device", required=True)
    install_parser.add_argument("--execute", action="store_true")

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
        elif args.command == "oobe-finalize":
            finalize_oobe(load_plan(args.plan))
        return 0
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError, RuntimeError) as error:
        event("status", message=f"Stopped safely: {error}")
        print(f"aero7 backend: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
