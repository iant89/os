#!/usr/bin/env bash
# build_lab_vm_qemu.sh — create the firmware-lab VM with QEMU/KVM (no VirtualBox).
#
# Usage:
#   scripts/build_lab_vm_qemu.sh                      # downloads Ubuntu 22.04 cloud image
#   scripts/build_lab_vm_qemu.sh --image local.qcow2  # use an existing cloud image
#   scripts/build_lab_vm_qemu.sh --bundle DIR         # provision offline from a bundle
#   scripts/build_lab_vm_qemu.sh --run                # just start the existing VM
#
# Requirements on the host: qemu-system-x86_64, qemu-img, cloud-localds (cloud-image-utils).
# USB passthrough of the UART adapter (CP2102 example):
#   qemu-system-x86_64 ... -device qemu-xhci -device usb-host,vendorid=0x10c4,productid=0xea60
# (list yours with: lsusb)
set -euo pipefail

VM_DIR="${VM_DIR:-$HOME/firmware-lab-vm}"
IMAGE_URL="https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64.img"
IMAGE="$VM_DIR/base.img"
DISK="$VM_DIR/lab.qcow2"
SEED="$VM_DIR/seed.iso"
BUNDLE=""
RUN_ONLY=0
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2 ;;
    --bundle) BUNDLE="$(cd "$2" && pwd)"; shift 2 ;;
    --run) RUN_ONLY=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$VM_DIR"

if [ "$RUN_ONLY" -eq 0 ]; then
  command -v qemu-system-x86_64 >/dev/null || { echo "install qemu-system-x86" >&2; exit 1; }
  command -v cloud-localds >/dev/null || { echo "install cloud-image-utils" >&2; exit 1; }

  if [ ! -f "$IMAGE" ]; then
    echo "==> downloading cloud image"
    curl -fL --retry 3 -o "$IMAGE" "$IMAGE_URL"
  fi

  echo "==> building cloud-init seed (runs setup_firmware_lab.sh on first boot)"
  SETUP_ARGS="--prefix /opt/firmware-lab"
  PROVISION_SRC="$REPO_ROOT"
  MOUNT_LINE=""
  if [ -n "$BUNDLE" ]; then
    MOUNT_LINE="mount -t 9p -o trans=virtio,version=9p2000.L bundle /mnt/bundle || true"
  fi
  cat > "$VM_DIR/user-data" <<EOF
#cloud-config
hostname: firmware-lab
users:
  - name: analyst
    groups: [sudo, dialout]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
runcmd:
  - mkdir -p /mnt/repo /mnt/bundle
  - mount -t 9p -o trans=virtio,version=9p2000.L repo /mnt/repo || true
  - $MOUNT_LINE
  - if [ -d /mnt/bundle ]; then bash /mnt/bundle/setup_firmware_lab.sh --bundle /mnt/bundle $SETUP_ARGS; else bash /mnt/repo/scripts/setup_firmware_lab.sh $SETUP_ARGS; fi
  - echo DONE > /home/analyst/provisioned
EOF
  echo "instance-id: firmware-lab-1" > "$VM_DIR/meta-data"
  cloud-localds "$SEED" "$VM_DIR/user-data" "$VM_DIR/meta-data"

  [ -f "$DISK" ] || qemu-img create -f qcow2 -b "$IMAGE" -F qcow2 "$DISK" 32G
fi

echo "==> starting VM (8 GB RAM, 4 vCPU, KVM)"
echo "    repo at /mnt/repo (9p), bundle at /mnt/bundle when --bundle given"
BUNDLE_VIRTFS=()
if [ -n "$BUNDLE" ]; then
  BUNDLE_VIRTFS=(-virtfs "local,path=$BUNDLE,mount_tag=bundle,security_model=mapped-xattr,id=bundle")
fi
exec qemu-system-x86_64 \
  -enable-kvm -m 8192 -smp 4 \
  -drive "file=$DISK,if=virtio,format=qcow2" \
  -drive "file=$SEED,if=virtio,format=raw" \
  -virtfs "local,path=$REPO_ROOT,mount_tag=repo,security_model=mapped-xattr,id=repo" \
  "${BUNDLE_VIRTFS[@]}" \
  -netdev user,id=n0,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=n0 \
  -display none -serial mon:stdio
