#!/usr/bin/env bash
set -Eeuo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fresh=0
installed_only=0
iso_path=""
display_backend="sdl"

usage() {
  printf 'Usage: %s [--fresh] [--installed] [--iso PATH] [--display sdl|gtk]\n' "${0##*/}"
}

while (($#)); do
  case "$1" in
    --fresh) fresh=1 ;;
    --installed) installed_only=1 ;;
    --iso) shift; (($#)) || { usage >&2; exit 2; }; iso_path="$1" ;;
    --display) shift; (($#)) || { usage >&2; exit 2; }; display_backend="$1" ;;
    --help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

case "$display_backend" in
  sdl) display_spec="sdl,gl=off" ;;
  gtk) display_spec="gtk,gl=off" ;;
  *)
    printf 'Unsupported QEMU display backend: %s (use sdl or gtk).\n' "$display_backend" >&2
    exit 2
    ;;
esac

if ((fresh && installed_only)); then
  printf '%s\n' '--fresh and --installed cannot be used together.' >&2
  exit 2
fi

for command_name in qemu-system-x86_64 qemu-img; do
  command -v "$command_name" >/dev/null 2>&1 || { printf 'Missing tool: %s\n' "$command_name" >&2; exit 1; }
done

if ((!installed_only)) && [[ -z "$iso_path" ]]; then
  release_name="$(sed -n 's/^iso_name="\([^"]*\)"/\1/p' "$project_root/archiso/profiledef.sh")"
  [[ -n "$release_name" ]] || {
    printf 'Could not determine the current ISO release name.\n' >&2
    exit 1
  }
  iso_path="$(find "$project_root/out" -maxdepth 1 -type f -name "$release_name-*.iso" -printf '%T@ %p\n' | sort -nr | awk 'NR==1 {$1=""; sub(/^ /, ""); print}')"
fi
if ((!installed_only)); then
  [[ -n "$iso_path" && -f "$iso_path" ]] || {
    printf 'No ISO for the current Aero7 release was found. Build it first.\n' >&2
    printf 'Older images in out/ are deliberately ignored; use --iso PATH to select one explicitly.\n' >&2
    exit 1
  }
fi

if ((fresh)); then
  printf '%s\n' 'Fresh mode resets the disposable VM disk and UEFI variables; it does not rebuild the ISO.'
fi

qemu_root="$project_root/work/qemu"
archive_root="$qemu_root/archive"
disk_path="$qemu_root/aero7-test.qcow2"
vars_path="$qemu_root/OVMF_VARS.4m.fd"
serial_path="$qemu_root/aero7-serial.log"
monitor_path="$qemu_root/aero7-monitor.sock"
qmp_path="$qemu_root/aero7-qmp.sock"
code_path="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
vars_template="/usr/share/edk2/x64/OVMF_VARS.4m.fd"
mkdir -p "$qemu_root" "$archive_root"
[[ -f "$code_path" && -f "$vars_template" ]] || { printf 'OVMF firmware is missing (install edk2-ovmf).\n' >&2; exit 1; }
rm -f -- "$monitor_path"
rm -f -- "$qmp_path"

if ((fresh)) && [[ -e "$disk_path" ]]; then
  mv "$disk_path" "$archive_root/aero7-test-$(date -u +%Y%m%dT%H%M%SZ).qcow2"
fi
if ((installed_only)) && [[ ! -f "$disk_path" ]]; then
  printf 'No installed Aero7 VM disk exists at %s\n' "$disk_path" >&2
  exit 1
fi
if ((fresh)) || [[ ! -f "$vars_path" ]]; then
  cp "$vars_template" "$vars_path"
fi
if [[ ! -f "$disk_path" ]]; then
  qemu-img create -f qcow2 "$disk_path" 40G
fi

accel="tcg"
[[ -r /dev/kvm && -w /dev/kvm ]] && accel="kvm"
cpu_model="max"
[[ "$accel" == "kvm" ]] && cpu_model="host"

if ((installed_only)); then
  printf 'ISO: not attached (installed-disk mode)\n'
else
  printf 'ISO: %s\n' "$iso_path"
fi
printf 'Disposable disk: %s\nAcceleration: %s\n' "$disk_path" "$accel"
printf 'Display frontend: %s\n' "$display_backend"
printf 'Debug serial log: %s\n' "$serial_path"
printf 'QEMU monitor: %s\n' "$monitor_path"
printf 'QMP input socket: %s\n' "$qmp_path"
# QXL is intentional. QEMU's legacy std VGA adapter loses wlroots damage
# updates, which leaves cursor trails and pieces of the previous page behind.
# virtio-vga is also unsuitable here because this Cage/wlroots combination
# cannot import its DMA-BUF for scan-out. QXL provides clean full repaints.
# Use SDL for the host window by default. QEMU 11's GTK/Cairo frontend can
# reject QXL scanlines with an "invalid value for stride" warning, leaving a
# black window that repaints only while the pointer moves. SDL presents the
# same QXL guest surface without that host-side repaint failure. Keep GTK as an
# explicit diagnostic option through --display gtk.
# Put the virtual disk first in the UEFI device boot order. A fresh empty disk
# falls through to the installer DVD, while the first reboot after installation
# selects the newly bootable disk even if the virtual DVD is still attached.
storage_args=(
  -drive "if=none,id=aero7disk,format=qcow2,file=$disk_path"
  -device "virtio-blk-pci,drive=aero7disk,bootindex=1"
)
if ((!installed_only)); then
  storage_args+=(
    -drive "if=none,id=aero7cd,media=cdrom,readonly=on,file=$iso_path"
    -device "ide-cd,drive=aero7cd,bootindex=2"
  )
fi

exec qemu-system-x86_64 \
  -name Aero7-Installer-Test \
  -machine "q35,accel=$accel" \
  -cpu "$cpu_model" \
  -m 4096 \
  -smp 4 \
  -vga qxl \
  -display "$display_spec" \
  -device qemu-xhci \
  -device usb-tablet \
  -drive "if=pflash,format=raw,readonly=on,file=$code_path" \
  -drive "if=pflash,format=raw,file=$vars_path" \
  "${storage_args[@]}" \
  -boot menu=on \
  -nic user,model=virtio-net-pci \
  -monitor "unix:$monitor_path,server=on,wait=off" \
  -qmp "unix:$qmp_path,server=on,wait=off" \
  -serial "file:$serial_path"
