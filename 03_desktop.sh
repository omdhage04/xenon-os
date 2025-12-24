#!/bin/bash
set -euo pipefail

# Load Config
source "$(dirname "$0")/env.sh"

check_root
log_info "=== STARTED: Xenon OS Desktop Setup (GNOME Minimal) ==="

# --------------------------------------------------
# Mount Chroot Environment
# --------------------------------------------------
mount_chroot

# --------------------------------------------------
# Enter Chroot
# --------------------------------------------------
chroot "$CHROOT_DIR" /bin/bash <<'CHROOT_EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# --------------------------------------------------
# Enable Universe (Required)
# --------------------------------------------------
apt-get update
apt-get install -y software-properties-common
add-apt-repository universe
apt-get update

# --------------------------------------------------
# Install GNOME (ULTRA MINIMAL – NO RECOMMENDS)
# --------------------------------------------------
echo "Installing minimal GNOME desktop..."

apt-get install -y --no-install-recommends \
    gnome-shell \
    gnome-session \
    gnome-control-center \
    gnome-terminal \
    nautilus \
    gdm3 \
    xdg-user-dirs \
    xdg-user-dirs-gtk \
    fonts-noto-color-emoji

# --------------------------------------------------
# Enable Display Manager
# --------------------------------------------------
systemctl enable gdm3
systemctl set-default graphical.target

# --------------------------------------------------
# Enable Wayland (Default)
# --------------------------------------------------
sed -i 's/#WaylandEnable=false/WaylandEnable=true/' /etc/gdm3/custom.conf

# --------------------------------------------------
# Branding (Optional)
# --------------------------------------------------
mkdir -p /usr/share/backgrounds/xenon
if [ -f /tmp/assets/branding/wallpaper.png ]; then
    cp /tmp/assets/branding/wallpaper.png \
       /usr/share/backgrounds/xenon/default.png
fi

# --------------------------------------------------
# Aggressive Cleanup (IMPORTANT)
# --------------------------------------------------
echo "Cleaning GNOME desktop..."

apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /usr/share/doc/*
rm -rf /usr/share/man/*
rm -rf /usr/share/help/*

echo "GNOME minimal desktop installation completed."

CHROOT_EOF

# --------------------------------------------------
# Unmount Chroot
# --------------------------------------------------
unmount_chroot

log_info "=== SUCCESS: GNOME Minimal Desktop Installed ==="
