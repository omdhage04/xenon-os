#!/bin/bash
set -euo pipefail

# Load Config
source "$(dirname "$0")/env.sh"

# Root check
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (sudo).${NC}"
  exit 1
fi

echo -e "${GREEN}=== STARTED: Xenon OS Applications & Gaming Setup ===${NC}"

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
# Enable 32-bit Architecture (Steam / Wine)
# --------------------------------------------------
echo "Enabling i386 architecture..."
dpkg --add-architecture i386
apt-get update

# --------------------------------------------------
# Gaming Stack (Ubuntu 24.04 safe)
# --------------------------------------------------
echo "Installing gaming stack..."

apt-get install -y \
    steam-installer \
    lutris \
    gamemode \
    lib32gcc-s1 \
    mesa-vulkan-drivers \
    mesa-vulkan-drivers:i386 \
    libgl1-mesa-dri:i386 \
    libgl1:i386 \
    libglx-mesa0:i386 \
    vulkan-tools \
    mesa-utils

# --------------------------------------------------
# Desktop & Daily Applications
# --------------------------------------------------
echo "Installing desktop applications..."

apt-get install -y \
    firefox \
    chromium \
    vlc \
    gimp \
    libreoffice \
    transmission-gtk \
    curl \
    wget \
    git \
    htop \
    neofetch \
    vim \
    p7zip-full \
    unrar \
    gparted

# --------------------------------------------------
# Virtual Machine Guest Tools (Safe)
# --------------------------------------------------
echo "Installing VM guest tools..."

apt-get install -y \
    spice-vdagent \
    qemu-guest-agent \
    open-vm-tools \
    open-vm-tools-desktop || true

apt-get install -y \
    virtualbox-guest-utils \
    virtualbox-guest-x11 2>/dev/null || true

# --------------------------------------------------
# Steam Security / AppArmor Fix
# --------------------------------------------------
echo "Applying Steam sysctl fix..."

if [ -f /tmp/assets/configs/sysctl-steam.conf ]; then
    cp /tmp/assets/configs/sysctl-steam.conf /etc/sysctl.d/99-steam-fix.conf
else
    cat > /etc/sysctl.d/99-steam-fix.conf <<SYSCTL
kernel.unprivileged_userns_clone=1
SYSCTL
fi

# --------------------------------------------------
# Extra Build & System Utilities
# --------------------------------------------------
apt-get install -y \
    build-essential \
    software-properties-common \
    apt-transport-https \
    gnupg2

# --------------------------------------------------
# Cleanup (Reduce ISO size)
# --------------------------------------------------
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "Applications and gaming stack installed successfully."

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

echo -e "${GREEN}=== SUCCESS: Applications Installed ===${NC}"
