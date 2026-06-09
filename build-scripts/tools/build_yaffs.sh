#!/bin/bash
# =============================================================================
# Karotz Open Firmware - YAFFS Tools Builder
# =============================================================================
# This script builds YAFFS filesystem tools from source.
# 
# YAFFS (Yet Another Flash File System) is a filesystem designed for NAND flash.
# This builds the user-space tools needed for Karotz firmware:
# - nandwrite
# - flash_eraseall
# - mkyaffs2image
# - yaffs2utils
# 
# Usage: ./build_yaffs.sh [clean]
#   clean: Remove existing build and start fresh
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/output/build/yaffs"
OUTPUT_DIR="$PROJECT_ROOT/output/firmware/yaffs-tools"
LOG_FILE="$PROJECT_ROOT/output/logs/yaffs_build_$(date +%Y%m%d_%H%M%S).log"

# YAFFS Source
YAFFS_VERSION="v5.1.6"
YAFFS_REPO="https://github.com/yaffs/yaffs2.git"
YAFFS_SOURCE="$PROJECT_ROOT/output/sources/yaffs2"

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
    log_info "Cleaning YAFFS build..."
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
    if [ -d "$OUTPUT_DIR" ]; then
        rm -rf "$OUTPUT_DIR"
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
# Download YAFFS Source
# =============================================================================

download_yaffs() {
    log_info "Downloading YAFFS source..."
    
    if [ ! -d "$YAFFS_SOURCE" ]; then
        mkdir -p "$YAFFS_SOURCE"
        cd "$YAFFS_SOURCE"
        
        # Clone YAFFS repository
        if ! git clone --depth 1 --branch "$YAFFS_VERSION" "$YAFFS_REPO" .; then
            log_error "Failed to clone YAFFS repository"
        fi
        
        # Verify clone
        if [ ! -f "yaffs_guts.c" ]; then
            log_error "YAFFS source files not found"
        fi
        
        cd "$PROJECT_ROOT"
    else
        log_info "YAFFS source already exists at $YAFFS_SOURCE"
    fi
}

# =============================================================================
# Build MTD Utils (nandwrite, flash_eraseall)
# =============================================================================

build_mtd_utils() {
    log_info "Building MTD utilities..."
    
    cd "$BUILD_DIR"
    
    # Download mtd-utils source
    if [ ! -d "mtd-utils" ]; then
        log_info "Downloading mtd-utils..."
        git clone --depth 1 https://git.infradead.org/mtd-utils.git mtd-utils
    fi
    
    cd "mtd-utils"
    
    # Configure
    log_info "Configuring mtd-utils..."
    export CC="$TARGET-gcc"
    export CROSS_COMPILE="$TARGET-"
    export PATH="$PREFIX/bin:$PATH"
    
    if [ -f "configure" ]; then
        ./configure --host=arm-linux --prefix=/usr 2>&1 | tee -a "$LOG_FILE" || true
    fi
    
    # Build specific tools
    log_info "Building nandwrite and flash_eraseall..."
    if ! make -j$(nproc) CFLAGS="-Os -Wall" nandwrite flash_eraseall 2>&1 | tee -a "$LOG_FILE"; then
        log_warning "mtd-utils build partially failed, trying alternative"
        # Try to build just what we need
        make clean 2>/dev/null || true
        
        # Cross-compile nandwrite
        $TARGET-gcc -Os -Wall -o nandwrite nandwrite.c \
            lib/libmtd.c lib/libfsmtd.c lib/libiniprobe.c \
            -I. -Iinclude -D_FILE_OFFSET_BITS=64 2>&1 | tee -a "$LOG_FILE" || true
        
        # Cross-compile flash_eraseall
        $TARGET-gcc -Os -Wall -o flash_eraseall flash_eraseall.c \
            lib/libmtd.c -I. -Iinclude 2>&1 | tee -a "$LOG_FILE" || true
    fi
    
    # Copy outputs
    if [ -f "nandwrite" ]; then
        mkdir -p "$OUTPUT_DIR"
        cp nandwrite "$OUTPUT_DIR/"
        log_info "Copied nandwrite to output"
    fi
    
    if [ -f "flash_eraseall" ]; then
        cp flash_eraseall "$OUTPUT_DIR/"
        log_info "Copied flash_eraseall to output"
    fi
    
    cd "$BUILD_DIR"
}

# =============================================================================
# Build YAFFS2 Utils
# =============================================================================

build_yaffs_utils() {
    log_info "Building YAFFS2 utilities..."
    
    cd "$YAFFS_SOURCE"
    
    # Set environment
    export CC="$TARGET-gcc"
    export CROSS_COMPILE="$TARGET-"
    export PATH="$PREFIX/bin:$PATH"
    export CFLAGS="-Os -Wall -D_FILE_OFFSET_BITS=64"
    
    # Build yaffs2 utils
    log_info "Building mkyaffs2image..."
    if ! make -j$(nproc) mkyaffs2image 2>&1 | tee -a "$LOG_FILE"; then
        log_warning "YAFFS2 utils build failed, trying manual compilation"
        
        # Manual compilation
        $TARGET-gcc $CFLAGS -o mkyaffs2image mkyaffs2image.c \
            yaffs_guts.c yaffs_ecc.c yaffs_bitmap.c \
            yaffs_yaffs1.c yaffs_yaffs2.c yaffs_analyze.c \
            yaffs_hweight.c yaffs_verify.c \
            -I. 2>&1 | tee -a "$LOG_FILE" || true
    fi
    
    # Copy outputs
    if [ -f "mkyaffs2image" ]; then
        cp mkyaffs2image "$OUTPUT_DIR/"
        log_info "Copied mkyaffs2image to output"
    fi
    
    # Build other YAFFS tools
    for tool in yaffs2utils yaffscfg; do
        if [ -f "$tool.c" ]; then
            log_info "Building $tool..."
            if $TARGET-gcc $CFLAGS -o "$tool" "$tool.c" -I. 2>&1 | tee -a "$LOG_FILE"; then
                cp "$tool" "$OUTPUT_DIR/"
                log_info "Copied $tool to output"
            fi
        fi
    done
    
    cd "$BUILD_DIR"
}

# =============================================================================
# Build zlib for YAFFS
# =============================================================================

build_zlib() {
    log_info "Building zlib for ARM..."
    
    cd "$BUILD_DIR"
    
    # Download zlib source
    if [ ! -d "zlib" ]; then
        log_info "Downloading zlib..."
        wget -q --show-progress -O zlib.tar.gz https://zlib.net/zlib-1.2.11.tar.gz
        tar -xzf zlib.tar.gz
        rm zlib.tar.gz
    fi
    
    cd "zlib-*"
    
    # Configure and build for ARM
    export CC="$TARGET-gcc"
    export CROSS_COMPILE="$TARGET-"
    export PATH="$PREFIX/bin:$PATH"
    export CHOST="arm-linux"
    
    ./configure --prefix=/usr 2>&1 | tee -a "$LOG_FILE" || true
    make -j$(nproc) 2>&1 | tee -a "$LOG_FILE" || log_warning "zlib build had issues"
    
    # Copy libz
    if [ -f "libz.a" ]; then
        cp libz.a "$OUTPUT_DIR/"
        log_info "Copied libz.a to output"
    fi
    
    cd "$BUILD_DIR"
}

# =============================================================================
# Package Tools
# =============================================================================

package_tools() {
    log_info "Packaging YAFFS tools..."
    
    cd "$OUTPUT_DIR"
    
    # Create tar.gz package
    local PACKAGE_NAME="yaffs-tools-open.tar.gz"
    tar -czf "$PACKAGE_NAME" .
    
    # Generate checksums
    if [ -f "$PACKAGE_NAME" ]; then
        local sha256=$(sha256sum "$PACKAGE_NAME" | cut -d' ' -f1)
        local md5=$(md5sum "$PACKAGE_NAME" | cut -d' ' -f1)
        
        log_success "YAFFS tools packaged successfully"
        log_success "  File: $OUTPUT_DIR/$PACKAGE_NAME"
        log_success "  Size: $(du -h "$PACKAGE_NAME" | cut -f1)"
        log_success "  SHA256: $sha256"
        log_success "  MD5: $md5"
        
        # Save checksums
        echo "yaffs-tools-open.tar.gz|$sha256|$md5" > "$OUTPUT_DIR/yaffs-tools.checksum"
    else
        log_error "Failed to create YAFFS tools package"
    fi
    
    cd "$PROJECT_ROOT"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo "=========================================="
    echo "Karotz Open Firmware - YAFFS Tools Builder"
    echo "=========================================="
    echo ""
    
    # Create directories
    mkdir -p "$BUILD_DIR"
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Initialize log file
    echo "YAFFS Tools Build Log - $(date)" > "$LOG_FILE"
    echo "==========================================" >> "$LOG_FILE"
    
    # Handle clean option
    if [ "${1:-}" = "clean" ]; then
        clean_build
        log_success "YAFFS build directory cleaned"
        exit 0
    fi
    
    # Build steps
    check_toolchain
    download_yaffs
    build_mtd_utils
    build_yaffs_utils
    build_zlib
    package_tools
    
    echo ""
    echo "=========================================="
    echo "YAFFS tools build completed successfully!"
    echo "=========================================="
    echo ""
    echo "Output directory: $OUTPUT_DIR"
    echo "Checksums saved to: $OUTPUT_DIR/yaffs-tools.checksum"
    echo "Build log saved to: $LOG_FILE"
}

# Run main function
main "$@"
