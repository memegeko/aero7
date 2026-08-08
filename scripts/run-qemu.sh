#!/usr/bin/env bash
set -Eeuo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fresh=0
installed_only=0
iso_path=""
display_backend="spice"
dualboot_fixture=0

usage() {
  printf 'Usage: %s [--fresh] [--installed] [--dualboot-fixture] [--iso PATH] [--display spice|sdl|gtk]\n' "${0##*/}"
}

while (($#)); do
  case "$1" in
    --fresh) fresh=1 ;;
    --installed) installed_only=1 ;;
    --dualboot-fixture) dualboot_fixture=1 ;;
    --iso) shift; (($#)) || { usage >&2; exit 2; }; iso_path="$1" ;;
    --display) shift; (($#)) || { usage >&2; exit 2; }; display_backend="$1" ;;
    --help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

case "$display_backend" in
  spice) display_spec="none" ;;
  sdl)
    display_spec="sdl,gl=off"
    # QEMU's SDL frontend otherwise uses nearest-neighbour enlargement, which
    # makes the fixed 1024x768 installer framebuffer look blocky.
    export SDL_RENDER_SCALE_QUALITY=linear
    ;;
  gtk) display_spec="gtk,gl=off" ;;
  *)
    printf 'Unsupported QEMU display backend: %s (use spice, sdl, or gtk).\n' "$display_backend" >&2
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
if ((dualboot_fixture)); then
  command -v sfdisk >/dev/null 2>&1 || {
    printf 'Missing tool for --dualboot-fixture: sfdisk.\n' >&2
    exit 1
  }
fi
if [[ "$display_backend" == "spice" ]]; then
  command -v remote-viewer >/dev/null 2>&1 || {
    printf 'Missing SPICE client: remote-viewer (install virt-viewer).\n' >&2
    exit 1
  }
fi

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
if ((dualboot_fixture)); then
  disk_path="$qemu_root/aero7-dualboot.raw"
  disk_format="raw"
else
  disk_path="$qemu_root/aero7-test.qcow2"
  disk_format="qcow2"
fi
vars_path="$qemu_root/OVMF_VARS.4m.fd"
serial_path="$qemu_root/aero7-serial.log"
qemu_runtime_root="${XDG_RUNTIME_DIR:-/tmp}/aero7-qemu-$UID"
monitor_path="$qemu_runtime_root/monitor.sock"
qmp_path="$qemu_runtime_root/qmp.sock"
spice_path="$qemu_runtime_root/spice.sock"
code_path="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
vars_template="/usr/share/edk2/x64/OVMF_VARS.4m.fd"
mkdir -p "$qemu_root" "$qemu_runtime_root"
chmod 0700 "$qemu_runtime_root"
[[ -f "$code_path" && -f "$vars_template" ]] || { printf 'OVMF firmware is missing (install edk2-ovmf).\n' >&2; exit 1; }
rm -f -- "$monitor_path"
rm -f -- "$qmp_path"
rm -f -- "$spice_path"

if ((fresh)) && [[ -e "$disk_path" ]]; then
  # The test disk is explicitly disposable in fresh mode. Archiving every
  # previous 40 GiB image caused silent storage growth and eventual failures.
  rm -f -- "$disk_path"
fi
if ((installed_only)) && [[ ! -f "$disk_path" ]]; then
  printf 'No installed Aero7 VM disk exists at %s\n' "$disk_path" >&2
  exit 1
fi
if ((fresh)) || [[ ! -f "$vars_path" ]]; then
  cp "$vars_template" "$vars_path"
fi
if [[ ! -f "$disk_path" ]]; then
  if ((dualboot_fixture)); then
    truncate -s 40G "$disk_path"
    printf '%s\n' \
      'label: gpt' \
      'unit: sectors' \
      '' \
      'start=2048, size=1048576, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="Existing EFI"' \
      'start=1050624, size=16777216, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7, name="Windows"' \
      | sfdisk "$disk_path" >/dev/null
  else
    qemu-img create -f qcow2 "$disk_path" 40G
  fi
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
if ((dualboot_fixture)); then
  printf '%s\n' 'Disk fixture: existing GPT/EFI/Windows partitions plus unallocated space'
fi
printf 'Display frontend: %s\n' "$display_backend"
printf 'Debug serial log: %s\n' "$serial_path"
printf 'QEMU monitor: %s\n' "$monitor_path"
printf 'QMP input socket: %s\n' "$qmp_path"
# QXL is intentional. QEMU's legacy std VGA adapter loses wlroots damage
# updates, which leaves cursor trails and pieces of the previous page behind.
# virtio-vga is also unsuitable here because this Cage/wlroots combination
# cannot import its DMA-BUF for scan-out. QXL provides clean full repaints.
# Use a local SPICE Unix socket for the host window. QEMU 11's SDL frontend can
# lose physical mouse-button events, while its GTK/Cairo frontend can reject
# QXL scanlines and repaint only while the pointer moves. remote-viewer avoids
# both frontend bugs. SDL and GTK remain explicit diagnostic options.
# Put the virtual disk first in the UEFI device boot order. A fresh empty disk
# falls through to the installer DVD, while the first reboot after installation
# selects the newly bootable disk even if the virtual DVD is still attached.
storage_args=(
  -drive "if=none,id=aero7disk,format=$disk_format,file=$disk_path"
  -device "virtio-blk-pci,drive=aero7disk,bootindex=1"
)
if ((!installed_only)); then
  storage_args+=(
    -drive "if=none,id=aero7cd,media=cdrom,readonly=on,file=$iso_path"
    -device "ide-cd,drive=aero7cd,bootindex=2"
  )
fi

qemu_args=(
  qemu-system-x86_64
  -name Aero7-Installer-Test
  -machine "q35,accel=$accel,vmport=off"
  -cpu "$cpu_model"
  -m 4096
  -smp 4
  -vga qxl
  -display "$display_spec"
  -device "virtio-tablet-pci,id=aero7tablet"
  -drive "if=pflash,format=raw,readonly=on,file=$code_path"
  -drive "if=pflash,format=raw,file=$vars_path"
  "${storage_args[@]}"
  -boot menu=on
  -nic "user,model=virtio-net-pci"
  -monitor "unix:$monitor_path,server=on,wait=off"
  -qmp "unix:$qmp_path,server=on,wait=off"
  -serial "file:$serial_path"
)

if [[ "$display_backend" != "spice" ]]; then
  exec "${qemu_args[@]}"
fi

qemu_args+=(
  -spice "unix=on,addr=$spice_path,disable-ticketing=on,image-compression=off,streaming-video=off"
)
"${qemu_args[@]}" &
qemu_pid=$!

cleanup_spice() {
  trap - EXIT
  if kill -0 "$qemu_pid" >/dev/null 2>&1; then
    kill "$qemu_pid" >/dev/null 2>&1 || true
    wait "$qemu_pid" >/dev/null 2>&1 || true
  fi
  rm -f -- "$spice_path"
}
trap cleanup_spice EXIT

for ((attempt = 0; attempt < 100; attempt++)); do
  [[ -S "$spice_path" ]] && break
  if ! kill -0 "$qemu_pid" >/dev/null 2>&1; then
    set +e
    wait "$qemu_pid"
    qemu_status=$?
    set -e
    exit "$qemu_status"
  fi
  sleep 0.05
done
[[ -S "$spice_path" ]] || {
  printf 'QEMU did not create the SPICE socket: %s\n' "$spice_path" >&2
  exit 1
}

{
  printf '[virt-viewer]\n'
  printf 'type=spice\n'
  printf 'unix-path=%s\n' "$spice_path"
} | remote-viewer --auto-resize=never --cursor=auto --title 'Aero7 Installer Test' -
