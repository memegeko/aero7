#!/usr/bin/env bash
set -Eeuo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
out_root="$project_root/out"

for command_name in file rg sha256sum strings unsquashfs xorriso; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Missing release verification tool: %s\n' "$command_name" >&2
    exit 1
  }
done

mapfile -d '' images < <(
  find "$out_root" -maxdepth 1 -type f -name 'aero7-beta1-*.iso' -print0
)
if ((${#images[@]} != 1)); then
  printf 'Expected exactly one Aero7 Beta 1 ISO, found %d.\n' "${#images[@]}" >&2
  exit 1
fi
image="${images[0]}"

verify_root="$(mktemp -d /tmp/aero7-release-verify.XXXXXX)"
trap 'rm -rf -- "$verify_root"' EXIT
squashfs="$verify_root/airootfs.sfs"
loader="$verify_root/01-aero7.conf"
embedded_lock="$verify_root/sources.lock"
embedded_plasma="$verify_root/plasma.sh"
embedded_applications="$verify_root/applications.sh"
embedded_base_packages="$verify_root/base-packages.txt"

file "$image"
sha256sum "$image"
xorriso -indev "$image" -pvd_info
xorriso -osirrox on -indev "$image" \
  -extract /aero7/x86_64/airootfs.sfs "$squashfs" \
  -extract /loader/entries/01-aero7.conf "$loader"

grep -Fq 'quiet splash' "$loader"
grep -Fq 'plymouth.ignore-serial-consoles' "$loader"
unsquashfs -stat "$squashfs"

unsquashfs -cat "$squashfs" usr/lib/aero7/aero7-install-backend \
  | rg -F 'def brand_plasma_look_and_feel(' >/dev/null
unsquashfs -cat "$squashfs" usr/lib/aero7/aero7-install-backend \
  | rg -F 'aero7-first-login-cleanup.timer' >/dev/null
unsquashfs -cat "$squashfs" usr/lib/aero7/aero7-install-backend \
  | rg -F 'ExecStartPre=/usr/bin/sleep' >/dev/null
unsquashfs -cat "$squashfs" usr/bin/aero7-installer \
  | strings | rg -F 'Aero7 is beta software supplied without warranty' >/dev/null
unsquashfs -cat "$squashfs" usr/bin/aero7-installer \
  | strings -el | rg -F 'aero7-first-login-cleanup.timer' >/dev/null

unsquashfs -cat "$squashfs" usr/share/aero7/source/lib/plasma.sh >"$embedded_plasma"
rg -F 'new Panel("io.gitgud.wackyideas.panel")' "$embedded_plasma" >/dev/null
if sed -n '/aero7_apply_plasma_layout()/,/^}/p' "$embedded_plasma" \
    | rg -F 'org.kde.plasma.icontasks' >/dev/null; then
  printf 'The embedded shell still creates a duplicate stock KDE taskbar.\n' >&2
  exit 1
fi

unsquashfs -cat "$squashfs" usr/share/aero7/source/lib/applications.sh \
  >"$embedded_applications"
rg -F 'Name=Command Prompt' "$embedded_applications" >/dev/null
rg -F 'Name=Media Player' "$embedded_applications" >/dev/null
rg -F 'Name=Snipping Tool' "$embedded_applications" >/dev/null
rg -F 'Name=Calculator' "$embedded_applications" >/dev/null
rg -F 'Name=Notepad' "$embedded_applications" >/dev/null
rg -F 'Exec=/usr/bin/spectacle -r -b -c' "$embedded_applications" >/dev/null
rg -F 'aero7-snipping-tool-print.desktop' "$embedded_applications" >/dev/null
rg -F 'kbuildsycoca6 --noincremental' "$embedded_applications" >/dev/null
unsquashfs -cat "$squashfs" usr/share/aero7/branding/aero7-login-background.jpg \
  >/dev/null

unsquashfs -cat "$squashfs" usr/share/aero7/base-packages.txt \
  >"$embedded_base_packages"
cmp -s "$project_root/config/base-packages.txt" "$embedded_base_packages"
grep -Fqx plasma-desktop "$embedded_base_packages"
for required_desktop_application in qterminal vlc spectacle kcalc featherpad; do
  grep -Fqx "$required_desktop_application" "$embedded_base_packages"
done
for excluded_target_package in plasma-meta kde-applications-meta konsole; do
  if grep -Fqx "$excluded_target_package" "$embedded_base_packages"; then
    printf 'The release ISO contains an unwanted desktop meta-package: %s\n' \
      "$excluded_target_package" >&2
    exit 1
  fi
done

unsquashfs -cat "$squashfs" usr/share/aero7/sources.lock >"$embedded_lock"
cmp -s "$project_root/sources.lock" "$embedded_lock"

if unsquashfs -cat "$squashfs" usr/bin/aero7-installer \
    | strings | rg -Fi 'alpha software' >/dev/null; then
  printf 'The embedded installer still contains the alpha release label.\n' >&2
  exit 1
fi

printf 'Aero7 Beta 1 release image verification passed.\n'
