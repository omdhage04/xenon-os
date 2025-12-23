#!/bin/bash
set -euo pipefail

# Load Config
source "$(dirname "$0")/env.sh"

# Root check
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (sudo).${NC}"
  exit 1
fi

echo -e "${GREEN}=== STARTED: Building Xenon OS ISO ===${NC}"

# --------------------------------------------------
# Ensure chroot is cleanly unmounted
# --------------------------------------------------
umount -lf "$CHROOT_DIR/run" 2>/dev/null || true
umount -lf "$CHROOT_DIR/dev/pts" 2>/dev/null || true
umount -lf "$CHROOT_DIR/dev" 2>/dev/null || true
umount -lf "$CHROOT_DIR/proc" 2>/dev/null || true
umount -lf "$CHROOT_DIR/sys" 2>/dev/null || true

# --------------------------------------------------
# Prepare ISO directory structure
# --------------------------------------------------
ISO_DIR="$WORK_DIR/iso"
rm -rf "$ISO_DIR"
mkdir -p "$ISO_DIR"/{casper,boot/grub,EFI/BOOT,.disk}

# --------------------------------------------------
# Copy Kernel & Initrd
# --------------------------------------------------
echo "Locating kernel and initrd..."

VMLINUX=$(find "$CHROOT_DIR/boot" -name "vmlinuz-*" | sort -V | tail -n1)
INITRD=$(find "$CHROOT_DIR/boot" -name "initrd.img-*" | sort -V | tail -n1)

if [[ -z "$VMLINUX" || -z "$INITRD" ]]; then
    echo -e "${RED}Kernel or initrd not found in chroot!${NC}"
    exit 1
fi

cp "$VMLINUX" "$ISO_DIR/casper/vmlinuz"
cp "$INITRD" "$ISO_DIR/casper/initrd"

# --------------------------------------------------
# GRUB Configuration (CREATE FIRST)
# --------------------------------------------------
cat > "$ISO_DIR/boot/grub/grub.cfg" <<'GRUB_EOF'
set default=0
set timeout=10
set gfxpayload=keep

menuentry "Start Xenon OS (Live Session)" {
    linux  /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}

menuentry "Start Xenon OS (Safe Graphics)" {
    linux  /casper/vmlinuz boot=casper nomodeset quiet splash ---
    initrd /casper/initrd
}

menuentry "Start Xenon OS (Debug Mode)" {
    linux  /casper/vmlinuz boot=casper debug ---
    initrd /casper/initrd
}
GRUB_EOF

# --------------------------------------------------
# EFI Bootloader
# --------------------------------------------------
echo "Setting up EFI bootloader..."

if [ -f "$CHROOT_DIR/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed" ]; then
    cp "$CHROOT_DIR/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed" \
       "$ISO_DIR/EFI/BOOT/bootx64.efi"
else
    grub-mkstandalone \
        --format=x86_64-efi \
        --output="$ISO_DIR/EFI/BOOT/bootx64.efi" \
        --locales="" \
        --fonts="" \
        "boot/grub/grub.cfg=$ISO_DIR/boot/grub/grub.cfg"
fi

# --------------------------------------------------
# Package Manifest
# --------------------------------------------------
echo "Creating filesystem manifest..."
chroot "$CHROOT_DIR" dpkg-query -W --showformat='${Package} ${Version}\n' \
    > "$ISO_DIR/casper/filesystem.manifest"

cp "$ISO_DIR/casper/filesystem.manifest" \
   "$ISO_DIR/casper/filesystem.manifest-desktop"

# --------------------------------------------------
# Filesystem Size
# --------------------------------------------------
du -sx --block-size=1 "$CHROOT_DIR" | cut -f1 \
    > "$ISO_DIR/casper/filesystem.size"

# --------------------------------------------------
# Compress Root Filesystem
# --------------------------------------------------
echo "Creating SquashFS (this may take time)..."

mksquashfs "$CHROOT_DIR" "$ISO_DIR/casper/filesystem.squashfs" \
    -noappend \
    -comp zstd \
    -b 1M \
    -e boot

# --------------------------------------------------
# Disk Metadata
# --------------------------------------------------
cat > "$ISO_DIR/.disk/info" <<INFO
Xenon OS Alpha 1 (Ubuntu 24.04 Noble) amd64
INFO

echo "full" > "$ISO_DIR/.disk/cd_type"

# --------------------------------------------------
# Checksums
# --------------------------------------------------
(
    cd "$ISO_DIR"
    find . -type f -print0 | xargs -0 md5sum > md5sum.txt
)

# --------------------------------------------------
# Build ISO
# --------------------------------------------------
mkdir -p "$OUTPUT_DIR"

grub-mkrescue \
    -o "$OUTPUT_DIR/$IMAGE_NAME" \
    "$ISO_DIR" \
    -- \
    -volid "XENON_ALPHA1"

# --------------------------------------------------
# Final Output
# --------------------------------------------------
if [ ! -f "$OUTPUT_DIR/$IMAGE_NAME" ]; then
    echo -e "${RED}ISO build failed!${NC}"
    exit 1
fi

ISO_SIZE=$(du -h "$OUTPUT_DIR/$IMAGE_NAME" | cut -f1)
ISO_MD5=$(md5sum "$OUTPUT_DIR/$IMAGE_NAME" | cut -d' ' -f1)

echo "$ISO_MD5  $IMAGE_NAME" > "$OUTPUT_DIR/$IMAGE_NAME.md5"

echo -e "${GREEN}=== SUCCESS: ISO BUILD COMPLETE ===${NC}"
echo "ISO: $OUTPUT_DIR/$IMAGE_NAME"
echo "Size: $ISO_SIZE"
echo "MD5 : $ISO_MD5"
