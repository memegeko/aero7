#!/usr/bin/env bash
set -Eeuo pipefail

source_root="${1:-}"
expected_root="${AERO7_ARCHISO_SOURCE_ROOT:-}"

[[ -n "$source_root" && -n "$expected_root" ]] || {
  printf 'Aero7 SquashFS guard is missing its source root.\n' >&2
  exit 64
}

source_root="$(realpath -m -- "$source_root")"
expected_root="$(realpath -m -- "$expected_root")"
[[ "$source_root" == "$expected_root" ]] || {
  printf 'Aero7 SquashFS guard rejected unexpected source: %s\n' "$source_root" >&2
  exit 64
}

# Archiso normally removes its chroot bind mounts before this point. If a
# helper survives pacstrap, a failed unmount must never make SquashFS traverse
# the host's /proc, /sys, /dev, or /run trees. `findmnt -R <path>` only works
# when <path> is itself a mount point, so enumerate the mount table and filter
# it explicitly instead. Detach only mounts at or below this exact
# project-local temporary root, deepest first.
mapfile -t leaked_mounts < <(
  while IFS= read -r mount_target; do
    if [[ "$mount_target" == "$source_root" || "$mount_target" == "$source_root"/* ]]; then
      printf '%s %s\n' "${#mount_target}" "$mount_target"
    fi
  done < <(findmnt -rn -o TARGET)
  true
)
if ((${#leaked_mounts[@]})); then
  mapfile -t leaked_mounts < <(printf '%s\n' "${leaked_mounts[@]}" | sort -rn | cut -d' ' -f2-)
fi
for mount_target in "${leaked_mounts[@]}"; do
  umount "$mount_target" 2>/dev/null || umount -l "$mount_target"
done

remaining_mounts=()
while IFS= read -r mount_target; do
  if [[ "$mount_target" == "$source_root" || "$mount_target" == "$source_root"/* ]]; then
    remaining_mounts+=("$mount_target")
  fi
done < <(findmnt -rn -o TARGET)
if ((${#remaining_mounts[@]})); then
  printf 'Aero7 SquashFS guard: temporary mounts remain below %s\n' "$source_root" >&2
  printf '  %s\n' "${remaining_mounts[@]}" >&2
  exit 75
fi

exec /usr/bin/mksquashfs "$@"
