#!/usr/bin/env bash
set -Eeuo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
shell_relative_path="$(sed -n 's/^aero7_shell_path=//p' "$project_root/sources.lock")"
source_path="$(realpath -m "$project_root/$shell_relative_path")"

printf 'Repository policy files\n'
for policy_file in \
  CONTRIBUTING.md \
  CODE_OF_CONDUCT.md \
  SECURITY.md \
  SUPPORT.md \
  THIRD_PARTY.md \
  .github/PULL_REQUEST_TEMPLATE.md \
  .github/ISSUE_TEMPLATE/bug_report.yml \
  .github/ISSUE_TEMPLATE/feature_request.yml; do
  [[ -s "$project_root/$policy_file" ]] || {
    printf 'Missing repository policy file: %s\n' "$policy_file" >&2
    exit 1
  }
done

printf 'Repository structure\n'
mapfile -t tracked_readmes < <(
  git -C "$project_root" ls-files | grep -Ei '(^|/)readme([^/]*)$' || true
)
if ((${#tracked_readmes[@]} != 1)) || [[ "${tracked_readmes[0]:-}" != "README.md" ]]; then
  printf 'Keep one public README at the repository root; found:\n' >&2
  printf '  %s\n' "${tracked_readmes[@]}" >&2
  exit 1
fi
if git -C "$project_root" ls-files \
    | grep -v '^out/\.gitkeep$' \
    | grep -Eq '(^|/)(__pycache__|build|work|out|\.cache)(/|$)|\.(iso|qcow2|raw|img|fd|log|pyc)$'; then
  printf 'Generated build output is tracked in the source repository.\n' >&2
  exit 1
fi
if git -C "$project_root" ls-files | grep -Eq '^aero_desktop/'; then
  printf 'Aero7-shell source is tracked inside the ISO repository.\n' >&2
  exit 1
fi

printf 'Beta 2 package ownership\n'
local_package_manifest="$project_root/config/beta2-local-packages.sha256"
local_package_names="$project_root/config/beta2-local-package-names.txt"
optional_package_names="$project_root/config/beta2-optional-package-names.txt"
[[ -s "$local_package_manifest" ]] || {
  printf 'The Beta 2 package manifest is missing.\n' >&2
  exit 1
}
[[ -s "$local_package_names" && -s "$optional_package_names" ]] || {
  printf 'The required/optional Beta 2 package lists are missing.\n' >&2
  exit 1
}
if comm -12 \
    <(grep -Ev '^[[:space:]]*(#|$)' "$local_package_names" | sort -u) \
    <(grep -Ev '^[[:space:]]*(#|$)' "$optional_package_names" | sort -u) \
    | grep -q .; then
  printf 'A Beta 2 package is declared as both required and optional.\n' >&2
  exit 1
fi
command -v bsdtar >/dev/null 2>&1 || {
  printf 'bsdtar is required to validate package ownership.\n' >&2
  exit 1
}
(
  cd "$project_root"
  sha256sum --check "${local_package_manifest#$project_root/}"
)
declare -A package_owners=()
while read -r package_hash package_path; do
  [[ "$package_hash" =~ ^[0-9a-f]{64}$ && "$package_path" == local-packages/*.pkg.tar.zst ]] || {
    printf 'Invalid Beta 2 package manifest entry: %s %s\n' \
      "$package_hash" "$package_path" >&2
    exit 1
  }
  while IFS= read -r package_entry; do
    [[ -n "$package_entry" && "$package_entry" != */ ]] || continue
    case "$package_entry" in
      .BUILDINFO|.MTREE|.PKGINFO) continue ;;
    esac
    if [[ -v "package_owners[$package_entry]" ]]; then
      printf 'Beta 2 packages have conflicting ownership for %s: %s and %s\n' \
        "$package_entry" "${package_owners[$package_entry]}" "$package_path" >&2
      exit 1
    fi
    package_owners["$package_entry"]="$package_path"
  done < <(bsdtar -tf "$project_root/$package_path")
done < "$local_package_manifest"

file_explorer_package_path="$(
  awk '$2 ~ /^local-packages\/aero7-file-explorer-.*\.pkg\.tar\.zst$/ { print $2 }' \
    "$local_package_manifest"
)"
[[ -n "$file_explorer_package_path" && -f "$project_root/$file_explorer_package_path" ]] || {
  printf 'The embedded File Explorer package is missing.\n' >&2
  exit 1
}
file_explorer_desktop="$(
  bsdtar -xOf "$project_root/$file_explorer_package_path" \
    usr/share/applications/org.aero7.FileExplorer.desktop
)"
for desktop_key in \
  'Name=File Explorer' \
  'Exec=aero7-file-explorer %u' \
  'Icon=aero7-file-explorer' \
  'StartupWMClass=org.aero7.FileExplorer'; do
  grep -Fqx "$desktop_key" <<<"$file_explorer_desktop" || {
    printf 'The embedded File Explorer desktop identity is incorrect: %s\n' \
      "$desktop_key" >&2
    exit 1
  }
done
declare -A approved_file_explorer_icons=(
  [32x32]='f6e73ec0c30f356d23365cecabe9c3495bfd76a16374c7dc6c1393749fe7abd2'
  [256x256]='d1c134d992bcc624c92213b3d81254cdb47692981c31fd9e64b92b870f9cb22c'
)
for icon_size in 32x32 256x256; do
  embedded_icon_hash="$(
    bsdtar -xOf "$project_root/$file_explorer_package_path" \
      "usr/share/icons/hicolor/$icon_size/apps/aero7-file-explorer.png" \
      | sha256sum | cut -d ' ' -f 1
  )"
  [[ "$embedded_icon_hash" == "${approved_file_explorer_icons[$icon_size]}" ]] || {
    printf 'File Explorer does not contain the approved AeroThemePlasma icon at %s.\n' \
      "$icon_size" >&2
    exit 1
  }
done

grep -Fqx 'aero7_shell_path=../aero7-beta2-test-inputs/aero7-shell-pinned' "$project_root/sources.lock" || {
  printf 'The ISO must consume Aero7-shell from its separate sibling clone.\n' >&2
  exit 1
}
grep -Fq 'for source_item in assets commands config keys lib modules recipes stages ui; do' \
  "$project_root/scripts/build-iso.sh"
if grep -Eq 'cp[[:space:]].*"\$source_path"[[:space:]]' "$project_root/scripts/build-iso.sh"; then
  printf 'The ISO builder copies the entire Aero7-shell repository.\n' >&2
  exit 1
fi

printf 'Python backend tests\n'
python -m unittest discover -s "$project_root/tests" -p 'test_*.py' -v

printf 'Python syntax\n'
python -m py_compile \
  "$project_root/backend/aero7_install_backend.py" \
  "$project_root/backend/aero7_shell_adapter.py"

printf 'Bash syntax\n'
while IFS= read -r script; do
  bash -n "$script"
  [[ -x "$script" ]] || {
    printf 'Project script is not executable: %s\n' "$script" >&2
    exit 1
  }
done < <(find "$project_root/scripts" -maxdepth 1 -type f -name '*.sh' -print | sort)
bash -n "$project_root/archiso/profiledef.sh"
bash -n "$project_root/archiso/airootfs/usr/lib/aero7/aero7-kiosk-launch"
bash -n "$project_root/diagnostics/aero7-collect-logs"
[[ -x "$project_root/diagnostics/aero7-collect-logs" ]] || {
  printf 'Diagnostic collector is not executable.\n' >&2
  exit 1
}
grep -Fq 'Aero7 Physical Install Logs' \
  "$project_root/diagnostics/aero7-collect-logs"
if rg -n 'capture .* (plasmashell|kwin_wayland) --version' \
    "$project_root/diagnostics/aero7-collect-logs" >/dev/null 2>&1; then
  printf 'Diagnostic collector launches a GUI process for version detection.\n' >&2
  exit 1
fi
grep -Fq 'session_display_available' \
  "$project_root/diagnostics/aero7-collect-logs"
grep -Fqx 'Storage=persistent' \
  "$project_root/diagnostics/50-aero7-test-logging.conf"
grep -Fqx 'OnUnitActiveSec=10min' \
  "$project_root/diagnostics/aero7-diagnostic-collect.timer"
grep -Fqx 'OnUnitActiveSec=5min' \
  "$project_root/diagnostics/aero7-diagnostic-session.timer"
grep -Fq 'configure_diagnostic_logging(username)' \
  "$project_root/backend/aero7_install_backend.py"
grep -Fq 'aero7-diagnostic-collect.timer' \
  "$project_root/backend/aero7_install_backend.py"
for diagnostic_package in \
  pciutils usbutils dmidecode smartmontools efibootmgr wireless-regdb rtkit; do
  grep -Fqx "$diagnostic_package" "$project_root/config/base-packages.txt" || {
    printf 'Physical diagnostic package is missing: %s\n' "$diagnostic_package" >&2
    exit 1
  }
done

printf 'QEMU UEFI boot order\n'
grep -Fq -- '-device "virtio-blk-pci,drive=aero7disk,bootindex=1"' \
  "$project_root/scripts/run-qemu.sh"
grep -Fq -- '-device "ide-cd,drive=aero7cd,bootindex=2"' \
  "$project_root/scripts/run-qemu.sh"
grep -Fq 'release_name="$(sed -n' "$project_root/scripts/run-qemu.sh"
grep -Fq 'Older images in out/ are deliberately ignored' \
  "$project_root/scripts/run-qemu.sh"
grep -Fq 'display_backend="spice"' "$project_root/scripts/run-qemu.sh"
grep -Fq 'display_spec="sdl,gl=off"' "$project_root/scripts/run-qemu.sh"
grep -Fq 'SDL_RENDER_SCALE_QUALITY=linear' "$project_root/scripts/run-qemu.sh"
grep -Fq 'remote-viewer --auto-resize=never' "$project_root/scripts/run-qemu.sh"
grep -Fq 'qemu_runtime_root="${XDG_RUNTIME_DIR:-/tmp}/aero7-qemu-$UID"' \
  "$project_root/scripts/run-qemu.sh"
grep -Fq 'qemu_runtime_root="${XDG_RUNTIME_DIR:-/tmp}/aero7-qemu-$UID"' \
  "$project_root/scripts/qemu-vm-input.sh"
grep -Fq 'image-compression=off,streaming-video=off' \
  "$project_root/scripts/run-qemu.sh"
grep -Fq -- '-machine "q35,accel=$accel,vmport=off"' \
  "$project_root/scripts/run-qemu.sh"
grep -Fq -- '-device "virtio-tablet-pci,id=aero7tablet"' \
  "$project_root/scripts/run-qemu.sh"
if rg -n -- '-device (usb-tablet|qemu-xhci)' \
    "$project_root/scripts/run-qemu.sh" >/dev/null 2>&1; then
  printf 'The QEMU launcher still contains the click-dropping USB tablet path.\n' >&2
  exit 1
fi
grep -Fq 'it does not rebuild the ISO' "$project_root/scripts/run-qemu.sh"
grep -Fq -- '--dualboot-fixture' "$project_root/scripts/run-qemu.sh"
grep -Fq -- '--disk-management-fixture' "$project_root/scripts/run-qemu.sh"
grep -Fq -- '--ssh-forward' "$project_root/scripts/run-qemu.sh"
grep -Fq 'name="Projects"' "$project_root/scripts/run-qemu.sh"
grep -Fq 'name="Backups"' "$project_root/scripts/run-qemu.sh"
grep -Fq 'name="Archive"' "$project_root/scripts/run-qemu.sh"
grep -Fq 'name="Existing EFI"' "$project_root/scripts/run-qemu.sh"
grep -Fq 'name="Windows"' "$project_root/scripts/run-qemu.sh"
if grep -Fq -- 'once=d' "$project_root/scripts/run-qemu.sh"; then
  printf 'The QEMU launcher still forces the installer DVD on reboot.\n' >&2
  exit 1
fi
grep -Fq 'staging_out="$work_root/iso-output-$build_stamp"' \
  "$project_root/scripts/build-iso.sh"
grep -Fq 'Expected exactly one staged Aero7 ISO' \
  "$project_root/scripts/build-iso.sh"
grep -Fq "findmnt -rn -o TARGET" \
  "$project_root/scripts/mksquashfs-safe-wrapper.sh"
if grep -Fq 'findmnt -Rrn -o TARGET "$source_root"' \
  "$project_root/scripts/mksquashfs-safe-wrapper.sh"; then
  printf 'The SquashFS guard still assumes its source root is a mount point.\n' >&2
  exit 1
fi
grep -Fq 'rm -rf --one-file-system -- "$stale_staging"' \
  "$project_root/scripts/build-iso.sh"
grep -Fq 'rm -rf --one-file-system -- "$archiso_work"' \
  "$project_root/scripts/build-iso.sh"
if rg -n 'work_root/archive|out_root/archive' \
    "$project_root/scripts/build-iso.sh" >/dev/null 2>&1; then
  printf 'The ISO builder still accumulates local build archives.\n' >&2
  exit 1
fi

printf 'Online and offline installer variants\n'
grep -Fq 'Usage: %s [--variant online|offline]' \
  "$project_root/scripts/build-iso.sh"
grep -Fq 'iso_name="aero7-beta2-online"' \
  "$project_root/scripts/build-iso.sh"
grep -Fq 'iso_name="aero7-beta2-offline"' \
  "$project_root/scripts/build-iso.sh"
grep -Fq 'install-variant' "$project_root/scripts/build-iso.sh"
grep -Fq 'if variant == "offline"' \
  "$project_root/backend/aero7_install_backend.py"
grep -Fq 'ensure_install_network()' \
  "$project_root/backend/aero7_install_backend.py"
grep -Fq 'if variant == "online"' \
  "$project_root/backend/aero7_shell_adapter.py"
grep -Fq 'offline-packages/aero7/' \
  "$project_root/backend/aero7_shell_adapter.py"
grep -Fq '/etc/pacman-aero7-offline.conf' \
  "$project_root/backend/aero7_shell_adapter.py"
grep -Fq 'offline-aero7-repo.sha256' \
  "$project_root/scripts/verify-release.sh"
grep -Fqx '/offline-packages/' "$project_root/.gitignore"
[[ -x "$project_root/scripts/prepare-offline-packages.sh" ]] || {
  printf 'The offline package preparation script is not executable.\n' >&2
  exit 1
}
grep -Fq 'pacman -Sy --noconfirm' \
  "$project_root/scripts/prepare-offline-packages.sh"
grep -Fq 'Aero7 Beta 2 %s image verification passed.' \
  "$project_root/scripts/verify-release.sh"

printf 'Live package mirrors\n'
mirrorlist="$project_root/archiso/airootfs/etc/pacman.d/mirrorlist"
[[ -s "$mirrorlist" ]] || { printf 'The live Arch mirrorlist is missing.\n' >&2; exit 1; }
if ! grep -Eq '^[[:space:]]*Server[[:space:]]*=' "$mirrorlist"; then
  printf 'The live Arch mirrorlist has no enabled servers.\n' >&2
  exit 1
fi
grep -Fqx 'Requires=pacman-init.service' \
  "$project_root/archiso/airootfs/etc/systemd/system/aero7-installer.service"
grep -Fqx 'Wants=systemd-logind.service systemd-resolved.service NetworkManager.service' \
  "$project_root/archiso/airootfs/etc/systemd/system/aero7-installer.service"
grep -Fqx 'dns=systemd-resolved' \
  "$project_root/archiso/airootfs/etc/NetworkManager/conf.d/10-aero7-live-dns.conf"
grep -Fq '/run/systemd/resolve/stub-resolv.conf' \
  "$project_root/scripts/build-iso.sh"
grep -Fq 'multi-user.target.wants/systemd-resolved.service' \
  "$project_root/scripts/build-iso.sh"
grep -Fqx 'ExecStart=/usr/bin/pacman-key --populate' \
  "$project_root/archiso/airootfs/etc/systemd/system/pacman-init.service"
for advanced_storage_package in ntfsprogs parted; do
  grep -Fqx "$advanced_storage_package" "$project_root/archiso/packages.x86_64" || {
    printf 'Advanced storage package is missing from the live ISO: %s\n' \
      "$advanced_storage_package" >&2
    exit 1
  }
done
grep -Fq 'def backup_partition_table(' \
  "$project_root/backend/aero7_install_backend.py"
grep -Fq 'r"/dev/(?:vd[a-z]|sd[a-z]|nvme\d+n\d+|mmcblk\d+)"' \
  "$project_root/backend/aero7_install_backend.py"
grep -Fq 'real installation must run from booted Aero7 installation media' \
  "$project_root/backend/aero7_install_backend.py"
if rg -n 'VM_MARKERS|restricted to a recognized virtual machine|only a QEMU VirtIO' \
    "$project_root/backend/aero7_install_backend.py" >/dev/null 2>&1; then
  printf 'The backend still contains the retired VM-only execution gate.\n' >&2
  exit 1
fi
grep -Fq '"--no-act",' \
  "$project_root/backend/aero7_install_backend.py"
grep -Fq 'runner.run(["ntfsresize", "--check", partition])' \
  "$project_root/backend/aero7_install_backend.py"
grep -Fqx 'Environment=WLR_RENDERER=pixman' \
  "$project_root/oobe/aero7-oobe.service"
grep -Fqx 'Environment=WLR_NO_HARDWARE_CURSORS=1' \
  "$project_root/oobe/aero7-oobe.service"
for shell_executable in \
  install.sh \
  uninstall.sh \
  update.sh \
  commands/aero7 \
  commands/aero7-dir \
  commands/aero7-ipconfig \
  commands/aero7-systeminfo \
  commands/aero7-winver; do
  grep -Fq "[\"/usr/share/aero7/source/$shell_executable\"]=\"0:0:755\"" \
    "$project_root/archiso/profiledef.sh"
done

printf 'QML syntax\n'
mapfile -t qml_files < <(find "$project_root/installer/qml" -type f -name '*.qml' -print | sort)
qml_linter=""
for qml_linter_candidate in \
  "${AERO7_QMLLINT:-}" \
  /usr/lib/qt6/bin/qmllint \
  "$(command -v qmllint6 || true)" \
  "$(command -v qmllint || true)"; do
  if [[ -n "$qml_linter_candidate" && -x "$qml_linter_candidate" ]]; then
    qml_linter="$qml_linter_candidate"
    break
  fi
done
[[ -n "$qml_linter" ]] || {
  printf 'Qt 6 qmllint is not installed.\n' >&2
  exit 1
}
printf 'Using %s\n' "$qml_linter"
"$qml_linter" "${qml_files[@]}"
if rg -n 'Continue|AeroButton' \
  "$project_root/installer/qml/screens/OobeWelcomeScreen.qml" >/dev/null 2>&1; then
  printf 'The automatic OOBE Welcome screen still contains a manual button.\n' >&2
  exit 1
fi
grep -Fq 'opacity: controller.desktopHandoff ? 1 : 0' \
  "$project_root/installer/qml/Main.qml"
grep -Fq 'QStringLiteral("aero7-first-login-cleanup.timer")' \
  "$project_root/installer/src/installercontroller.cpp"
grep -Fq 'QStringLiteral("sddm.service")' \
  "$project_root/installer/src/installercontroller.cpp"
grep -Fq 'Q_PROPERTY(int progressStagePercent READ progressStagePercent NOTIFY progressChanged)' \
  "$project_root/installer/src/installercontroller.h"
grep -Fq 'stage_percent=self.stage_percent' \
  "$project_root/backend/aero7_install_backend.py"
grep -Fq 'magick "$project_root/installer/assets/aero7-background.png" -strip -quality 92 "$login_background"' \
  "$project_root/scripts/build-iso.sh" || {
  printf 'SDDM must use the same background as the Welcome screen.\n' >&2
  exit 1
}
grep -Fq 'brand_plasma_look_and_feel()' \
  "$project_root/backend/aero7_install_backend.py"
if rg -n '\balpha software\b' "$project_root/installer/qml" >/dev/null 2>&1; then
  printf 'Installer still identifies the release as alpha software.\n' >&2
  exit 1
fi

printf 'Pinned visual assets\n'
for required_file in \
  "$project_root/third_party/PlymouthVista/LICENSE" \
  "$project_root/third_party/PlymouthVista/generate-aero7-boot-frames.sh" \
  "$project_root/third_party/PlymouthVista/PlymouthVista.plymouth" \
  "$project_root/third_party/PlymouthVista/PlymouthVista.script" \
  "$project_root/third_party/PlymouthVista/images/aero7-logo-plain.png" \
  "$project_root/third_party/PlymouthVista/images/aero7-auth-background.png" \
  "$project_root/third_party/PlymouthVista/images/flag0.png" \
  "$project_root/third_party/PlymouthVista/images/flag104.png" \
  "$project_root/third_party/AeroThemePlasma-LICENSE" \
  "$project_root/third_party/AdwaitaFonts-LICENSE" \
  "$project_root/third_party/SMOD-LICENSE" \
  "$project_root/installer/assets/aero7-logo-circle.png" \
  "$project_root/installer/assets/aero7-logo-plain.png" \
  "$project_root/installer/assets/aero7-sddm-branding.png" \
  "$project_root/installer/assets/aero-shell/aero7-user.png" \
  "$project_root/installer/assets/aero-shell/aero7-background.png" \
  "$project_root/installer/assets/cursors/aero-pointer.svg" \
  "$project_root/installer/assets/fonts/AdwaitaSans-Regular.ttf" \
  "$project_root/installer/assets/loading/spinner_0.png" \
  "$project_root/installer/assets/loading/spinner_17.png" \
  "$project_root/installer/assets/icons/check-green.svg" \
  "$project_root/installer/assets/icons/recycle-bin.svg" \
  "$project_root/installer/assets/smod/top.png" \
  "$project_root/installer/assets/smod/close.png" \
  "$project_root/installer/assets/controls/button-normal.png"; do
  [[ -s "$required_file" ]] || { printf 'Missing visual asset: %s\n' "$required_file" >&2; exit 1; }
done
if find "$project_root/installer/assets/aero-shell" -maxdepth 1 -type f \
    \( -name 'aero_bg_1.png' -o -name 'aero_bg_2.jpeg' -o -name 'aero_bg_3.jpg' \) \
    -print -quit | grep -q .; then
  printf 'A retired desktop wallpaper is still bundled.\n' >&2
  exit 1
fi
printf '%s  %s\n' \
  'ba52528d0353c4e474b6e9e007ad53dfc36f2b4c7a11283bafc066d21de5aaca' "$project_root/installer/assets/aero-shell/aero7-background.png" \
  | sha256sum --check --status || {
  printf 'The Aero7 desktop wallpaper differs from the approved artwork.\n' >&2
  exit 1
}
printf '%s  %s\n' \
  '1e2b19e4a706259462169ff25d5a7cc659b29f5989d45c4ba588fc8ac002727c' "$project_root/third_party/PlymouthVista/PlymouthVista.script" \
  '5632d386115028d42b07eaca5c345ed03203ebe61dcd7bd222f1a644ee93d1c6' "$project_root/third_party/PlymouthVista/images/aero7-logo-plain.png" \
  '7852558af39cea34b64f20e87a3ee0f2b3009f70f8f45c4261b1b4e15c1bc305' "$project_root/third_party/PlymouthVista/images/flag0.png" \
  'f65b1c839e1db631bfd985209ef18942e38f7c830a48577276667bd459ceb2cf' "$project_root/third_party/PlymouthVista/images/flag104.png" \
  | sha256sum --check --status || {
  printf 'Plymouth assets differ from the approved Aero7 animation.\n' >&2
  exit 1
}
branding_geometry="$(magick identify -format '%wx%h' "$project_root/installer/assets/aero7-sddm-branding.png")"
[[ "$branding_geometry" == "350x50" ]] || {
  printf 'Unexpected SDDM branding dimensions: %s\n' "$branding_geometry" >&2
  exit 1
}
approved_branding_hash='d45164d6d67f2d8ccae63c4fd83bd0dd73e05808f3c8cd739c4850b5680d4982'
printf '%s  %s\n' "$approved_branding_hash" \
  "$project_root/installer/assets/aero7-sddm-branding.png" \
  | sha256sum --check --status || {
  printf 'The login and lock-screen branding differs from the approved corrected artwork.\n' >&2
  exit 1
}
branding_visible_bounds="$(
  magick "$project_root/installer/assets/aero7-sddm-branding.png" \
    -alpha extract -trim -format '%@' info:
)"
[[ "$branding_visible_bounds" == '223x45+0+0' ]] || {
  printf 'Unexpected visible branding bounds: %s\n' "$branding_visible_bounds" >&2
  exit 1
}
magick identify -format '%[channels]' \
  "$project_root/installer/assets/aero7-sddm-branding.png" | grep -qi 'a' || {
  printf 'SDDM branding must retain a transparent alpha channel.\n' >&2
  exit 1
}

theme_package_path="$(
  awk '$2 ~ /^local-packages\/aerothemeplasma-desktop-git-.*\.pkg\.tar\.zst$/ { print $2 }' \
    "$local_package_manifest"
)"
[[ -n "$theme_package_path" && -f "$project_root/$theme_package_path" ]] || {
  printf 'The embedded AeroTheme desktop package is missing.\n' >&2
  exit 1
}
for branding_member in \
  usr/share/sddm/themes/sddm-theme-mod/Assets/aero7-branding-r3.png \
  usr/share/plasma/shells/io.gitgud.wackyideas.desktop/contents/images/branding.png; do
  embedded_branding_hash="$(
    bsdtar -xOf "$project_root/$theme_package_path" "$branding_member" \
      | sha256sum | cut -d ' ' -f 1
  )"
  [[ "$embedded_branding_hash" == "$approved_branding_hash" ]] || {
    printf 'The embedded AeroTheme package contains stale branding: %s\n' \
      "$branding_member" >&2
    exit 1
  }
done

desktop_package_path="$(
  awk '$2 ~ /^local-packages\/aero7-desktop-.*\.pkg\.tar\.zst$/ { print $2 }' \
    "$local_package_manifest"
)"
[[ -n "$desktop_package_path" && -f "$project_root/$desktop_package_path" ]] || {
  printf 'The embedded Aero7 Desktop package is missing.\n' >&2
  exit 1
}
desktop_layout="$(
  bsdtar -xOf "$project_root/$desktop_package_path" \
    usr/share/aero7-desktop/shell/aero7-shell-layout.js
)"
factory_launchers="$(
  sed -n '/^var defaultLaunchers = \[/,/^\];/p' <<<"$desktop_layout"
)"
grep -Fq '"applications:org.aero7.FileExplorer.desktop"' \
  <<<"$factory_launchers" || {
  printf 'The default taskbar does not pin the case-correct File Explorer identity.\n' >&2
  exit 1
}
if grep -Fq 'org.aero7.fileexplorer.desktop' <<<"$factory_launchers"; then
  printf 'The default taskbar still contains the broken lowercase File Explorer pin.\n' >&2
  exit 1
fi
grep -Fq 'function isPreviousFactoryLayout(launchers)' <<<"$desktop_layout" || {
  printf 'The desktop package cannot migrate the earlier broken factory taskbar.\n' >&2
  exit 1
}
for logo_asset in aero7-logo-circle.png aero7-logo-plain.png; do
  logo_geometry="$(magick identify -format '%wx%h' "$project_root/installer/assets/$logo_asset")"
  [[ "$logo_geometry" == "512x512" ]] || {
    printf 'Unexpected %s dimensions: %s\n' "$logo_asset" "$logo_geometry" >&2
    exit 1
  }
  magick identify -format '%[channels]' \
    "$project_root/installer/assets/$logo_asset" | grep -qi 'a' || {
    printf '%s must retain a transparent alpha channel.\n' "$logo_asset" >&2
    exit 1
  }
done
if cmp -s "$project_root/installer/assets/aero7-logo-circle.png" \
    "$project_root/installer/assets/aero7-logo-plain.png"; then
  printf 'Circular and standalone Aero7 logos unexpectedly match.\n' >&2
  exit 1
fi
grep -Fqx 'ModuleName=script' "$project_root/third_party/PlymouthVista/PlymouthVista.plymouth"
grep -Fq 'global.PasswordTitle = "Aero7 Boot Manager";' "$project_root/third_party/PlymouthVista/PlymouthVista.script"
grep -Fq 'global.AnswerTitle = "Aero7 Boot Manager";' "$project_root/third_party/PlymouthVista/PlymouthVista.script"
grep -Fq 'global.UpdateTextMTL = "Configuring Aero7 updates\n%i% complete\nDo not turn off your computer.";' "$project_root/third_party/PlymouthVista/PlymouthVista.script"
grep -Fq 'global.StartingText = "Starting Aero7";' "$project_root/third_party/PlymouthVista/PlymouthVista.script"
grep -Fq 'global.ResumingText = "Resuming Aero7";' "$project_root/third_party/PlymouthVista/PlymouthVista.script"
grep -Fq 'global.CopyrightText = "Aero7 Open Project";' "$project_root/third_party/PlymouthVista/PlymouthVista.script"
grep -Fq 'self.Current = 76;' "$project_root/third_party/PlymouthVista/PlymouthVista.script"
grep -Fq 'Image("flag" + i + ".png")' "$project_root/third_party/PlymouthVista/PlymouthVista.script"
grep -Fqx 'logo_size=108' "$project_root/third_party/PlymouthVista/generate-aero7-boot-frames.sh"
grep -Fq 'scale=${logo_size}:${logo_size}' "$project_root/third_party/PlymouthVista/generate-aero7-boot-frames.sh"
grep -Fq 'overlay=(W-w)/2:(H-h)/2' "$project_root/third_party/PlymouthVista/generate-aero7-boot-frames.sh"
if rg -n 'Image\("branding_|Image\("authui_' "$project_root/third_party/PlymouthVista/PlymouthVista.script" >/dev/null 2>&1; then
  printf 'Plymouth script still references replaced branding or auth artwork.\n' >&2
  exit 1
fi
for removed_asset in \
  authui_7.png authui_vista.png branding_7.png branding_vista.png \
  base.png progress.png resumevista.png \
  resumebar1.png resumebar2.png resumebar3.png resumebar4.png \
  resumebar5.png resumebar6.png resumebar7.png resumebar8.png \
  resumebar9.png resumebar10.png; do
  if [[ -e "$project_root/third_party/PlymouthVista/images/$removed_asset" ]]; then
    printf 'Unused upstream Plymouth bitmap returned: %s\n' "$removed_asset" >&2
    exit 1
  fi
done
if rg -n 'LegacyBootScreen|UseLegacyBootScreen|UseNoGuiResume|NoGuiResumeText|Windows Boot Manager|Configuring Windows updates|Resuming Windows' \
    "$project_root/third_party/PlymouthVista/PlymouthVista.script" >/dev/null 2>&1; then
  printf 'Plymouth script still contains removed legacy boot code or Windows labels.\n' >&2
  exit 1
fi
if [[ -e "$project_root/installer/assets/aero7-mark.png" \
    || -e "$project_root/installer/assets/aero7-mark.svg" ]] \
    || rg -n 'aero7-mark' "$project_root/installer" >/dev/null 2>&1; then
  printf 'The retired temporary A mark is still present or referenced.\n' >&2
  exit 1
fi

printf 'Aero7-shell package parity\n'
while IFS= read -r package_name; do
  [[ -n "$package_name" && "$package_name" != \#* ]] || continue
  case "$package_name" in
    # Source-build and optional utility packages used by the standalone shell
    # installer are intentionally absent from the binary-package ISO target.
    cmake|extra-cmake-modules|ninja|base-devel|wayland-protocols|vulkan-headers|kate|okular)
      continue
      ;;
  esac
  grep -Fqx "$package_name" "$project_root/config/base-packages.txt" || {
    printf 'Base package from the pinned shell installer is missing: %s\n' "$package_name" >&2
    exit 1
  }
done < "$source_path/config/packages.conf"
while IFS= read -r package_name; do
  [[ -n "$package_name" && "$package_name" != \#* ]] || continue
  grep -Fqx "$package_name" "$project_root/config/aero7-packages.txt" || {
    printf 'Aero package from the pinned shell installer is missing: %s\n' "$package_name" >&2
    exit 1
  }
done < "$source_path/config/aur-packages.conf"
while IFS= read -r package_name; do
  [[ -n "$package_name" && "$package_name" != \#* ]] || continue
  grep -Fqx "$package_name" "$project_root/config/aero7-packages.txt" || {
    printf 'Aero companion package from the pinned shell installer is missing: %s\n' "$package_name" >&2
    exit 1
  }
done < "$source_path/config/companion-packages.conf"
grep -Fqx plasma-desktop "$project_root/config/base-packages.txt" || {
  printf 'The focused plasma-desktop package is missing from the installed system.\n' >&2
  exit 1
}
for excluded_target_package in \
  plasma-meta kde-applications-meta \
  cmake extra-cmake-modules ninja base-devel wayland-protocols vulkan-headers \
  kate okular konsole; do
  if grep -Fqx "$excluded_target_package" "$project_root/config/base-packages.txt"; then
    printf 'Unwanted target package is present: %s\n' "$excluded_target_package" >&2
    exit 1
  fi
done
for required_desktop_application in qterminal vlc spectacle kcalc featherpad; do
  if ! grep -Fqx "$required_desktop_application" "$project_root/config/base-packages.txt"; then
    printf 'Required Aero7 desktop application is missing: %s\n' "$required_desktop_application" >&2
    exit 1
  fi
done
for required_control_panel_backend in plasma-nm iptables ufw hunspell hunspell-en_us hunspell-nl \
    accountsservice upower power-profiles-daemon pipewire-pulse wireplumber; do
  if ! grep -Fqx "$required_control_panel_backend" "$project_root/config/base-packages.txt"; then
    printf 'Required Control Panel backend package is missing: %s\n' \
      "$required_control_panel_backend" >&2
    exit 1
  fi
done
grep -Fq '"systemctl", "enable", "ufw.service"' \
  "$project_root/backend/aero7_install_backend.py" || {
    printf 'The installed system does not enable UFW rule restoration.\n' >&2
    exit 1
  }
for available_application in linux-devmgmt tuxmanager; do
  grep -Fqx "$available_application" "$project_root/config/aero7-packages.txt" || {
    printf 'Available shell application package is missing: %s\n' "$available_application" >&2
    exit 1
  }
done
if grep -Fqx winxplorer "$project_root/config/aero7-packages.txt"; then
  printf 'WinXplorer must remain optional and must not be installed by the ISO.\n' >&2
  exit 1
fi
grep -Fqx oxygen-icons "$project_root/config/base-packages.txt" || {
  printf 'The Oxygen fallback icon set is missing from the ISO.\n' >&2
  exit 1
}
grep -Fq 'io.gitgud.wackyideas.panel' \
  "$source_path/modules/plasma/first-login.sh" || {
  printf 'The pinned shell is missing duplicate-panel repair.\n' >&2
  exit 1
}
grep -Fq 'new Panel("io.gitgud.wackyideas.panel")' \
  "$source_path/lib/plasma.sh" || {
  printf 'The pinned shell layout does not create the canonical Aero taskbar.\n' >&2
  exit 1
}
if sed -n '/aero7_apply_plasma_layout()/,/^}/p' \
    "$source_path/lib/plasma.sh" | \
    grep -Fq 'org.kde.plasma.icontasks'; then
  printf 'The pinned shell layout still creates a duplicate stock KDE taskbar.\n' >&2
  exit 1
fi
grep -Fq 'aero7-login-background.jpg' \
  "$source_path/lib/plasma.sh" || {
  printf 'The pinned shell does not preserve the blue Welcome login background.\n' >&2
  exit 1
}
grep -Fq 'Name=Command Prompt' \
  "$source_path/lib/applications.sh" || {
  printf 'The pinned shell is missing Command Prompt application branding.\n' >&2
  exit 1
}
for branded_application in 'Name=Media Player' 'Name=Snipping Tool' \
  'Name=Calculator' 'Name=Notepad'; do
  grep -Fq "$branded_application" \
    "$source_path/lib/applications.sh" || {
    printf 'The pinned shell is missing application branding: %s\n' \
      "$branded_application" >&2
    exit 1
  }
done
grep -Fq 'Exec=/usr/bin/spectacle -r -b -c' \
  "$source_path/lib/applications.sh" || {
  printf 'The pinned shell is missing the Snipping Tool capture command.\n' >&2
  exit 1
}
grep -Fq 'aero7-snipping-tool-print.desktop' \
  "$source_path/lib/applications.sh" || {
  printf 'The pinned shell is missing the Print Screen shortcut service.\n' >&2
  exit 1
}

if command -v shellcheck >/dev/null 2>&1; then
  printf 'ShellCheck\n'
  shellcheck --severity=warning \
    "$project_root"/scripts/*.sh "$project_root/archiso/profiledef.sh"
else
  printf 'SKIP: shellcheck is not installed\n'
fi

printf 'Static checks passed\n'
