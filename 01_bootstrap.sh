#!/bin/bash
set -euo pipefail

# Load Config
source "$(dirname "$0")/env.sh"

# Root check
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (sudo).${NC}"
  exit 1
fi

echo -e "${GREEN}=== STARTED: Xenon OS Bootstrap ===${NC}"

# --------------------------------------------------
# Install Host Build Dependencies
# --------------------------------------------------
echo "Installing host build tools..."

apt-get update

apt-get install -y \
    debootstrap \
    xorriso \
    squashfs-tools \
    mtools \
    isolinux \
    syslinux-utils \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-ia32-bin \
    rsync \
    arch-test \
    qemu-user-static

# --------------------------------------------------
# Clean Previous Build (SAFE)
# --------------------------------------------------
if [ -d "$WORK_DIR" ]; then
    echo "Cleaning old build directory..."
    rm -rf "$WORK_DIR"
fi

# --------------------------------------------------
# Prepare Directories
# --------------------------------------------------
mkdir -p "$CHROOT_DIR"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$LOG_DIR"

# --------------------------------------------------
# Bootstrap Ubuntu Base System
# --------------------------------------------------
echo -e "${GREEN}Downloading Ubuntu ${CODENAME} base system...${NC}"

DEBOOTSTRAP_CACHE="$WORK_DIR/debootstrap-cache"
mkdir -p "$DEBOOTSTRAP_CACHE"

debootstrap \
    --arch=amd64 \
    --variant=minbase \
    --components=main,restricted,universe,multiverse \
    --include=systemd,systemd-sysv,dbus,udev,kmod,locales,nano,wget,curl,ca-certificates,gnupg \
    --cache-dir="$DEBOOTSTRAP_CACHE" \
    "$CODENAME" \
    "$CHROOT_DIR" \
    http://archive.ubuntu.com/ubuntu/ \
    | tee "$LOG_DIR/bootstrap.log"

# --------------------------------------------------
# Verify Bootstrap
# --------------------------------------------------
if [ ! -x "$CHROOT_DIR/bin/bash" ]; then
    echo -e "${RED}Debootstrap failed! /bin/bash not found.${NC}"
    exit 1
fi

# --------------------------------------------------
# Prepare Chroot Environment
# --------------------------------------------------
echo "Preparing chroot filesystem..."

mkdir -p "$CHROOT_DIR"/{proc,sys,dev,run,tmp}
chmod 1777 "$CHROOT_DIR/tmp"

mkdir -p "$CHROOT_DIR/tmp/assets"

# Copy env.sh into chroot (for reference/debug)
cp "$SCRIPT_DIR/env.sh" "$CHROOT_DIR/tmp/env.sh"

# Copy assets if available
if [ -d "$ASSETS_DIR" ]; then
    rsync -a "$ASSETS_DIR/" "$CHROOT_DIR/tmp/assets/" || true
fi

echo -e "${GREEN}=== SUCCESS: Bootstrap Complete ===${NC}"
echo "Chroot created at: $CHROOT_DIR"
