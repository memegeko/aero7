#!/usr/bin/env bash
set -Eeuo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
release_config="$project_root/config/public-release.conf"

[[ -s "$release_config" ]] || {
  printf 'Missing public-release configuration: %s\n' "$release_config" >&2
  exit 1
}

declare -A release_values=()
while IFS='=' read -r key value; do
  [[ -n "$key" && "$key" != \#* ]] || continue
  release_values["$key"]="$value"
done <"$release_config"

required_reviews=(
  plymouth_redistribution_rights
  logo_trademark_review
  repository_history_review
  private_vulnerability_reporting
  candidate_iso_rebuild
  fresh_vm_validation
)

blocked=0
for review in "${required_reviews[@]}"; do
  if [[ "${release_values[$review]:-pending}" != "cleared" ]]; then
    printf 'BLOCKED: %s is %s.\n' \
      "$review" "${release_values[$review]:-missing}" >&2
    blocked=1
  fi
done

if [[ "${release_values[public_release_status]:-blocked}" != "cleared" ]]; then
  printf 'BLOCKED: public_release_status is %s.\n' \
    "${release_values[public_release_status]:-missing}" >&2
  blocked=1
fi

if [[ -z "${release_values[approval_reference]:-}" ]]; then
  printf 'BLOCKED: approval_reference is empty.\n' >&2
  blocked=1
fi

if ((blocked)); then
  printf 'See docs/PUBLIC-RELEASE-CHECKLIST.md. No public release is approved.\n' >&2
  exit 1
fi

printf 'Public-release approval records are complete.\n'
