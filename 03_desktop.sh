#!/bin/bash
set -euo pipefail

# Load Config
source "$(dirname "$0")/env.sh"

# Root check
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (sudo).${NC}"
  exit 1
fi

echo -e "${GREEN}=== STARTED: Xenon OS Desktop Setup (KDE Plasma) ===${NC}"

# --------------------------------------------------
# Sync Assets
# --------------------------------------------------
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
# ENABLE UNIVERSE + UPDATE (CRITICAL FIX)
# --------------------------------------------------
apt-get update
apt-get install -y software-properties-common
add-apt-repository universe
apt-get update

# --------------------------------------------------
# Install KDE Plasma Desktop
# --------------------------------------------------
echo "Installing KDE Plasma..."

apt-get install -y \
    kde-plasma-desktop \
    sddm \
    sddm-theme-breeze \
    xorg \
    dolphin \
    konsole \
    plasma-nm \
    plasma-pa \
    kde-spectacle \
    kdeconnect \
    bluedevil \
    powerdevil \
    systemsettings \
    fonts-noto-color-emoji

# --------------------------------------------------
# Enable Display Manager
# --------------------------------------------------
systemctl enable sddm
systemctl set-default graphical.target

# --------------------------------------------------
# Branding
# --------------------------------------------------
mkdir -p /usr/share/backgrounds/xenon
if [ -f /tmp/assets/branding/wallpaper.png ]; then
    cp /tmp/assets/branding/wallpaper.png \
       /usr/share/backgrounds/xenon/default.png
fi

# --------------------------------------------------
# Cleanup
# --------------------------------------------------
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "KDE Desktop installation completed successfully."

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

echo -e "${GREEN}=== SUCCESS: KDE Desktop Installed ===${NC}"
