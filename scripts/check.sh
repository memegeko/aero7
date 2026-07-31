#!/usr/bin/env bash
set -Eeuo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

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

printf 'QEMU UEFI boot order\n'
grep -Fq -- '-device "virtio-blk-pci,drive=aero7disk,bootindex=1"' \
  "$project_root/scripts/run-qemu.sh"
grep -Fq -- '-device "ide-cd,drive=aero7cd,bootindex=2"' \
  "$project_root/scripts/run-qemu.sh"
grep -Fq 'release_name="$(sed -n' "$project_root/scripts/run-qemu.sh"
grep -Fq 'Older images in out/ are deliberately ignored' \
  "$project_root/scripts/run-qemu.sh"
grep -Fq 'display_backend="sdl"' "$project_root/scripts/run-qemu.sh"
grep -Fq 'display_spec="sdl,gl=off"' "$project_root/scripts/run-qemu.sh"
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
grep -Fq "failed-\${stale_staging##*/}-\$build_stamp" \
  "$project_root/scripts/build-iso.sh"

printf 'Live package mirrors\n'
mirrorlist="$project_root/archiso/airootfs/etc/pacman.d/mirrorlist"
[[ -s "$mirrorlist" ]] || { printf 'The live Arch mirrorlist is missing.\n' >&2; exit 1; }
if ! grep -Eq '^[[:space:]]*Server[[:space:]]*=' "$mirrorlist"; then
  printf 'The live Arch mirrorlist has no enabled servers.\n' >&2
  exit 1
fi
grep -Fqx 'Requires=pacman-init.service' \
  "$project_root/archiso/airootfs/etc/systemd/system/aero7-installer.service"
grep -Fqx 'ExecStart=/usr/bin/pacman-key --populate' \
  "$project_root/archiso/airootfs/etc/systemd/system/pacman-init.service"
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
qmllint "${qml_files[@]}"
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
grep -Fq 'brand_plasma_look_and_feel()' \
  "$project_root/backend/aero7_install_backend.py"
if rg -n '\balpha software\b' "$project_root/installer/qml" >/dev/null 2>&1; then
  printf 'Installer still identifies the release as alpha software.\n' >&2
  exit 1
fi

printf 'Pinned visual assets\n'
for required_file in \
  "$project_root/third_party/PlymouthVista/LICENSE" \
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
  "$project_root/installer/assets/aero-shell/aero_bg_1.png" \
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
branding_geometry="$(magick identify -format '%wx%h' "$project_root/installer/assets/aero7-sddm-branding.png")"
[[ "$branding_geometry" == "350x50" ]] || {
  printf 'Unexpected SDDM branding dimensions: %s\n' "$branding_geometry" >&2
  exit 1
}
magick identify -format '%[channels]' \
  "$project_root/installer/assets/aero7-sddm-branding.png" | grep -qi 'a' || {
  printf 'SDDM branding must retain a transparent alpha channel.\n' >&2
  exit 1
}
grep -Fqx 'ModuleName=script' "$project_root/third_party/PlymouthVista/PlymouthVista.plymouth"
grep -Fq 'global.UseLegacyBootScreen = 0;' "$project_root/third_party/PlymouthVista/PlymouthVista.script"
grep -Fq 'global.StartingText = "Starting Aero7";' "$project_root/third_party/PlymouthVista/PlymouthVista.script"
grep -Fq 'Image("flag" + i + ".png")' "$project_root/third_party/PlymouthVista/PlymouthVista.script"
if rg -n 'Image\("branding_|Image\("authui_' "$project_root/third_party/PlymouthVista/PlymouthVista.script" >/dev/null 2>&1; then
  printf 'Plymouth script still references replaced branding or auth artwork.\n' >&2
  exit 1
fi

printf 'Aero7-shell package parity\n'
while IFS= read -r package_name; do
  [[ -n "$package_name" && "$package_name" != \#* ]] || continue
  grep -Fqx "$package_name" "$project_root/config/base-packages.txt" || {
    printf 'Base package from the pinned shell installer is missing: %s\n' "$package_name" >&2
    exit 1
  }
done < "$project_root/../aero_desktop/config/packages.conf"
while IFS= read -r package_name; do
  [[ -n "$package_name" && "$package_name" != \#* ]] || continue
  grep -Fqx "$package_name" "$project_root/config/aero7-packages.txt" || {
    printf 'Aero package from the pinned shell installer is missing: %s\n' "$package_name" >&2
    exit 1
  }
done < "$project_root/../aero_desktop/config/aur-packages.conf"
while IFS= read -r package_name; do
  [[ -n "$package_name" && "$package_name" != \#* ]] || continue
  grep -Fqx "$package_name" "$project_root/config/aero7-packages.txt" || {
    printf 'Aero companion package from the pinned shell installer is missing: %s\n' "$package_name" >&2
    exit 1
  }
done < "$project_root/../aero_desktop/config/companion-packages.conf"
for available_application in linux-devmgmt tuxmanager; do
  grep -Fqx "$available_application" "$project_root/config/aero7-packages.txt" || {
    printf 'Available shell application package is missing: %s\n' "$available_application" >&2
    exit 1
  }
done

if command -v shellcheck >/dev/null 2>&1; then
  printf 'ShellCheck\n'
  shellcheck "$project_root"/scripts/*.sh "$project_root/archiso/profiledef.sh"
else
  printf 'SKIP: shellcheck is not installed\n'
fi

printf 'Static checks passed\n'
