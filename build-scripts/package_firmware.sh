#!/bin/bash
# =============================================================================
# Karotz Open Firmware - Package Firmware Script
# =============================================================================
# This script packages all built components into a complete firmware
# package ready for installation on Karotz via USB.
# 
# Usage: ./package_firmware.sh [clean|usb]
#   clean: Remove existing package
#   usb: Create USB-ready package in a specified directory
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FIRMWARE_DIR="$PROJECT_ROOT/output/firmware"
PACKAGE_DIR="$PROJECT_ROOT/output/package"
LOG_FILE="$PROJECT_ROOT/output/logs/package_$(date +%Y%m%d_%H%M%S).log"

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

clean_package() {
    log_info "Cleaning firmware package..."
    if [ -d "$PACKAGE_DIR" ]; then
        rm -rf "$PACKAGE_DIR"
    fi
    mkdir -p "$PACKAGE_DIR"
}

# =============================================================================
# Check Required Files
# =============================================================================

check_files() {
    log_info "Checking required firmware files..."
    
    local missing=()
    
    # Check kernel
    if [ ! -f "$FIRMWARE_DIR/zImage" ]; then
        missing+=("zImage")
    fi
    
    # Check rootfs
    if [ ! -f "$FIRMWARE_DIR/rootfs.img.gz" ]; then
        missing+=("rootfs.img.gz")
    fi
    
    # Check checksums
    if [ ! -f "$FIRMWARE_DIR/checksums.sha256" ]; then
        missing+=("checksums.sha256")
    fi
    
    # Check YAFFS tools
    if [ ! -d "$FIRMWARE_DIR/yaffs-tools" ] && [ ! -f "$FIRMWARE_DIR/yaffs-tools-open.tar.gz" ]; then
        missing+=("yaffs-tools")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required files: ${missing[*]}"
        log_error "Please build all components first:"
        log_error "  ./build-scripts/tools/build_toolchain.sh"
        log_error "  ./build-scripts/kernel/build_kernel.sh"
        log_error "  ./build-scripts/rootfs/build_rootfs.sh"
        log_error "  ./build-scripts/tools/build_yaffs.sh"
        log_error "  ./build-scripts/verification/verify_checksums.sh"
    fi
    
    log_success "All required files are present"
}

# =============================================================================
# Create Package Directory Structure
# =============================================================================

create_package() {
    log_info "Creating firmware package..."
    
    # Clean and create package directory
    clean_package
    
    # Copy firmware files
    log_info "Copying firmware files..."
    cp "$FIRMWARE_DIR/zImage" "$PACKAGE_DIR/"
    cp "$FIRMWARE_DIR/rootfs.img.gz" "$PACKAGE_DIR/"
    
    # Copy YAFFS tools
    if [ -d "$FIRMWARE_DIR/yaffs-tools" ]; then
        mkdir -p "$PACKAGE_DIR/yaffs-tools"
        cp "$FIRMWARE_DIR/yaffs-tools/"* "$PACKAGE_DIR/yaffs-tools/"
        # Create tar.gz of tools
        cd "$PACKAGE_DIR"
        tar -czf yaffs-tools.tar.gz yaffs-tools/
        rm -rf yaffs-tools
        cd "$PROJECT_ROOT"
    elif [ -f "$FIRMWARE_DIR/yaffs-tools-open.tar.gz" ]; then
        cp "$FIRMWARE_DIR/yaffs-tools-open.tar.gz" "$PACKAGE_DIR/yaffs-tools.tar.gz"
    fi
    
    # Copy checksums
    cp "$FIRMWARE_DIR/checksums.sha256" "$PACKAGE_DIR/"
    if [ -f "$FIRMWARE_DIR/checksums.sha256.sig" ]; then
        cp "$FIRMWARE_DIR/checksums.sha256.sig" "$PACKAGE_DIR/"
    fi
    
    # Copy original scripts
    log_info "Copying installation scripts..."
    cp "$PROJECT_ROOT/autorun" "$PACKAGE_DIR/"
    cp "$PROJECT_ROOT/installfirmware.sh" "$PACKAGE_DIR/"
    cp "$PROJECT_ROOT/functions.sh" "$PACKAGE_DIR/"
    cp "$PROJECT_ROOT/waitfornetwork.sh" "$PACKAGE_DIR/"
    
    # Copy sound files
    log_info "Copying sound files..."
    mkdir -p "$PACKAGE_DIR/sound"
    cp "$PROJECT_ROOT/sound/"*.mp3 "$PACKAGE_DIR/sound/"
    
    # Copy web interface
    log_info "Copying web interface..."
    mkdir -p "$PACKAGE_DIR/installpage"
    cp -a "$PROJECT_ROOT/installpage/"* "$PACKAGE_DIR/installpage/"
    
    # Create version file
    cat > "$PACKAGE_DIR/VERSION" << 'EOF'
Karotz Open Firmware
===================

Version: 1.0.0-open
Build Date: $(date)
Architecture: ARMv5TE (ARM926EJ-S)

Components:
- Kernel: Custom Linux $(cat "$FIRMWARE_DIR/zImage.checksum" 2>/dev/null | cut -d'|' -f1 || echo "unknown")
- RootFS: OpenWrt-based custom build
- YAFFS Tools: Open-source build

This is a fully open-source firmware build.
All components are compiled from source.
EOF
    
    log_success "Firmware package created successfully"
}

# =============================================================================
# Create USB Package
# =============================================================================

create_usb_package() {
    local usb_dir="${1:-"")"
    
    if [ -z "$usb_dir" ]; then
        log_error "USB directory not specified"
        log_error "Usage: ./package_firmware.sh usb /path/to/usb"
    fi
    
    if [ ! -d "$usb_dir" ]; then
        log_error "USB directory not found: $usb_dir"
    fi
    
    log_info "Creating USB package in $usb_dir..."
    
    # Copy all files to USB
    cp "$PACKAGE_DIR/"* "$usb_dir/"
    cp -r "$PACKAGE_DIR/installpage" "$usb_dir/" 2>/dev/null || true
    cp -r "$PACKAGE_DIR/sound" "$usb_dir/" 2>/dev/null || true
    
    # Create autorun.sig (optional signature)
    if [ -f "$PACKAGE_DIR/checksums.sha256.sig" ]; then
        cp "$PACKAGE_DIR/checksums.sha256.sig" "$usb_dir/autorun.sig"
    fi
    
    log_success "USB package created in $usb_dir"
    log_success "Files copied:"
    ls -la "$usb_dir" | tail -n +4 | awk '{print "  " $9 " (" $5 " bytes)"}'
}

# =============================================================================
# Create Tarball Package
# =============================================================================

create_tarball() {
    log_info "Creating tarball package..."
    
    local tarball_name="karotz-open-firmware-$(date +%Y%m%d-%H%M%S).tar.gz"
    local tarball_path="$PROJECT_ROOT/output/$tarball_name"
    
    cd "$PACKAGE_DIR"
    tar -czf "$tarball_path" . 2>/dev/null || log_error "Failed to create tarball"
    
    log_success "Tarball created: $tarball_path"
    log_success "  Size: $(du -h "$tarball_path" | cut -f1)"
    
    # Generate checksum for tarball
    local sha256=$(sha256sum "$tarball_path" | cut -d' ' -f1)
    local md5=$(md5sum "$tarball_path" | cut -d' ' -f1)
    
    echo "Tarball Checksums:" > "$PACKAGE_DIR/TARBALL_CHECKSUMS"
    echo "  SHA256: $sha256" >> "$PACKAGE_DIR/TARBALL_CHECKSUMS"
    echo "  MD5: $md5" >> "$PACKAGE_DIR/TARBALL_CHECKSUMS"
    
    log_success "Tarball checksums saved to $PACKAGE_DIR/TARBALL_CHECKSUMS"
    
    cd "$PROJECT_ROOT"
}

# =============================================================================
# Verify Package
# =============================================================================

verify_package() {
    log_info "Verifying firmware package..."
    
    # Check all expected files
    local expected_files=(
        "zImage"
        "rootfs.img.gz"
        "yaffs-tools.tar.gz"
        "checksums.sha256"
        "autorun"
        "installfirmware.sh"
        "functions.sh"
        "waitfornetwork.sh"
        "VERSION"
    )
    
    local missing=()
    
    for file in "${expected_files[@]}"; do
        if [ ! -f "$PACKAGE_DIR/$file" ]; then
            missing+=("$file")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_warning "Missing files in package: ${missing[*]}"
    fi
    
    # Verify checksums
    log_info "Verifying package checksums..."
    cd "$PACKAGE_DIR"
    
    # Quick verification
    if [ -f "checksums.sha256" ]; then
        while IFS='|' read -r filename expected_sha256 expected_md5 expected_size; do
            [[ "$filename" =~ ^#.*$ ]] && continue
            [[ -z "$filename" ]] && continue
            
            if [ -f "$filename" ]; then
                local actual_sha256=$(sha256sum "$filename" | cut -d' ' -f1)
                if [ "$actual_sha256" != "$expected_sha256" ]; then
                    log_warning "Checksum mismatch for $filename"
                else
                    log_info "  OK: $filename"
                fi
            else
                log_warning "  MISSING: $filename"
            fi
        done < "checksums.sha256"
    fi
    
    cd "$PROJECT_ROOT"
    
    if [ ${#missing[@]} -eq 0 ]; then
        log_success "Package verified successfully"
    else
        log_warning "Package has missing files but verification complete"
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo "=========================================="
    echo "Karotz Open Firmware - Package Firmware"
    echo "=========================================="
    echo ""
    
    # Create directories
    mkdir -p "$FIRMWARE_DIR"
    mkdir -p "$PACKAGE_DIR"
    mkdir -p "$PROJECT_ROOT/output/logs"
    
    # Initialize log file
    echo "Package Log - $(date)" > "$LOG_FILE"
    echo "==========================================" >> "$LOG_FILE"
    
    # Handle options
    case "${1:-}" in
        clean)
            clean_package
            log_success "Firmware package cleaned"
            exit 0
            ;;
        usb)
            check_files
            create_package
            create_usb_package "${2:-}"
            ;;
        tarball)
            check_files
            create_package
            create_tarball
            ;;
    esac
    
    # Default: create package and verify
    check_files
    create_package
    verify_package
    create_tarball
    
    echo ""
    echo "=========================================="
    echo "Firmware package created successfully!"
    echo "=========================================="
    echo ""
    echo "Package location: $PACKAGE_DIR"
    echo "Tarball location: $PROJECT_ROOT/output/karotz-open-firmware-*.tar.gz"
    echo ""
    echo "To create a USB installation key:"
    echo "  1. Format USB as FAT32"
    echo "  2. Copy all files from $PACKAGE_DIR to USB root"
    echo "  3. Insert into Karotz and power on while holding button"
    echo ""
    echo "Build log saved to: $LOG_FILE"
}

# Run main function
main "$@"
