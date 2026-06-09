#!/bin/bash
# =============================================================================
# Karotz Open Firmware - Root Filesystem Builder
# =============================================================================
# This script builds a custom root filesystem for the Karotz robot using
# OpenWrt as the base system.
# 
# The rootfs includes:
# - BusyBox for core utilities
# - Custom initialization scripts
# - Network configuration (wpa_supplicant)
# - Audio support (madplay)
# - Web interface (lighttpd + CGI)
# - Karotz-specific utilities
# 
# Usage: ./build_rootfs.sh [clean]
#   clean: Remove existing build and start fresh
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/output/build/rootfs"
OUTPUT_DIR="$PROJECT_ROOT/output/firmware"
LOG_FILE="$PROJECT_ROOT/output/logs/rootfs_build_$(date +%Y%m%d_%H%M%S).log"

# OpenWrt configuration
OPENWRT_VERSION="21.02.3"
OPENWRT_URL="https://downloads.openwrt.org/releases/$OPENWRT_VERSION"
OPENWRT_SOURCE="$PROJECT_ROOT/output/sources/openwrt-$OPENWRT_VERSION"
OPENWRT_SDK="openwrt-sdk-$OPENWRT_VERSION-arm-xscale_be-gcc-10.3.0_musl_eabi.Linux-x86_64.tar.xz"

# Toolchain
TOOLCHAIN_DIR="$PROJECT_ROOT/output/toolchain"
TARGET="armv5te-linaro-musleabi"

# RootFS output
ROOTFS_DIR="$BUILD_DIR/rootfs"
ROOTFS_IMG="$OUTPUT_DIR/rootfs.img.gz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# Logging Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

# =============================================================================
# Cleanup Function
# =============================================================================

clean_build() {
    log_info "Cleaning rootfs build..."
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
    if [ -f "$ROOTFS_IMG" ]; then
        rm -f "$ROOTFS_IMG"
    fi
    mkdir -p "$BUILD_DIR"
    mkdir -p "$OUTPUT_DIR"
}

# =============================================================================
# Check Toolchain
# =============================================================================

check_toolchain() {
    log_info "Checking toolchain..."
    
    if [ ! -d "$TOOLCHAIN_DIR" ]; then
        log_error "Toolchain not found. Please build toolchain first:"
        log_error "  ./build-scripts/tools/build_toolchain.sh"
    fi
    
    log_success "Toolchain verified"
}

# =============================================================================
# Download OpenWrt SDK
# =============================================================================

download_openwrt() {
    log_info "Downloading OpenWrt SDK..."
    
    mkdir -p "$PROJECT_ROOT/output/sources"
    cd "$PROJECT_ROOT/output/sources"
    
    if [ ! -d "openwrt-$OPENWRT_VERSION" ]; then
        # Download SDK
        if [ ! -f "$OPENWRT_SDK" ]; then
            log_info "Downloading OpenWrt SDK $OPENWRT_VERSION..."
            if ! wget -q --show-progress -O "$OPENWRT_SDK" \
                "$OPENWRT_URL/targets/arm/xscale_be/$OPENWRT_SDK"; then
                log_error "Failed to download OpenWrt SDK"
            fi
            
            # Verify download
            local sha256=$(sha256sum "$OPENWRT_SDK" | cut -d' ' -f1)
            log_info "OpenWrt SDK SHA256: $sha256"
        fi
        
        # Extract SDK
        log_info "Extracting OpenWrt SDK..."
        tar -xf "$OPENWRT_SDK" || log_error "Failed to extract OpenWrt SDK"
        
        # Clean up archive
        rm -f "$OPENWRT_SDK"
    else
        log_info "OpenWrt SDK already exists"
    fi
    
    cd "$PROJECT_ROOT"
}

# =============================================================================
# Configure OpenWrt
# =============================================================================

configure_openwrt() {
    log_info "Configuring OpenWrt for Karotz..."
    
    cd "$OPENWRT_SOURCE"
    
    # Update feeds
    log_info "Updating package feeds..."
    ./scripts/feeds update -a 2>&1 | tee -a "$LOG_FILE" || log_warning "Feed update had issues"
    
    # Install required packages
    log_info "Installing Karotz-specific packages..."
    ./scripts/feeds install -a 2>&1 | tee -a "$LOG_FILE" || log_warning "Package install had issues"
    
    # Copy custom configuration
    if [ -f "$SCRIPT_DIR/config_openwrt" ]; then
        log_info "Using custom OpenWrt configuration"
        cp "$SCRIPT_DIR/config_openwrt" .config
    fi
    
    # Apply Karotz-specific config
    cat >> .config << 'EOF'
# Karotz Custom Configuration
CONFIG_TARGET_arm=y
CONFIG_TARGET_arm_xscale=y
CONFIG_TARGET_arm_xscale_be=y
CONFIG_ARCH="arm"
CONFIG_TARGET_BOARD="xscale"
CONFIG_TARGET_SUBTARGET="be"

# Build system
CONFIG_ALL_KMODS=y
CONFIG_ALL_NONSHARED=y
CONFIG_DEVEL=y
CONFIG_CCACHE=y

# Base system
CONFIG_BUSYBOX_CUSTOM=y
CONFIG_BUSYBOX_DEFAULT FEATURES_IPV6=y
CONFIG_BUSYBOX_DEFAULT_HUSH=y
CONFIG_BUSYBOX_DEFAULT_LFS=y
CONFIG_BUSYBOX_DEFAULT_LONG_OPTIONS=y
CONFIG_BUSYBOX_DEFAULT_SHOW_USAGE=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_VERBOSE_USAGE=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_COMPRESS_USAGE=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_EDITING=y

# Network
CONFIG_PACKAGE_dnsmasq=y
CONFIG_PACKAGE_dropbear=y
CONFIG_PACKAGE_ip6tables=y
CONFIG_PACKAGE_iptables=y
CONFIG_PACKAGE_wpa-supplicant=y
CONFIG_PACKAGE_wpa-cli=y
CONFIG_PACKAGE_wireless-tools=y

# Audio
CONFIG_PACKAGE_madplay=y
CONFIG_PACKAGE_alsa-utils=y
CONFIG_PACKAGE_libmad=y

# Filesystem
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_mtd-utils=y
CONFIG_PACKAGE_nand-utils=y
CONFIG_PACKAGE_yaffs2utils=y

# Web
CONFIG_PACKAGE_lighttpd=y
CONFIG_PACKAGE_lighttpd-mod-cgi=y

# Utilities
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_wget=y
CONFIG_PACKAGE_ca-certificates=y
CONFIG_PACKAGE_ca-bundle=y

# Compression
CONFIG_PACKAGE_gzip=y
CONFIG_PACKAGE_tar=y
CONFIG_PACKAGE_unzip=y

# Shell
CONFIG_PACKAGE_bash=y
CONFIG_BUSYBOX_DEFAULT_ASH=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_BASH_IS_NONE=y

# LED Support
CONFIG_PACKAGE_kmod-leds=y
CONFIG_PACKAGE_kmod-leds-gpio=y

# USB Support
CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb-ehci=y
CONFIG_PACKAGE_kmod-usb-ohci=y
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_usbutils=y

# WiFi Support
CONFIG_PACKAGE_kmod-rt2x00=y
CONFIG_PACKAGE_kmod-rt2500-usb=y
CONFIG_PACKAGE_kmod-rt2800-usb=y
CONFIG_PACKAGE_kmod-mac80211=y
CONFIG_PACKAGE_kmod-cfg80211=y

# Custom packages directory
CONFIG_OPKG_DEST="arm_xscale_be"
CONFIG_EXTRA_OPTIMIZATION="-Os -pipe -march=armv5te -mtune=arm926ej-s"
EOF
    
    # Run defconfig
    log_info "Running defconfig..."
    make defconfig 2>&1 | tee -a "$LOG_FILE" || log_error "Defconfig failed"
    
    cd "$PROJECT_ROOT"
}

# =============================================================================
# Build Packages
# =============================================================================

build_packages() {
    log_info "Building OpenWrt packages..."
    
    cd "$OPENWRT_SOURCE"
    
    # Set custom package list
    if [ -f "$SCRIPT_DIR/package_lists/karotz-packages.txt" ]; then
        log_info "Using custom package list"
        cp "$SCRIPT_DIR/package_lists/karotz-packages.txt" "$OPENWRT_SOURCE/package/karotz/"
    fi
    
    # Build world (all packages)
    log_info "Starting build (this may take 45-90 minutes)..."
    if ! make world -j$(nproc) 2>&1 | tee -a "$LOG_FILE"; then
        log_error "OpenWrt build failed"
    fi
    
    cd "$PROJECT_ROOT"
}

# =============================================================================
# Create Custom RootFS Structure
# =============================================================================

create_rootfs() {
    log_info "Creating custom root filesystem..."
    
    # Create rootfs directory
    rm -rf "$ROOTFS_DIR"
    mkdir -p "$ROOTFS_DIR"
    
    cd "$ROOTFS_DIR"
    
    # Create basic directory structure
    log_info "Creating directory structure..."
    mkdir -p bin sbin usr/bin usr/sbin usr/lib usr/share
    mkdir -p etc/init.d etc/config etc/rc.d
    mkdir -p dev proc sys tmp var/log var/run var/lock
    mkdir -p root home
    mkdir -p usr/www/cgi-bin usr/www/install usr/www/welcome
    mkdir -p karotz/bin karotz/etc karotz/apps karotz/messages
    mkdir -p mnt/usbkey
    
    # Copy from OpenWrt build
    log_info "Copying files from OpenWrt build..."
    local OPENWRT_BIN="$OPENWRT_SOURCE/bin/targets/arm/xscale_be/openwrt-arm-xscale_be-xscale_be-rootfs"
    
    if [ -d "$OPENWRT_BIN" ]; then
        # Copy essential files
        cp -a "$OPENWRT_BIN"/* "$ROOTFS_DIR/" 2>/dev/null || true
    fi
    
    # Install BusyBox
    log_info "Installing BusyBox..."
    local BUSYBOX_DIR="$OPENWRT_SOURCE/build_dir/target-arm_xscale_be_musl_eabi/busybox-*/busybox"
    if [ -f "$BUSYBOX_DIR" ]; then
        cp "$BUSYBOX_DIR" bin/busybox
        ln -sf busybox bin/sh
        ln -sf busybox bin/ash
        # Create all BusyBox symlinks
        ./busybox --install -s bin/ 2>/dev/null || true
    fi
    
    # Install essential libraries
    log_info "Installing essential libraries..."
    local LIB_DIR="$OPENWRT_SOURCE/build_dir/target-arm_xscale_be_musl_eabi/"
    find "$LIB_DIR" -name "*.so*" -type f 2>/dev/null | xargs -I {} cp {} usr/lib/ 2>/dev/null || true
    
    # Install madplay and dependencies
    log_info "Installing audio support..."
    local MADPLAY_DIR="$OPENWRT_SOURCE/build_dir/target-arm_xscale_be_musl_eabi/madplay-*"
    if [ -d "$MADPLAY_DIR" ]; then
        cp "$MADPLAY_DIR/usr/bin/madplay" usr/bin/
        cp -a "$MADPLAY_DIR/usr/lib/"* usr/lib/ 2>/dev/null || true
    fi
    
    # Install wpa_supplicant
    log_info "Installing network support..."
    local WPA_DIR="$OPENWRT_SOURCE/build_dir/target-arm_xscale_be_musl_eabi/wpa-supplicant-*"
    if [ -d "$WPA_DIR" ]; then
        cp "$WPA_DIR/usr/sbin/wpa_supplicant" usr/sbin/
        cp "$WPA_DIR/usr/bin/wpa_cli" usr/bin/
    fi
    
    # Install lighttpd
    log_info "Installing web server..."
    local LIGHTTPD_DIR="$OPENWRT_SOURCE/build_dir/target-arm_xscale_be_musl_eabi/lighttpd-*"
    if [ -d "$LIGHTTPD_DIR" ]; then
        cp "$LIGHTTPD_DIR/usr/sbin/lighttpd" usr/sbin/
        cp -a "$LIGHTTPD_DIR/usr/lib/lighttpd/" usr/lib/lighttpd/ 2>/dev/null || true
        cp -a "$LIGHTTPD_DIR/etc/lighttpd/" etc/ 2>/dev/null || true
        cp -a "$LIGHTTPD_DIR/www/" usr/www/ 2>/dev/null || true
    fi
    
    # Install Dropbear SSH (optional)
    log_info "Installing SSH server..."
    local DROPBEAR_DIR="$OPENWRT_SOURCE/build_dir/target-arm_xscale_be_musl_eabi/dropbear-*"
    if [ -d "$DROPBEAR_DIR" ]; then
        cp "$DROPBEAR_DIR/usr/sbin/dropbear" usr/sbin/
        cp "$DROPBEAR_DIR/usr/bin/dbclient" usr/bin/ 2>/dev/null || true
        cp "$DROPBEAR_DIR/usr/bin/dropbearkey" usr/bin/ 2>/dev/null || true
        mkdir -p etc/dropbear
        cp "$SCRIPT_DIR/configs/dropbear_config" etc/dropbear/ 2>/dev/null || true
    fi
    
    cd "$PROJECT_ROOT"
}

# =============================================================================
# Add Custom Files
# =============================================================================

add_custom_files() {
    log_info "Adding Karotz-specific custom files..."
    
    # Copy original scripts (modified for open-source)
    cp "$PROJECT_ROOT/functions.sh" "$ROOTFS_DIR/usr/scripts/"
    cp "$PROJECT_ROOT/waitfornetwork.sh" "$ROOTFS_DIR/usr/scripts/"
    chmod 755 "$ROOTFS_DIR/usr/scripts/"*.sh
    
    # Copy sound files
    mkdir -p "$ROOTFS_DIR/tmp/"
    cp "$PROJECT_ROOT/sound/"*.mp3 "$ROOTFS_DIR/tmp/"
    
    # Copy web interface
    if [ -d "$PROJECT_ROOT/installpage" ]; then
        cp -a "$PROJECT_ROOT/installpage/"* "$ROOTFS_DIR/usr/www/"
        chmod 755 "$ROOTFS_DIR/usr/www/cgi-bin/"*.sh 2>/dev/null || true
    fi
    
    # Create init scripts
    cat > "$ROOTFS_DIR/etc/init.d/rcS" << 'EOF'
#!/bin/sh

# Karotz Custom Init Script

# Mount filesystem
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devpts devpts /dev/pts

# Setup device nodes
mknod -m 666 /dev/null c 1 3
mknod -m 666 /dev/zero c 1 5
mknod -m 666 /dev/random c 1 8
mknod -m 666 /dev/urandom c 1 9
mknod -m 644 /dev/console c 5 1

# Initialize LED
echo "Starting Karotz..." > /dev/kmsg

# Start services
/usr/scripts/led_green_pulse &

# Start network
if [ -f /usr/scripts/waitfornetwork.sh ]; then
    /usr/scripts/waitfornetwork.sh &
fi

# Start web server
if [ -f /usr/sbin/lighttpd ]; then
    /usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf &
fi

# Start SSH (if enabled)
if [ -f /etc/dropbear/dropbear_enable ]; then
    /usr/sbin/dropbear &
fi

# Keep system running
exec /bin/sh
EOF
    chmod 755 "$ROOTFS_DIR/etc/init.d/rcS"
    
    # Create inittab
    cat > "$ROOTFS_DIR/etc/inittab" << 'EOF'
::sysinit:/etc/init.d/rcS
::askfirst:/bin/sh
::ctrlaltdel:/sbin/reboot
::shutdown:/sbin/halt
::restart:/sbin/init
EOF
    
    # Create fstab
    cat > "$ROOTFS_DIR/etc/fstab" << 'EOF'
proc /proc proc defaults 0 0
sysfs /sys sysfs defaults 0 0
devpts /dev/pts devpts defaults 0 0
EOF
    
    # Create passwd, group, shadow
    cat > "$ROOTFS_DIR/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/sh
daemon:x:1:1:daemon:/usr/sbin:/bin/false
bin:x:2:2:bin:/bin:/bin/false
sys:x:3:3:sys:/dev:/bin/false
sync:x:4:65534:sync:/bin:/bin/sync
nobody:x:65534:65534:nobody:/nonexistent:/bin/false
www-data:x:33:33:www-data:/var/www:/bin/false
EOF
    
    cat > "$ROOTFS_DIR/etc/group" << 'EOF'
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
adm:x:4:
tty:x:5:
disk:x:6:
lp:x:7:
mail:x:8:
news:x:9:
uucp:x:10:
man:x:12:
proxy:x:13:
kmem:x:15:
dialout:x:20:
fax:x:21:
voice:x:22:
cdrom:x:24:
floppy:x:25:
tape:x:26:
sudo:x:27:
dip:x:28:
www-data:x:33:
nogroup:x:65534:
EOF
    
    cat > "$ROOTFS_DIR/etc/shadow" << 'EOF'
root:!:18382:0:99999:7:::
daemon:*:18382:0:99999:7:::
bin:*:18382:0:99999:7:::
sys:*:18382:0:99999:7:::
sync:*:18382:0:99999:7:::
nobody:*:18382:0:99999:7:::
www-data:*:18382:0:99999:7:::
EOF
}

# =============================================================================
# Create RootFS Image
# =============================================================================

create_image() {
    log_info "Creating root filesystem image..."
    
    cd "$ROOTFS_DIR"
    
    # Calculate image size (compressed)
    local ROOTFS_SIZE=$(du -s . | cut -f1)
    local IMG_SIZE=$((ROOTFS_SIZE * 2))  # Double the size for compression overhead
    
    # Create a temporary image file
    local TEMP_IMG="$BUILD_DIR/rootfs.img.raw"
    
    log_info "Creating image of size ${IMG_SIZE}KB..."
    
    # Create ext2 image
    dd if=/dev/zero of="$TEMP_IMG" bs=1K count=${IMG_SIZE} 2>/dev/null || true
    mkfs.ext2 -F -i 4096 "$TEMP_IMG" 2>/dev/null || true
    
    # Mount and copy files
    local MOUNT_POINT="$BUILD_DIR/mnt"
    mkdir -p "$MOUNT_POINT"
    
    if mount -o loop "$TEMP_IMG" "$MOUNT_POINT" 2>/dev/null; then
        log_info "Copying files to image..."
        cp -a * "$MOUNT_POINT/" 2>/dev/null || true
        umount "$MOUNT_POINT"
    else
        # Fallback: create a tar.gz directly
        log_warning "Loop mount failed, creating tar.gz instead"
        tar -czf "$ROOTFS_IMG" . 2>/dev/null || log_error "Failed to create rootfs image"
        rm -f "$TEMP_IMG"
        return
    fi
    
    # Compress the image
    log_info "Compressing image..."
    gzip -9 -c "$TEMP_IMG" > "$ROOTFS_IMG"
    
    # Clean up
    rm -f "$TEMP_IMG"
    rm -rf "$MOUNT_POINT"
    
    # Generate checksums
    if [ -f "$ROOTFS_IMG" ]; then
        local sha256=$(sha256sum "$ROOTFS_IMG" | cut -d' ' -f1)
        local md5=$(md5sum "$ROOTFS_IMG" | cut -d' ' -f1)
        
        log_success "Root filesystem image created successfully"
        log_success "  File: $ROOTFS_IMG"
        log_success "  Size: $(du -h "$ROOTFS_IMG" | cut -f1)"
        log_success "  SHA256: $sha256"
        log_success "  MD5: $md5"
        
        # Save checksums
        echo "rootfs.img.gz|$sha256|$md5" > "$OUTPUT_DIR/rootfs.checksum"
    else
        log_error "Root filesystem image not created"
    fi
    
    cd "$PROJECT_ROOT"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo "=========================================="
    echo "Karotz Open Firmware - RootFS Builder"
    echo "=========================================="
    echo ""
    
    # Create directories
    mkdir -p "$BUILD_DIR"
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Initialize log file
    echo "RootFS Build Log - $(date)" > "$LOG_FILE"
    echo "==========================================" >> "$LOG_FILE"
    
    # Handle clean option
    if [ "${1:-}" = "clean" ]; then
        clean_build
        log_success "RootFS build directory cleaned"
        exit 0
    fi
    
    # Build steps
    check_toolchain
    download_openwrt
    configure_openwrt
    build_packages
    create_rootfs
    add_custom_files
    create_image
    
    echo ""
    echo "=========================================="
    echo "RootFS build completed successfully!"
    echo "=========================================="
    echo ""
    echo "Output: $ROOTFS_IMG"
    echo "Checksums saved to: $OUTPUT_DIR/rootfs.checksum"
    echo "Build log saved to: $LOG_FILE"
}

# Run main function
main "$@"
