#!/bin/bash
# =============================================================================
# XENON OS - OPTIMIZED BUILD SYSTEM
# =============================================================================
# This contains all optimized scripts with fixes and improvements
# Extract each section to its respective file

# =============================================================================
# FILE: scripts/env.sh
# =============================================================================
#!/bin/bash

# Automatic Path Detection (works with sudo)
SCRIPT_DIR_ABS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR_ABS")"

# Project Identity
export OS_NAME="Xenon"
export OS_VERSION="Alpha 1"
export CODENAME="noble"

# Directories
export WORK_DIR="$PROJECT_DIR/work"
export OUTPUT_DIR="$PROJECT_DIR/output"
export ASSETS_DIR="$PROJECT_DIR/assets"
export SCRIPT_DIR="$PROJECT_DIR/scripts"
export LOG_DIR="$PROJECT_DIR/logs"

# Chroot Environment
export CHROOT_DIR="$WORK_DIR/chroot"
export IMAGE_NAME="xenon-alpha1.iso"
export ISO_DIR="$WORK_DIR/iso"

# Build Optimization
export MAKEFLAGS="-j$(nproc)"
export DEBIAN_FRONTEND=noninteractive
export APT_OPTS="-y -qq --no-install-recommends"

# Colors
export GREEN='\033[0;32m'
export RED='\033[0;31m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'

# Utility Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%H:%M:%S') - $*" | tee -a "${LOG_DIR}/build.log"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') - $*" | tee -a "${LOG_DIR}/build.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') - $*" | tee -a "${LOG_DIR}/build.log"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $*" | tee -a "${LOG_DIR}/build.log"
}

# Mount/Unmount Functions
mount_chroot() {
    log_step "Mounting chroot environment..."
    mount --bind /dev "$CHROOT_DIR/dev" 2>/dev/null || true
    mount --bind /dev/pts "$CHROOT_DIR/dev/pts" 2>/dev/null || true
    mount --bind /proc "$CHROOT_DIR/proc" 2>/dev/null || true
    mount --bind /sys "$CHROOT_DIR/sys" 2>/dev/null || true
    mount --bind /run "$CHROOT_DIR/run" 2>/dev/null || true
    cp -L /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf"
}

unmount_chroot() {
    log_step "Unmounting chroot environment..."
    umount -lf "$CHROOT_DIR/run" 2>/dev/null || true
    umount -lf "$CHROOT_DIR/dev/pts" 2>/dev/null || true
    umount -lf "$CHROOT_DIR/dev" 2>/dev/null || true
    umount -lf "$CHROOT_DIR/proc" 2>/dev/null || true
    umount -lf "$CHROOT_DIR/sys" 2>/dev/null || true
    rm -f "$CHROOT_DIR/etc/resolv.conf"
}

# Cleanup on exit
cleanup_on_exit() {
    if [ $? -ne 0 ]; then
        log_error "Build failed! Cleaning up..."
        unmount_chroot
    fi
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root (sudo)"
        exit 1
    fi
}

# Create necessary directories
mkdir -p "$LOG_DIR" "$OUTPUT_DIR"

trap cleanup_on_exit EXIT

