#!/bin/bash
# =============================================================================
# Karotz Open Firmware - Custom Kernel Builder
# =============================================================================
# This script builds a custom Linux kernel for the Karotz robot.
# 
# Hardware: ARM926EJ-S (ARMv5TE)
# Platform: Karotz / Nabaztag (Violet/Mindscape)
# Kernel: Linux 5.4.x (OpenWrt backport)
# 
# Usage: ./build_kernel.sh [clean|menuconfig|savedefconfig]
#   clean: Clean build directory
#   menuconfig: Run kernel menuconfig
#   savedefconfig: Save current config as defconfig
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/output/build/kernel"
OUTPUT_DIR="$PROJECT_ROOT/output/firmware"
LOG_FILE="$PROJECT_ROOT/output/logs/kernel_build_$(date +%Y%m%d_%H%M%S).log"

# Kernel configuration
KERNEL_VERSION="5.4.200"
KERNEL_SOURCE="https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.xz"
KERNEL_SOURCE_DIR="$PROJECT_ROOT/output/sources/linux-$KERNEL_VERSION"

# Toolchain
TOOLCHAIN_DIR="$PROJECT_ROOT/output/toolchain"
TARGET="armv5te-linaro-musleabi"
PREFIX="$TOOLCHAIN_DIR/$TARGET"

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
    log_info "Cleaning kernel build..."
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
    if [ -f "$OUTPUT_DIR/zImage" ]; then
        rm -f "$OUTPUT_DIR/zImage"
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
    
    if [ ! -f "$PREFIX/bin/$TARGET-gcc" ]; then
        log_error "Toolchain compiler not found at $PREFIX/bin/$TARGET-gcc"
    fi
    
    log_success "Toolchain verified"
}

# =============================================================================
# Download Kernel Source
# =============================================================================

download_kernel() {
    log_info "Downloading kernel source..."
    
    if [ ! -d "$KERNEL_SOURCE_DIR" ]; then
        mkdir -p "$KERNEL_SOURCE_DIR"
        cd "$KERNEL_SOURCE_DIR"
        
        # Download kernel source
        if ! wget -q --show-progress -O "linux-$KERNEL_VERSION.tar.xz" "$KERNEL_SOURCE"; then
            log_error "Failed to download kernel source"
        fi
        
        # Verify download
        local expected_hash="$(sha256sum "linux-$KERNEL_VERSION.tar.xz" | cut -d' ' -f1)"
        log_info "Kernel archive SHA256: $expected_hash"
        
        # Extract
        log_info "Extracting kernel source..."
        tar -xf "linux-$KERNEL_VERSION.tar.xz" --strip-components=1
        rm "linux-$KERNEL_VERSION.tar.xz"
        
        cd "$PROJECT_ROOT"
    else
        log_info "Kernel source already exists at $KERNEL_SOURCE_DIR"
    fi
}

# =============================================================================
# Apply Karotz Patches
# =============================================================================

apply_patches() {
    log_info "Applying Karotz-specific patches..."
    
    cd "$KERNEL_SOURCE_DIR"
    
    # Create patches directory
    mkdir -p "$SCRIPT_DIR/patches"
    
    # Apply patches from patches directory
    if [ -d "$SCRIPT_DIR/patches" ]; then
        for patch in "$SCRIPT_DIR/patches"/*.patch; do
            if [ -f "$patch" ]; then
                log_info "Applying patch: $(basename "$patch")"
                if ! patch -p1 < "$patch"; then
                    log_warning "Patch $(basename "$patch") failed to apply"
                fi
            fi
        done
    fi
    
    cd "$PROJECT_ROOT"
}

# =============================================================================
# Configure Kernel
# =============================================================================

configure_kernel() {
    log_info "Configuring kernel..."
    
    cd "$KERNEL_SOURCE_DIR"
    
    # Use existing config if available
    if [ -f "$SCRIPT_DIR/config_kernel" ]; then
        log_info "Using custom kernel configuration"
        cp "$SCRIPT_DIR/config_kernel" .config
    else
        log_info "Using default OpenWrt configuration for ARMv5"
        # Create minimal config for Karotz
        cat > .config << 'EOF'
# Karotz Custom Kernel Configuration
CONFIG_ARM=y
CONFIG_ARCH_MULTI_V5=y
CONFIG_ARM_THUMB=y
CONFIG_ARM_NOHLT_WORKAROUND=y

# System Type
CONFIG_MACHINE_KAROTZ=y
CONFIG_ARCH_KAROTZ=y

# Processor Type
CONFIG_CPU_ARM926T=y
CONFIG_CPU_32v5=y

# Kernel Features
CONFIG_PREEMPT=y
CONFIG_HZ_100=y
CONFIG_AEABI=y
CONFIG_OABI_COMPAT=y

# Memory Management
CONFIG_PAGE_OFFSET=0xC0000000
CONFIG_MEMORY_START=0xC0000000
CONFIG_MEMORY_SIZE=0x04000000

# Device Drivers
CONFIG_MTD=y
CONFIG_MTD_NAND=y
CONFIG_MTD_NAND_DENALI=y
CONFIG_MTD_UBI=y
CONFIG_UBI auto-attach mtd

# Filesystems
CONFIG_YAFFS_FS=y
CONFIG_YAFFS_YAFFS2=y
CONFIG_JFFS2_FS=y
CONFIG_CRAMFS=y
CONFIG_SQUASHFS=y
CONFIG_SQUASHFS_LZ4=y
CONFIG_SQUASHFS_LZO=y
CONFIG_SQUASHFS_XZ=y

# Networking
CONFIG_NET=y
CONFIG_PACKET=y
CONFIG_UNIX=y
CONFIG_INET=y
CONFIG_IP_PNP=y
CONFIG_IP_PNP_DHCP=y
CONFIG_NETFILTER=y

# Wireless
CONFIG_CFG80211=y
CONFIG_MAC80211=y
CONFIG_RT2X00=y
CONFIG_RT2500USB=y
CONFIG_RT2800USB=y
CONFIG_RT2800USB_RT33XX=y
CONFIG_RT2800USB_RT35XX=y
CONFIG_RT2800USB_RT53XX=y
CONFIG_RT2800USB_UNKNOWN=y

# USB Support
CONFIG_USB=y
CONFIG_USB_EHCI_HCD=y
CONFIG_USB_OHCI_HCD=y
CONFIG_USB_STORAGE=y
CONFIG_USB_SERIAL=y
CONFIG_USB_SERIAL_FTDI_SIO=y

# Audio
CONFIG_SOUND=y
CONFIG_SND=y
CONFIG_SND_MIXER_OSS=y
CONFIG_SND_PCM_OSS=y
CONFIG_SND_PCM_OSS_PLUGINS=y
CONFIG_SND_USB_AUDIO=y

# LED Support
CONFIG_NEW_LEDS=y
CONFIG_LEDS_CLASS=y
CONFIG_LEDS_GPIO=y

# Character Devices
CONFIG_DEVPTS_MULTIPLE_INSTANCES=y
CONFIG_UNIX98_PTYS=y

# Console
CONFIG_VT=y
CONFIG_VT_CONSOLE=y
CONFIG_SERIAL_CORE=y
CONFIG_SERIAL_CORE_CONSOLE=y

# Compression
CONFIG_ZLIB_INFLATE=y
CONFIG_ZLIB_DEFLATE=y
CONFIG_LZO_COMPRESS=y
CONFIG_LZO_DECOMPRESS=y
CONFIG_XZ_DEC=y
CONFIG_XZ_DEC_X86=y
CONFIG_XZ_DEC_POWERPC=y
CONFIG_XZ_DEC_IA64=y
CONFIG_XZ_DEC_ARM=y
CONFIG_XZ_DEC_ARMTHUMB=y
CONFIG_XZ_DEC_SPARC=y

# Kernel hacking
CONFIG_MAGIC_SYSRQ=y
EOF
    fi
    
    # Apply defconfig if requested
    if [ "${1:-}" = "defconfig" ]; then
        make ARCH=arm CROSS_COMPILE="$TARGET-" defconfig
    fi
    
    # Run oldconfig to update config
    make ARCH=arm CROSS_COMPILE="$TARGET-" oldconfig -j1 || true
    
    cd "$PROJECT_ROOT"
}

# =============================================================================
# Build Kernel
# =============================================================================

build_kernel() {
    log_info "Building kernel..."
    
    cd "$KERNEL_SOURCE_DIR"
    
    # Set environment
    export ARCH=arm
    export CROSS_COMPILE="$TARGET-"
    export PATH="$PREFIX/bin:$PATH"
    
    # Build kernel
    log_info "Starting compilation (this may take 30-60 minutes)..."
    if ! make zImage -j$(nproc) 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Kernel build failed"
    fi
    
    # Copy output
    if [ -f "arch/arm/boot/zImage" ]; then
        log_info "Copying zImage to output directory..."
        cp "arch/arm/boot/zImage" "$OUTPUT_DIR/zImage"
        
        # Generate checksum
        local sha256=$(sha256sum "$OUTPUT_DIR/zImage" | cut -d' ' -f1)
        local md5=$(md5sum "$OUTPUT_DIR/zImage" | cut -d' ' -f1)
        
        log_success "Kernel built successfully"
        log_success "  File: $OUTPUT_DIR/zImage"
        log_success "  Size: $(du -h "$OUTPUT_DIR/zImage" | cut -f1)"
        log_success "  SHA256: $sha256"
        log_success "  MD5: $md5"
        
        # Save checksums
        echo "zImage|$sha256|$md5" > "$OUTPUT_DIR/zImage.checksum"
    else
        log_error "zImage not found after build"
    fi
    
    cd "$PROJECT_ROOT"
}

# =============================================================================
# Kernel Menuconfig
# =============================================================================

run_menuconfig() {
    log_info "Running kernel menuconfig..."
    
    cd "$KERNEL_SOURCE_DIR"
    
    export ARCH=arm
    export CROSS_COMPILE="$TARGET-"
    export PATH="$PREFIX/bin:$PATH"
    
    make menuconfig
    
    cd "$PROJECT_ROOT"
}

# =============================================================================
# Save Defconfig
# =============================================================================

save_defconfig() {
    log_info "Saving current config as defconfig..."
    
    cd "$KERNEL_SOURCE_DIR"
    
    export ARCH=arm
    export CROSS_COMPILE="$TARGET-"
    
    make savedefconfig
    cp defconfig "$SCRIPT_DIR/config_kernel"
    
    log_success "Defconfig saved to $SCRIPT_DIR/config_kernel"
    cd "$PROJECT_ROOT"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo "=========================================="
    echo "Karotz Open Firmware - Kernel Builder"
    echo "=========================================="
    echo ""
    
    # Create directories
    mkdir -p "$BUILD_DIR"
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Initialize log file
    echo "Kernel Build Log - $(date)" > "$LOG_FILE"
    echo "==========================================" >> "$LOG_FILE"
    
    # Handle options
    case "${1:-}" in
        clean)
            clean_build
            log_success "Kernel build directory cleaned"
            exit 0
            ;;
        menuconfig)
            check_toolchain
            download_kernel
            apply_patches
            configure_kernel
            run_menuconfig
            exit 0
            ;;
        savedefconfig)
            check_toolchain
            download_kernel
            apply_patches
            configure_kernel
            save_defconfig
            exit 0
            ;;
    esac
    
    # Full build
    check_toolchain
    download_kernel
    apply_patches
    configure_kernel
    build_kernel
    
    echo ""
    echo "=========================================="
    echo "Kernel build completed successfully!"
    echo "=========================================="
    echo ""
    echo "Output: $OUTPUT_DIR/zImage"
    echo "Checksums saved to: $OUTPUT_DIR/zImage.checksum"
    echo "Build log saved to: $LOG_FILE"
}

# Run main function
main "$@"
