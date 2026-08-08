#!/usr/bin/env bash

set -euo pipefail

# .sp extension = "script part"
# basically, we're breaking PlymouthXP into several parts
# for ease of development

script_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
script_parts_dir="$script_root/src"
output="$script_root/PlymouthVista.script"
files=(
  bootlegacy.sp
  boot7.sp
  bootmgr.sp
  plymouth_config.sp
  stringutils.sp
  wupdate.sp
  shutdown.sp
  vistaresume.sp
  main.sp
)

temporary_output="$(mktemp "$script_root/.PlymouthVista.script.XXXXXX")"
trap 'rm -f -- "$temporary_output"' EXIT

for source_part in "${files[@]}"; do
  cat -- "$script_parts_dir/$source_part"
done >"$temporary_output"

mv -- "$temporary_output" "$output"
trap - EXIT

printf 'Compiled %s\n' "$output"
