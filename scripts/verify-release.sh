#!/usr/bin/env bash
set -Eeuo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

if (($# != 1)); then
  printf 'Usage: %s IMAGE.iso\n' "${0##*/}" >&2
  exit 2
fi
image="$(realpath -e "$1")"
case "${image##*/}" in
  aero7-beta2-online-*.iso) expected_variant="online" ;;
  aero7-beta2-offline-*.iso) expected_variant="offline" ;;
  *)
    printf 'The image name does not identify an Aero7 Beta 2 variant: %s\n' \
      "${image##*/}" >&2
    exit 2
    ;;
esac

for command_name in file rg sha256sum strings unsquashfs xorriso; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Missing release verification tool: %s\n' "$command_name" >&2
    exit 1
  }
done

verify_root="$(mktemp -d /tmp/aero7-release-verify.XXXXXX)"
cleanup_verify_root() {
  chmod -R u+w "$verify_root" 2>/dev/null || true
  rm -rf -- "$verify_root"
}
trap cleanup_verify_root EXIT
squashfs="$verify_root/airootfs.sfs"
loader="$verify_root/01-aero7.conf"
embedded_lock="$verify_root/sources.lock"
embedded_plasma="$verify_root/plasma.sh"
embedded_applications="$verify_root/applications.sh"
embedded_base_packages="$verify_root/base-packages.txt"
embedded_aero7_packages="$verify_root/aero7-packages.txt"
embedded_local_manifest="$verify_root/beta2-local-packages.sha256"
embedded_optional_names="$verify_root/beta2-optional-package-names.txt"
embedded_collector="$verify_root/aero7-collect-logs"
embedded_variant="$verify_root/install-variant"

file "$image"
sha256sum "$image"
xorriso -indev "$image" -pvd_info
xorriso -osirrox on -indev "$image" \
  -extract /aero7/x86_64/airootfs.sfs "$squashfs" \
  -extract /loader/entries/01-aero7.conf "$loader"

grep -Fq 'quiet splash' "$loader"
grep -Fq 'plymouth.ignore-serial-consoles' "$loader"
unsquashfs -stat "$squashfs"
unsquashfs -cat "$squashfs" usr/share/aero7/install-variant >"$embedded_variant"
[[ "$(cat "$embedded_variant")" == "$expected_variant" ]] || {
  printf 'The embedded installer variant does not match the ISO name.\n' >&2
  exit 1
}
unsquashfs -cat "$squashfs" usr/share/aero7/beta2-optional-package-names.txt \
  >"$embedded_optional_names"
cmp -s "$project_root/config/beta2-optional-package-names.txt" "$embedded_optional_names"

unsquashfs -cat "$squashfs" usr/lib/aero7/aero7-install-backend \
  | rg -F 'def brand_plasma_look_and_feel(' >/dev/null
unsquashfs -cat "$squashfs" usr/lib/aero7/aero7-install-backend \
  | rg -F 'aero7-first-login-cleanup.timer' >/dev/null
unsquashfs -cat "$squashfs" usr/lib/aero7/aero7-install-backend \
  | rg -F 'ExecStartPre=/usr/bin/sleep' >/dev/null
unsquashfs -cat "$squashfs" usr/lib/aero7/aero7-install-backend \
  | rg -F 'def backup_partition_table(' >/dev/null
unsquashfs -cat "$squashfs" usr/lib/aero7/aero7-install-backend \
  | rg -F '"ntfsresize", "--check", partition' >/dev/null
unsquashfs -cat "$squashfs" usr/lib/aero7/aero7-install-backend \
  | rg -F 'configure_diagnostic_logging(username)' >/dev/null
unsquashfs -cat "$squashfs" usr/lib/aero7/aero7-install-backend \
  | rg -F 'if variant == "offline"' >/dev/null
unsquashfs -cat "$squashfs" usr/lib/aero7/aero7_shell_adapter.py \
  | rg -F 'package for package in requested_packages if package not in embedded_names' \
  >/dev/null
unsquashfs -cat "$squashfs" usr/lib/aero7/aero7-collect-logs \
  >"$embedded_collector"
rg -F 'Aero7 Physical Install Logs' "$embedded_collector" >/dev/null
rg -F 'session_display_available' "$embedded_collector" >/dev/null
rg -F 'pacman -Q plasma-workspace' "$embedded_collector" >/dev/null
rg -F 'pacman -Q kwin' "$embedded_collector" >/dev/null
if rg -n 'capture .* (plasmashell|kwin_wayland) --version' \
    "$embedded_collector" >/dev/null 2>&1; then
  printf 'The embedded diagnostic collector launches a GUI version probe.\n' >&2
  exit 1
fi
unsquashfs -cat "$squashfs" usr/lib/systemd/system/aero7-diagnostic-collect.timer \
  | rg -F 'OnUnitActiveSec=10min' >/dev/null
unsquashfs -cat "$squashfs" usr/lib/systemd/user/aero7-diagnostic-session.timer \
  | rg -F 'OnUnitActiveSec=5min' >/dev/null
unsquashfs -cat "$squashfs" etc/systemd/journald.conf.d/50-aero7-test-logging.conf \
  | rg -F 'Storage=persistent' >/dev/null
for advanced_storage_binary in usr/bin/ntfsresize usr/bin/parted; do
  unsquashfs -cat "$squashfs" "$advanced_storage_binary" >/dev/null
done
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
for required_control_panel_backend in plasma-nm iptables ufw hunspell hunspell-en_us hunspell-nl \
    accountsservice upower power-profiles-daemon pipewire-pulse wireplumber \
    efibootmgr wireless-regdb rtkit; do
  grep -Fqx "$required_control_panel_backend" "$embedded_base_packages"
done
for excluded_target_package in plasma-meta kde-applications-meta konsole; do
  if grep -Fqx "$excluded_target_package" "$embedded_base_packages"; then
    printf 'The release ISO contains an unwanted desktop meta-package: %s\n' \
      "$excluded_target_package" >&2
    exit 1
  fi
done

unsquashfs -cat "$squashfs" usr/share/aero7/aero7-packages.txt \
  >"$embedded_aero7_packages"
cmp -s "$project_root/config/aero7-packages.txt" "$embedded_aero7_packages"
for required_embedded_dependency in aero7-internet-explorer baloo-widgets cups; do
  grep -Fqx "$required_embedded_dependency" "$embedded_aero7_packages"
done

unsquashfs -cat "$squashfs" usr/share/aero7/sources.lock >"$embedded_lock"
cmp -s "$project_root/sources.lock" "$embedded_lock"
unsquashfs -cat "$squashfs" usr/share/aero7/beta2-local-packages.sha256 \
  >"$embedded_local_manifest"
cmp -s "$project_root/config/beta2-local-packages.sha256" "$embedded_local_manifest"
while read -r package_hash package_path; do
  embedded_package="$verify_root/${package_path##*/}"
  unsquashfs -cat "$squashfs" \
    "usr/share/aero7/local-packages/${package_path##*/}" >"$embedded_package"
  printf '%s  %s\n' "$package_hash" "$embedded_package" | sha256sum --check -
done < "$project_root/config/beta2-local-packages.sha256"

if [[ "$expected_variant" == "offline" ]]; then
  offline_root="$verify_root/offline-root"
  unsquashfs -d "$offline_root" "$squashfs" \
    usr/share/aero7/offline-packages \
    usr/share/aero7/offline-base-packages.sha256 \
    usr/share/aero7/offline-aero7-packages.sha256 \
    usr/share/aero7/offline-aero7-repo.sha256 >/dev/null
  share_root="$offline_root/usr/share/aero7"
  cmp -s "$project_root/config/offline-base-packages.sha256" \
    "$share_root/offline-base-packages.sha256"
  cmp -s "$project_root/config/offline-aero7-packages.sha256" \
    "$share_root/offline-aero7-packages.sha256"
  cmp -s "$project_root/config/offline-aero7-repo.sha256" \
    "$share_root/offline-aero7-repo.sha256"
  (
    cd "$share_root"
    sha256sum --check offline-base-packages.sha256
    sha256sum --check offline-aero7-packages.sha256
    sha256sum --check offline-aero7-repo.sha256
  )
else
  if unsquashfs -ll "$squashfs" | rg -F 'usr/share/aero7/offline-packages/' >/dev/null; then
    printf 'The online ISO unexpectedly embeds the offline package bundle.\n' >&2
    exit 1
  fi
fi

if unsquashfs -cat "$squashfs" usr/bin/aero7-installer \
    | strings | rg -Fi 'alpha software' >/dev/null; then
  printf 'The embedded installer still contains the alpha release label.\n' >&2
  exit 1
fi

printf 'Aero7 Beta 2 %s image verification passed.\n' "$expected_variant"
