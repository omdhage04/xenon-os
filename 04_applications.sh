#!/bin/bash
set -euo pipefail

# Load Config
source "$(dirname "$0")/env.sh"

check_root
log_info "=== STARTED: Xenon OS Applications Setup (Lightweight + Brave) ==="

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
# Enable i386 Architecture (Gaming / Proton)
# --------------------------------------------------
echo "Enabling i386 architecture..."
dpkg --add-architecture i386
apt-get update

# --------------------------------------------------
# Remove Heavy / Unwanted Browsers & Services
# --------------------------------------------------
echo "Removing unnecessary packages..."

apt-get purge -y \
    firefox \
    chromium \
    thunderbird \
    apport \
    whoopsie \
    popularity-contest || true

# --------------------------------------------------
# Install Brave Browser (Official Repo)
# --------------------------------------------------
echo "Installing Brave Browser..."

curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
  https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] \
https://brave-browser-apt-release.s3.brave.com/ stable main" \
  > /etc/apt/sources.list.d/brave-browser-release.list

apt-get update
apt-get install -y brave-browser

# --------------------------------------------------
# Lightweight Desktop Applications
# --------------------------------------------------
echo "Installing essential lightweight apps..."

apt-get install -y \
    vlc \
    gimp \
    libreoffice-writer \
    libreoffice-calc \
    git \
    curl \
    wget \
    vim \
    htop \
    p7zip-full \
    unrar \
    gparted

# --------------------------------------------------
# Gaming Stack (Minimal but Complete)
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
# Steam / AppArmor Fix
# --------------------------------------------------
echo "Applying Steam sysctl fix..."

cat > /etc/sysctl.d/99-steam-fix.conf <<SYSCTL
kernel.unprivileged_userns_clone=1
SYSCTL

# --------------------------------------------------
# Developer / Build Utilities (Minimal)
# --------------------------------------------------
apt-get install -y \
    build-essential \
    software-properties-common \
    apt-transport-https \
    gnupg2

# --------------------------------------------------
# Aggressive Cleanup (IMPORTANT for ISO size)
# --------------------------------------------------
echo "Cleaning system..."

apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /usr/share/doc/*
rm -rf /usr/share/man/*
rm -rf /var/cache/apt/*

echo "Lightweight applications setup completed successfully."

CHROOT_EOF

# --------------------------------------------------
# Unmount Chroot
# --------------------------------------------------
unmount_chroot

log_info "=== SUCCESS: Applications Installed (Lightweight) ==="
