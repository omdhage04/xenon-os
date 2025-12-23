#!/bin/bash
set -euo pipefail

# Load Config
source "$(dirname "$0")/env.sh"

# Root check
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (sudo).${NC}"
  exit 1
fi

echo -e "${GREEN}=== STARTED: Xenon OS Core Base Setup ===${NC}"

# --------------------------------------------------
# Sync Assets
# --------------------------------------------------
echo "Syncing assets..."
mkdir -p "$CHROOT_DIR/tmp/assets"
if [ -d "$ASSETS_DIR" ]; then
    cp -r "$ASSETS_DIR/"* "$CHROOT_DIR/tmp/assets/" 2>/dev/null || true
fi

# --------------------------------------------------
# Mount Chroot Environment
# --------------------------------------------------
mount --bind /dev "$CHROOT_DIR/dev"
mount --bind /dev/pts "$CHROOT_DIR/dev/pts"
mount --bind /proc "$CHROOT_DIR/proc"
mount --bind /sys "$CHROOT_DIR/sys"
mount --bind /run "$CHROOT_DIR/run"
cp -L /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf"

# --------------------------------------------------
# Enter Chroot
# --------------------------------------------------
chroot "$CHROOT_DIR" /bin/bash <<'CHROOT_EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# --------------------------------------------------
# APT Sources (Ubuntu 24.04 Noble)
# --------------------------------------------------
cat > /etc/apt/sources.list <<SOURCES
deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-security main restricted universe multiverse
SOURCES

apt-get update

# --------------------------------------------------
# Prevent Polkit Crash
# --------------------------------------------------
groupadd -r polkitd 2>/dev/null || true
useradd -r -g polkitd -s /usr/sbin/nologin polkitd 2>/dev/null || true

# --------------------------------------------------
# Install Kernel & Core System (FIXED)
# --------------------------------------------------
echo "Installing kernel and core system..."

apt-get install -y \
    linux-image-generic \
    linux-headers-generic \
    linux-firmware \
    systemd \
    systemd-sysv \
    systemd-resolved \
    casper \
    network-manager \
    netplan.io \
    sudo \
    locales \
    tzdata \
    dbus \
    udev \
    grub-pc-bin \
    grub-efi-amd64-bin \
    efibootmgr \
    plymouth \
    plymouth-themes

# --------------------------------------------------
# Initramfs (REQUIRED for Live ISO)
# --------------------------------------------------
sed -i 's/^COMPRESS=.*/COMPRESS=gzip/' /etc/initramfs-tools/initramfs.conf
update-initramfs -u -k all

# --------------------------------------------------
# Network Configuration (SAFE)
# --------------------------------------------------
if [ -f /tmp/assets/configs/01-netcfg.yaml ]; then
    cp /tmp/assets/configs/01-netcfg.yaml /etc/netplan/01-netcfg.yaml
else
    cat > /etc/netplan/01-netcfg.yaml <<NETPLAN
network:
  version: 2
  renderer: NetworkManager
NETPLAN
fi
chmod 600 /etc/netplan/01-netcfg.yaml

# --------------------------------------------------
# Locale & Time (FIXES WARNINGS)
# --------------------------------------------------
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
echo "UTC" > /etc/timezone

# --------------------------------------------------
# Hostname
# --------------------------------------------------
echo "Xenon" > /etc/hostname

cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
127.0.1.1   Xenon
::1         localhost ip6-localhost ip6-loopback
HOSTS

# --------------------------------------------------
# DNS (SAFE ENABLE)
# --------------------------------------------------
if systemctl list-unit-files | grep -q systemd-resolved.service; then
    systemctl enable systemd-resolved
fi

ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# --------------------------------------------------
# Security for Live ISO
# --------------------------------------------------
passwd -l root

# --------------------------------------------------
# Cleanup
# --------------------------------------------------
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "Core base installation completed successfully."

CHROOT_EOF

# --------------------------------------------------
# Cleanup Mounts
# --------------------------------------------------
umount -lf "$CHROOT_DIR/run" 2>/dev/null || true
umount -lf "$CHROOT_DIR/dev/pts" 2>/dev/null || true
umount -lf "$CHROOT_DIR/dev" 2>/dev/null || true
umount -lf "$CHROOT_DIR/proc" 2>/dev/null || true
umount -lf "$CHROOT_DIR/sys" 2>/dev/null || true
rm -f "$CHROOT_DIR/etc/resolv.conf"

echo -e "${GREEN}=== SUCCESS: Core Base Installed ===${NC}"
