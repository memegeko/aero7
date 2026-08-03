#!/usr/bin/env bash
set -Eeuo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
prepare_only=0
mkarchiso_only=0

usage() {
  printf 'Usage: %s [--prepare-only | --mkarchiso-only]\n' "${0##*/}"
}

while (($#)); do
  case "$1" in
    --prepare-only) prepare_only=1 ;;
    --mkarchiso-only) mkarchiso_only=1 ;;
    --help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

lock_value() {
  local key="$1"
  sed -n "s/^${key}=//p" "$project_root/sources.lock"
}

source_path="$(realpath -m "$project_root/$(lock_value aero7_shell_path)")"
expected_commit="$(lock_value aero7_shell_commit)"
expected_origin="$(lock_value aero7_shell_origin)"
expected_status_hash="$(lock_value aero7_shell_status_sha256)"

verify_source() {
  local actual_commit actual_origin actual_status_hash
  actual_commit="$(git -c "safe.directory=$source_path" -C "$source_path" rev-parse HEAD)"
  actual_origin="$(git -c "safe.directory=$source_path" -C "$source_path" remote get-url origin)"
  actual_status_hash="$(git -c "safe.directory=$source_path" -C "$source_path" status --porcelain=v1 -z | sha256sum | awk '{print $1}')"
  [[ "$actual_commit" == "$expected_commit" ]] || { printf 'Aero7-shell HEAD changed: %s\n' "$actual_commit" >&2; return 1; }
  [[ "$actual_origin" == "$expected_origin" ]] || { printf 'Aero7-shell origin changed: %s\n' "$actual_origin" >&2; return 1; }
  [[ "$actual_status_hash" == "$expected_status_hash" ]] || { printf 'Aero7-shell working tree differs from sources.lock.\n' >&2; return 1; }
}

verify_source
trap verify_source EXIT

build_root="$project_root/build"
work_root="$project_root/work"
profile_root="$work_root/profile"
out_root="$project_root/out"

# Prevent desktop search indexers from entering Archiso's temporary bind mounts.
mkdir -p "$work_root"
touch "$work_root/.metadata_never_index"

if ((mkarchiso_only)); then
  ((EUID == 0)) || { printf '%s must run as root.\n' '--mkarchiso-only' >&2; exit 2; }
  command -v mkarchiso >/dev/null 2>&1 || { printf 'Missing build tool: mkarchiso (install archiso).\n' >&2; exit 1; }
  [[ -x "$profile_root/airootfs/usr/bin/aero7-installer" ]] || { printf 'Prepared profile is missing. Run --prepare-only as your normal user first.\n' >&2; exit 1; }
  if rg -n '@INSTALL_MODE@|@DESTRUCTIVE_ENV@' "$profile_root" >/dev/null 2>&1; then
    printf 'Prepared profile still contains unresolved service placeholders.\n' >&2
    exit 1
  fi
  archiso_work="$work_root/archiso"
  build_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  # Preserve incomplete ISO staging directories from interrupted builds for
  # diagnosis, but keep them out of the next atomic publication attempt.
  while IFS= read -r -d '' stale_staging; do
    mkdir -p "$work_root/archive"
    mv "$stale_staging" "$work_root/archive/failed-${stale_staging##*/}-$build_stamp"
  done < <(find "$work_root" -mindepth 1 -maxdepth 1 -type d -name 'iso-output-*' -print0)
  if [[ -e "$archiso_work" ]]; then
    stale_source="$archiso_work/x86_64/airootfs"
    if [[ -d "$stale_source" ]]; then
      mapfile -t stale_mounts < <(
        while IFS= read -r mount_target; do
          if [[ "$mount_target" == "$stale_source" || "$mount_target" == "$stale_source"/* ]]; then
            printf '%s %s\n' "${#mount_target}" "$mount_target"
          fi
        done < <(findmnt -rn -o TARGET)
        true
      )
      if ((${#stale_mounts[@]})); then
        mapfile -t stale_mounts < <(printf '%s\n' "${stale_mounts[@]}" | sort -rn | cut -d' ' -f2-)
        for mount_target in "${stale_mounts[@]}"; do
          umount "$mount_target" 2>/dev/null || umount -l "$mount_target"
        done
      fi
    fi
    mkdir -p "$work_root/archive"
    mv "$archiso_work" "$work_root/archive/archiso-$build_stamp"
  fi
  staging_out="$work_root/iso-output-$build_stamp"
  [[ ! -e "$staging_out" ]] || { printf 'ISO staging path already exists: %s\n' "$staging_out" >&2; exit 1; }
  mkdir -p "$archiso_work" "$out_root" "$staging_out"
  safe_tools="$work_root/safe-tools"
  install -d -m 0755 "$safe_tools"
  safe_mkarchiso="$safe_tools/mkarchiso-aero7"
  cp "$(command -v mkarchiso)" "$safe_mkarchiso"
  sed -i 's|_unshare mksquashfs "${image_source}"|_unshare "${AERO7_MKSQUASHFS_WRAPPER:?}" "${image_source}"|' "$safe_mkarchiso"
  if ! rg -F '_unshare "${AERO7_MKSQUASHFS_WRAPPER:?}" "${image_source}"' "$safe_mkarchiso" >/dev/null; then
    printf 'Could not install the Aero7 SquashFS safety hook into mkarchiso.\n' >&2
    exit 1
  fi
  chmod 0755 "$safe_mkarchiso"
  AERO7_ARCHISO_SOURCE_ROOT="$archiso_work/x86_64/airootfs" \
    AERO7_MKSQUASHFS_WRAPPER="$project_root/scripts/mksquashfs-safe-wrapper.sh" \
    "$safe_mkarchiso" -v -w "$archiso_work" -o "$staging_out" "$profile_root"
  mapfile -d '' staged_images < <(
    find "$staging_out" -maxdepth 1 -type f -name 'aero7-*.iso' -print0
  )
  if ((${#staged_images[@]} != 1)); then
    printf 'Expected exactly one staged Aero7 ISO, found %d.\n' "${#staged_images[@]}" >&2
    exit 1
  fi
  if find "$out_root" -maxdepth 1 -type f -name 'aero7-*.iso' -print -quit | grep -q .; then
    mkdir -p "$out_root/archive/$build_stamp"
    while IFS= read -r -d '' old_image; do
      mv "$old_image" "$out_root/archive/$build_stamp/"
    done < <(find "$out_root" -maxdepth 1 -type f -name 'aero7-*.iso' -print0)
  fi
  for staged_image in "${staged_images[@]}"; do
    mv "$staged_image" "$out_root/"
  done
  rmdir "$staging_out"
  output_uid="${SUDO_UID:-${PKEXEC_UID:-}}"
  if [[ -z "$output_uid" ]]; then
    project_uid="$(stat -c '%u' "$project_root")"
    if [[ "$project_uid" =~ ^[0-9]+$ && "$project_uid" -ge 1000 ]]; then
      output_uid="$project_uid"
    fi
  fi
  if [[ "$output_uid" =~ ^[0-9]+$ ]]; then
    output_gid="$(id -g "$output_uid")"
    while IFS= read -r -d '' image; do
      chown "$output_uid:$output_gid" "$image"
    done < <(find "$out_root" -maxdepth 1 -type f -name 'aero7-*.iso' -print0)
  elif [[ -n "${SUDO_USER:-}" ]]; then
    while IFS= read -r -d '' image; do
      chown "$SUDO_USER" "$image"
    done < <(find "$out_root" -maxdepth 1 -type f -name 'aero7-*.iso' -print0)
  fi
  printf 'ISO output:\n'
  find "$out_root" -maxdepth 1 -type f -name 'aero7-*.iso' -print
  exit 0
fi

if ((EUID == 0)); then
  printf 'Refusing to compile or assemble the project as root. Run as your normal user first.\n' >&2
  printf 'Then run: sudo %q --mkarchiso-only\n' "$project_root/scripts/build-iso.sh" >&2
  exit 2
fi

for command_name in cmake ninja qmllint python git sha256sum realpath magick; do
  command -v "$command_name" >/dev/null 2>&1 || { printf 'Missing build tool: %s\n' "$command_name" >&2; exit 1; }
done

mkdir -p "$build_root" "$work_root" "$out_root"
"$project_root/scripts/check.sh"

cmake -S "$project_root/installer" -B "$build_root/installer" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON
cmake --build "$build_root/installer"
ctest --test-dir "$build_root/installer" --output-on-failure

if [[ -e "$profile_root" ]]; then
  archive_root="$work_root/archive/$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "$archive_root"
  mv "$profile_root" "$archive_root/profile"
fi
mkdir -p "$profile_root"
cp -a "$project_root/archiso/." "$profile_root/"
install -d -m 0750 "$profile_root/airootfs/root"

DESTDIR="$profile_root/airootfs" cmake --install "$build_root/installer" --prefix /usr
install -Dm755 "$project_root/backend/aero7_install_backend.py" \
  "$profile_root/airootfs/usr/lib/aero7/aero7-install-backend"
install -Dm755 "$project_root/backend/aero7_shell_adapter.py" \
  "$profile_root/airootfs/usr/lib/aero7/aero7_shell_adapter.py"
install -Dm644 "$project_root/config/base-packages.txt" \
  "$profile_root/airootfs/usr/share/aero7/base-packages.txt"
install -Dm644 "$project_root/config/aero7-packages.txt" \
  "$profile_root/airootfs/usr/share/aero7/aero7-packages.txt"
plymouth_source="$project_root/third_party/PlymouthVista"
plymouth_target="$profile_root/airootfs/usr/share/plymouth/themes/PlymouthVista"
install -d -m 0755 "$plymouth_target/images"
install -m 0644 "$plymouth_source/LICENSE" "$plymouth_target/LICENSE"
install -m 0644 "$plymouth_source/PlymouthVista.plymouth" "$plymouth_target/PlymouthVista.plymouth"
install -m 0644 "$plymouth_source/PlymouthVista.script" "$plymouth_target/PlymouthVista.script"
while IFS= read -r -d '' plymouth_asset; do
  asset_name="${plymouth_asset##*/}"
  case "$asset_name" in
    aero7-logo-circle.png) continue ;;
  esac
  install -m 0644 "$plymouth_asset" "$plymouth_target/images/$asset_name"
done < <(find "$plymouth_source/images" -maxdepth 1 -type f -print0)
install -Dm644 "$plymouth_source/LICENSE" \
  "$profile_root/airootfs/usr/share/licenses/PlymouthVista/LICENSE"
install -Dm644 "$project_root/oobe/aero7-oobe.service" \
  "$profile_root/airootfs/usr/share/aero7/oobe/aero7-oobe.service"
install -Dm644 "$project_root/installer/assets/aero7-sddm-branding.png" \
  "$profile_root/airootfs/usr/share/aero7/branding/aero7-sddm-branding.png"
login_background="$profile_root/airootfs/usr/share/aero7/branding/aero7-login-background.jpg"
install -d -m 0755 "${login_background%/*}"
magick "$project_root/installer/assets/aero7-background.png" -strip -quality 92 "$login_background"
chmod 0644 "$login_background"
install -Dm644 "$project_root/sources.lock" \
  "$profile_root/airootfs/usr/share/aero7/sources.lock"
install -Dm644 "$source_path/keys/aero7-repository.asc" \
  "$profile_root/airootfs/usr/share/aero7/aero7-repository.asc"

# Ship the exact pinned Aero7-shell implementation used by the post-OOBE
# image-mode adapter. Only runtime files are copied; Git metadata, tests, and
# development output never enter the ISO.
shell_payload="$profile_root/airootfs/usr/share/aero7/source"
install -d -m 0755 "$shell_payload"
for source_item in assets commands config keys lib modules recipes stages ui; do
  cp -a "$source_path/$source_item" "$shell_payload/"
done
for source_file in install.sh uninstall.sh update.sh LICENSE THIRD_PARTY.md; do
  cp -a "$source_path/$source_file" "$shell_payload/"
done

service_file="$profile_root/airootfs/etc/systemd/system/aero7-installer.service"
if [[ "${AERO7_ENABLE_LIVE_INSTALL:-1}" == "1" ]]; then
  sed -i 's/@INSTALL_MODE@/--live-install/; s|@DESTRUCTIVE_ENV@|Environment=AERO7_ALLOW_DESTRUCTIVE=YES-I-AM-IN-A-DISPOSABLE-AERO7-VM|' "$service_file"
  printf 'Prepared LIVE-INSTALL profile. Use only with scripts/run-qemu.sh --fresh.\n'
else
  sed -i 's/@INSTALL_MODE@/--demo/; s/@DESTRUCTIVE_ENV@//' "$service_file"
  printf 'Prepared simulation-only profile.\n'
fi

install -d -m 0755 \
  "$profile_root/airootfs/etc/systemd/system/multi-user.target.wants" \
  "$profile_root/airootfs/etc/systemd/system/getty.target.wants"

# NetworkManager receives DHCP-provided DNS servers and sends them to
# systemd-resolved. Arch package assembly otherwise leaves a placeholder
# resolv.conf in the live root, causing pacstrap mirror lookups to fail.
ln -sfn /run/systemd/resolve/stub-resolv.conf \
  "$profile_root/airootfs/etc/resolv.conf"

ln -sfn ../aero7-installer.service \
  "$profile_root/airootfs/etc/systemd/system/multi-user.target.wants/aero7-installer.service"
ln -sfn /usr/lib/systemd/system/systemd-resolved.service \
  "$profile_root/airootfs/etc/systemd/system/multi-user.target.wants/systemd-resolved.service"
ln -sfn /usr/lib/systemd/system/NetworkManager.service \
  "$profile_root/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
ln -sfn /usr/lib/systemd/system/getty@.service \
  "$profile_root/airootfs/etc/systemd/system/getty.target.wants/getty@tty2.service"
ln -sfn ../pacman-init.service \
  "$profile_root/airootfs/etc/systemd/system/multi-user.target.wants/pacman-init.service"

if rg -n -i 'install windows|windows 7 professional|microsoft software license' \
    "$project_root/installer/qml" "$project_root/installer/assets" >/dev/null 2>&1; then
  printf 'Unexpected proprietary branding string found in shipped payload.\n' >&2
  exit 1
fi

printf 'Assembled profile: %s\n' "$profile_root"
if ((prepare_only)); then
  printf 'Prepare-only build complete; mkarchiso was not run.\n'
  exit 0
fi

printf 'Profile checks passed. Archiso requires a short root-only second phase. Run exactly:\n' >&2
printf '  sudo %q --mkarchiso-only\n' "$project_root/scripts/build-iso.sh" >&2
exit 2
