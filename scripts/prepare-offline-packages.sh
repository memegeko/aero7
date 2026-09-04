#!/usr/bin/env bash
set -Eeuo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
((EUID == 0)) || {
  printf 'Run this package-download phase with sudo.\n' >&2
  exit 2
}

for command_name in bsdtar pacman repo-add sha256sum; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Missing offline-bundle tool: %s\n' "$command_name" >&2
    exit 1
  }
done

bundle_root="$project_root/offline-packages"
base_cache="$bundle_root/base"
aero_cache="$bundle_root/aero7"
staging="$project_root/work/offline-pacman"
download_root="$(mktemp -d /var/tmp/aero7-offline-packages.XXXXXX)"
base_download_cache="$download_root/base"
aero_download_cache="$download_root/aero7"
chmod 0755 "$download_root"
for clean_root in "$base_cache" "$aero_cache" "$staging"; do
  mkdir -p "$clean_root"
  find "$clean_root" -mindepth 1 -delete
done
find "$bundle_root" -maxdepth 1 -name 'aero7-offline.*' -delete
# Current pacman downloads as its unprivileged SandboxUser. Give that account
# only two disposable caches under /var/tmp: the developer's home directory is
# intentionally not traversable by that system account.
mkdir -p "$base_download_cache" "$aero_download_cache"
pacman_sandbox_user="$(pacman-conf DownloadUser 2>/dev/null || true)"
[[ -n "$pacman_sandbox_user" ]] || pacman_sandbox_user="alpm"
if id "$pacman_sandbox_user" >/dev/null 2>&1; then
  chown "$pacman_sandbox_user:$pacman_sandbox_user" \
    "$base_download_cache" "$aero_download_cache"
  chmod 0755 "$base_download_cache" "$aero_download_cache"
fi

mapfile -t base_packages < <(
  sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d' "$project_root/config/base-packages.txt"
)
mapfile -t aero_packages < <(
  sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d' "$project_root/config/aero7-packages.txt"
)
((${#base_packages[@]} && ${#aero_packages[@]})) || {
  printf 'The base or Aero7 package list is empty.\n' >&2
  exit 1
}

# Refresh signed repository databases once at build time. The resulting ISO
# never runs this command in offline mode.
pacman -Sy --noconfirm

download_bundle() {
  local name="$1"
  local cache="$2"
  shift 2
  local db="$staging/$name-db"
  mkdir -p "$db"
  cp -a /var/lib/pacman/sync "$db/"
  pacman \
    --config /etc/pacman.conf \
    --dbpath "$db" \
    --cachedir "$cache" \
    --gpgdir /etc/pacman.d/gnupg \
    --logfile "$staging/$name-pacman.log" \
    -Sw --noconfirm --ask=4 -- "$@"
  find "$cache" -maxdepth 1 -type f -name '*.part' -print -quit \
    | grep -q . && {
      printf 'An incomplete download remains in %s.\n' "$cache" >&2
      exit 1
    }
  find "$cache" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -print -quit \
    | grep -q . || {
      printf 'No packages were downloaded into %s.\n' "$cache" >&2
      exit 1
    }
}

download_bundle base "$base_download_cache" "${base_packages[@]}"
download_bundle aero7 "$aero_download_cache" "${aero_packages[@]}"

while IFS= read -r -d '' package_file; do
  install -m 0644 "$package_file" "$base_cache/${package_file##*/}"
done < <(find "$base_download_cache" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -print0)
declare -A base_package_names=()
while IFS= read -r -d '' package_file; do
  package_name="$(bsdtar -xOf "$package_file" .PKGINFO | sed -n 's/^pkgname = //p')"
  [[ -n "$package_name" ]] || {
    printf 'Could not read a package name from %s.\n' "$package_file" >&2
    exit 1
  }
  base_package_names["$package_name"]=1
done < <(find "$base_download_cache" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -print0)
while IFS= read -r -d '' package_file; do
  package_name="$(bsdtar -xOf "$package_file" .PKGINFO | sed -n 's/^pkgname = //p')"
  [[ -n "$package_name" ]] || {
    printf 'Could not read a package name from %s.\n' "$package_file" >&2
    exit 1
  }
  # The base transaction is installed first. Keep only packages that are not
  # already present there, avoiding hundreds of duplicate archives in the ISO.
  if [[ ! -v "base_package_names[$package_name]" ]]; then
    install -m 0644 "$package_file" "$aero_cache/${package_file##*/}"
  fi
done < <(find "$aero_download_cache" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -print0)
find "$download_root" -depth -delete

repo-add -q "$bundle_root/aero7-offline.db.tar.gz" \
  "$aero_cache"/*.pkg.tar.*

(
  cd "$project_root"
  find offline-packages/base -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -print0 \
    | sort -z | xargs -0 sha256sum > config/offline-base-packages.sha256
  find offline-packages/aero7 -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -print0 \
    | sort -z | xargs -0 sha256sum > config/offline-aero7-packages.sha256
  sha256sum offline-packages/aero7-offline.db.tar.gz \
    > config/offline-aero7-repo.sha256
)

output_uid="${SUDO_UID:-}"
if [[ "$output_uid" =~ ^[0-9]+$ ]]; then
  output_gid="$(id -g "$output_uid")"
  chown -R "$output_uid:$output_gid" "$bundle_root"
  chown "$output_uid:$output_gid" \
    "$project_root/config/offline-base-packages.sha256" \
    "$project_root/config/offline-aero7-packages.sha256" \
    "$project_root/config/offline-aero7-repo.sha256"
fi

printf 'Offline base bundle: %s packages, %s\n' \
  "$(find "$base_cache" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' | wc -l)" \
  "$(du -sh "$base_cache" | cut -f1)"
printf 'Offline Aero7 bundle: %s packages, %s\n' \
  "$(find "$aero_cache" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' | wc -l)" \
  "$(du -sh "$aero_cache" | cut -f1)"
printf 'Offline Aero7 repository database: %s\n' \
  "$bundle_root/aero7-offline.db.tar.gz"
