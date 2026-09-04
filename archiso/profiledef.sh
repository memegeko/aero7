#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="aero7-physical-log-test"
iso_label="AERO7LOG_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m%d)"
iso_publisher="Aero7 Open Project <https://github.com/aero7-open-project>"
iso_application="Aero7 Beta 2 Physical Logging Test x86_64 UEFI installation medium"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="aero7"
buildmodes=('iso')
bootmodes=('uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/usr/lib/aero7/aero7-install-backend"]="0:0:755"
  ["/usr/lib/aero7/aero7-kiosk-launch"]="0:0:755"
  ["/usr/lib/aero7/aero7-collect-logs"]="0:0:755"
  ["/usr/lib/aero7/aero7_shell_adapter.py"]="0:0:755"
  ["/usr/bin/aero7-installer"]="0:0:755"
  ["/usr/share/aero7/source/install.sh"]="0:0:755"
  ["/usr/share/aero7/source/uninstall.sh"]="0:0:755"
  ["/usr/share/aero7/source/update.sh"]="0:0:755"
  ["/usr/share/aero7/source/commands/aero7"]="0:0:755"
  ["/usr/share/aero7/source/commands/aero7-dir"]="0:0:755"
  ["/usr/share/aero7/source/commands/aero7-ipconfig"]="0:0:755"
  ["/usr/share/aero7/source/commands/aero7-systeminfo"]="0:0:755"
  ["/usr/share/aero7/source/commands/aero7-winver"]="0:0:755"
)
