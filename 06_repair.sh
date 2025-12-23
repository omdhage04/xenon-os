#!/bin/bash
set -euo pipefail

# Load Config
source "$(dirname "$0")/env.sh"

check_root

log_info "=== STARTED: Repairing Xenon OS (Live Fixes) ==="

# --------------------------------------------------
# Mount Chroot Environment
# --------------------------------------------------
log_step "Mounting chroot..."
mount --bind /dev "$CHROOT_DIR/dev"
mount --bind /dev/pts "$CHROOT_DIR/dev/pts"
mount --bind /proc "$CHROOT_DIR/proc"
mount --bind /sys "$CHROOT_DIR/sys"
mount --bind /run "$CHROOT_DIR/run"
cp -L /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf"

# --------------------------------------------------
# Enter Chroot
# --------------------------------------------------
log_step "Applying repair steps inside chroot..."
chroot "$CHROOT_DIR" /bin/bash <<'CHROOT_EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# --------------------------------------------------
# Restore Critical Directories
# --------------------------------------------------
echo "Restoring critical directories..."
mkdir -p /tmp /run /var/tmp /var/lock /var/run
chmod 1777 /tmp /var/tmp
ln -sf /run/lock /var/lock 2>/dev/null || true
ln -sf /run /var/run 2>/dev/null || true

# --------------------------------------------------
# Create Live User (ubuntu)
# --------------------------------------------------
echo "Ensuring live user exists..."
if ! id ubuntu &>/dev/null; then
    useradd -m -s /bin/bash -u 999 \
        -G sudo,adm,cdrom,dialout,plugdev,lpadmin,sambashare ubuntu
    echo "ubuntu:ubuntu" | chpasswd

    echo "ubuntu ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ubuntu
    chmod 0440 /etc/sudoers.d/ubuntu
fi

# Create standard directories
mkdir -p /home/ubuntu/{Desktop,Documents,Downloads,Music,Pictures,Videos}
chown -R ubuntu:ubuntu /home/ubuntu

# --------------------------------------------------
# Fix SDDM Permissions
# --------------------------------------------------
echo "Fixing SDDM permissions..."
mkdir -p /var/lib/sddm
chown -R sddm:sddm /var/lib/sddm 2>/dev/null || true

# --------------------------------------------------
# DNS (systemd-resolved)
# --------------------------------------------------
echo "Ensuring DNS is configured..."
systemctl enable systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# --------------------------------------------------
# Regenerate Initramfs (Safe)
# --------------------------------------------------
echo "Regenerating initramfs..."
update-initramfs -u -k all

# --------------------------------------------------
# Permissions Fixes
# --------------------------------------------------
chmod 4755 /usr/bin/sudo
chmod 4755 /usr/bin/pkexec 2>/dev/null || true

# --------------------------------------------------
# AppArmor (Safe Guard)
# --------------------------------------------------
if command -v apparmor_parser >/dev/null 2>&1; then
    echo "Reloading AppArmor profiles..."
    apparmor_parser -r /etc/apparmor.d/* || true
fi

# --------------------------------------------------
# Cleanup Temp Files (Keep Dirs)
# --------------------------------------------------
find /tmp -mindepth 1 -delete 2>/dev/null || true
find /var/tmp -mindepth 1 -delete 2>/dev/null || true

echo "Repair completed successfully."

CHROOT_EOF

# --------------------------------------------------
# Cleanup Mounts
# --------------------------------------------------
log_step "Unmounting chroot..."
umount -lf "$CHROOT_DIR/run" 2>/dev/null || true
umount -lf "$CHROOT_DIR/dev/pts" 2>/dev/null || true
umount -lf "$CHROOT_DIR/dev" 2>/dev/null || true
umount -lf "$CHROOT_DIR/proc" 2>/dev/null || true
umount -lf "$CHROOT_DIR/sys" 2>/dev/null || true
rm -f "$CHROOT_DIR/etc/resolv.conf"

log_info "=== SUCCESS: Repair Completed ==="
