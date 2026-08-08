#!/usr/bin/env bash
set -Eeuo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
binary="$project_root/build/installer/aero7-installer"
output_root="$project_root/work/render-smoke"
[[ -x "$binary" ]] || { printf 'Build the installer first.\n' >&2; exit 1; }
mkdir -p "$output_root"

installer_screens=(
  LanguageScreen WelcomeScreen StartingScreen LicenseScreen InstallTypeScreen
  DiskScreen ConfirmScreen ProgressScreen CompleteScreen
)
oobe_screens=(
  ApplyingSettingsScreen VideoPerformanceScreen AccountScreen PasswordScreen
  UpdatesScreen TimeScreen NetworkScreen FinalizingScreen OobeWelcomeScreen
  PreparingDesktopScreen DesktopScreen
)

for screen in "${installer_screens[@]}"; do
  env QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    "$binary" --demo --documentation-screenshot --screen "$screen" --size 1024x768 --screenshot "$output_root/$screen-1024x768.png"
done
env QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  "$binary" --demo --documentation-screenshot --screen DiskScreen --advanced-drive --size 1024x768 \
  --screenshot "$output_root/DiskScreen-advanced-1024x768.png"
for screen in "${oobe_screens[@]}"; do
  env QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    "$binary" --demo --documentation-screenshot --oobe --screen "$screen" --size 1024x768 --screenshot "$output_root/$screen-1024x768.png"
done

for size in 1366x768 1920x1080; do
  for screen in LanguageScreen ProgressScreen; do
    env QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
      "$binary" --demo --documentation-screenshot --screen "$screen" --size "$size" --screenshot "$output_root/$screen-$size.png"
  done
  env QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    "$binary" --demo --documentation-screenshot --oobe --screen AccountScreen --size "$size" --screenshot "$output_root/AccountScreen-$size.png"
  env QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    "$binary" --demo --documentation-screenshot --oobe --screen FinalizingScreen --size "$size" --screenshot "$output_root/FinalizingScreen-$size.png"
done

printf 'Rendered %d screen/resolution smoke captures in %s\n' \
  "$(( ${#installer_screens[@]} + ${#oobe_screens[@]} + 9 ))" "$output_root"
