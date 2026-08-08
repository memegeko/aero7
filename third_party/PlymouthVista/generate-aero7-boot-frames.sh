#!/usr/bin/env bash

set -euo pipefail

theme_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd -- "$theme_root/../.." && pwd)"
images_dir="$theme_root/images"
logo_source="$project_root/installer/assets/aero7-logo-plain.png"

command -v ffmpeg >/dev/null 2>&1 || {
  printf 'ffmpeg is required to regenerate the Aero7 Plymouth frames.\n' >&2
  exit 1
}

[[ -s "$logo_source" ]] || {
  printf 'Missing Aero7 logo: %s\n' "$logo_source" >&2
  exit 1
}

for frame in $(seq 56 104); do
  if (( frame <= 61 )); then
    read -r intensity radius opacity size < <(
      awk -v frame="$frame" 'BEGIN {
        t = (frame - 56) / 5;
        opacity = (t <= 0.2) ? 0 : (t - 0.2) / 0.8;
        printf "%.4f %.4f %.4f %.2f\n", 1.0 - (0.35 * t), 24 - (6 * t), opacity, 80 + (28 * t)
      }'
    )
  elif (( frame <= 75 )); then
    read -r intensity radius opacity size < <(
      awk -v frame="$frame" 'BEGIN {
        t = (frame - 62) / 13;
        printf "%.4f %.4f 1.0000 %.2f\n", 0.60 - (0.36 * t), 18 + (12 * t), 113 - (5 * t)
      }'
    )
  else
    read -r intensity radius opacity size < <(
      awk -v frame="$frame" 'BEGIN {
        pi = atan2(0, -1);
        phase = 2 * pi * (frame - 76) / 28;
        pulse = (1 - cos(phase)) / 2;
        printf "%.4f 30.0000 1.0000 %.2f\n", 0.20 + (0.04 * pulse), 108 + (2 * pulse)
      }'
    )
  fi

  glow="nullsrc=s=200x200,geq="
  glow+="r='255*${intensity}*exp(-(pow(X-W/2,2)+pow(Y-H/2,2))/(2*pow(${radius},2)))':"
  glow+="g='255*${intensity}*exp(-(pow(X-W/2,2)+pow(Y-H/2,2))/(2*pow(${radius}*1.25,2)))':"
  glow+="b='255*${intensity}*exp(-(pow(X-W/2,2)+pow(Y-H/2,2))/(2*pow(${radius}*1.70,2)))'"

  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "$glow" \
    -i "$logo_source" \
    -filter_complex \
      "[1:v]scale=${size}:${size}:force_original_aspect_ratio=decrease:flags=lanczos,format=rgba,colorchannelmixer=aa=${opacity}[logo];[0:v][logo]overlay=(W-w)/2:(H-h)/2,format=rgba" \
    -frames:v 1 "$images_dir/flag${frame}.png"
done

install -m 0644 "$logo_source" "$images_dir/aero7-logo-plain.png"

printf 'Generated Aero7 Plymouth reveal frames 56-104.\n'
