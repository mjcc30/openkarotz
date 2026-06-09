#!/bin/bash
# =============================================================================
# Karotz Open Firmware - Master Build Script
# =============================================================================
# This is the main build script that orchestrates the entire firmware
# build process. It builds all components in the correct order:
# 1. Toolchain
# 2. Kernel
# 3. YAFFS Tools
# 4. Root Filesystem
# 5. Verification
# 6. Packaging
# 
# Usage: ./build_all.sh [clean|fast|toolchain|kernel|rootfs|yaffs|verify|package]
#   clean: Clean all build artifacts
#   fast: Skip toolchain build (if already built)
#   toolchain: Build only toolchain
#   kernel: Build only kernel
#   rootfs: Build only root filesystem
#   yaffs: Build only YAFFS tools
#   verify: Run verification only
#   package: Package only
# 
# Environment Variables:
#   KAROTZ_JOBS: Number of parallel jobs (default: CPU cores)
#   KAROTZ_SKIP_TOOLCHAIN: Skip toolchain build (0 or 1)
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_ROOT/output/logs/build_all_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

log_header() {
    echo ""
    echo -e "${PURPLE}==========================================${NC}"
    echo -e "${PURPLE}  $1${NC}"
    echo -e "${PURPLE}==========================================${NC}"
    echo ""
    echo "$1" >> "$LOG_FILE"
    echo "==========================================" >> "$LOG_FILE"
}

# =============================================================================
# Build Step Functions
# =============================================================================

build_toolchain() {
    log_header "Building ARM Cross-Compilation Toolchain"
    
    local start_time=$(date +%s)
    
    if [ -f "$PROJECT_ROOT/output/toolchain/environment" ]; then
        if [ "${KAROTZ_SKIP_TOOLCHAIN:-0}" = "1" ] || [ "${1:-}" = "fast" ]; then
            log_info "Toolchain already exists, skipping..."
            return 0
        fi
    fi
    
    log_info "Building toolchain (this may take 2-3 hours)..."
    if ! "$SCRIPT_DIR/tools/build_toolchain.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Toolchain build failed"
    fi
    
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local elapsed_min=$((elapsed / 60))
    
    log_success "Toolchain built successfully in ${elapsed_min}m ${((elapsed % 60))}s"
}

build_kernel() {
    log_header "Building Custom Kernel"
    
    local start_time=$(date +%s)
    
    log_info "Building kernel (this may take 30-60 minutes)..."
    if ! "$SCRIPT_DIR/kernel/build_kernel.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Kernel build failed"
    fi
    
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local elapsed_min=$((elapsed / 60))
    
    log_success "Kernel built successfully in ${elapsed_min}m ${((elapsed % 60))}s"
}

build_yaffs() {
    log_header "Building YAFFS Tools"
    
    local start_time=$(date +%s)
    
    log_info "Building YAFFS tools (this may take 5-10 minutes)..."
    if ! "$SCRIPT_DIR/tools/build_yaffs.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log_error "YAFFS tools build failed"
    fi
    
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local elapsed_min=$((elapsed / 60))
    
    log_success "YAFFS tools built successfully in ${elapsed_min}m ${((elapsed % 60))}s"
}

build_rootfs() {
    log_header "Building Root Filesystem"
    
    local start_time=$(date +%s)
    
    log_info "Building root filesystem (this may take 45-90 minutes)..."
    if ! "$SCRIPT_DIR/rootfs/build_rootfs.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Root filesystem build failed"
    fi
    
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local elapsed_min=$((elapsed / 60))
    
    log_success "Root filesystem built successfully in ${elapsed_min}m ${((elapsed % 60))}s"
}

verify_build() {
    log_header "Verifying Build Artifacts"
    
    log_info "Generating and verifying checksums..."
    if ! "$SCRIPT_DIR/verification/verify_checksums.sh" generate 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Checksum generation failed"
    fi
    
    if ! "$SCRIPT_DIR/verification/verify_checksums.sh" verify 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Checksum verification failed"
    fi
    
    log_success "All build artifacts verified"
}

package_build() {
    log_header "Packaging Firmware"
    
    log_info "Packaging all components..."
    if ! "$SCRIPT_DIR/package_firmware.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Packaging failed"
    fi
    
    log_success "Firmware packaged successfully"
}

# =============================================================================
# Clean Function
# =============================================================================

clean_all() {
    log_header "Cleaning All Build Artifacts"
    
    log_info "Cleaning toolchain..."
    "$SCRIPT_DIR/tools/build_toolchain.sh" clean 2>&1 | tee -a "$LOG_FILE" || true
    
    log_info "Cleaning kernel..."
    "$SCRIPT_DIR/kernel/build_kernel.sh" clean 2>&1 | tee -a "$LOG_FILE" || true
    
    log_info "Cleaning YAFFS tools..."
    "$SCRIPT_DIR/tools/build_yaffs.sh" clean 2>&1 | tee -a "$LOG_FILE" || true
    
    log_info "Cleaning root filesystem..."
    "$SCRIPT_DIR/rootfs/build_rootfs.sh" clean 2>&1 | tee -a "$LOG_FILE" || true
    
    log_info "Cleaning package..."
    "$SCRIPT_DIR/package_firmware.sh" clean 2>&1 | tee -a "$LOG_FILE" || true
    
    # Remove output directories
    rm -rf "$PROJECT_ROOT/output/build"
    rm -rf "$PROJECT_ROOT/output/firmware"
    rm -rf "$PROJECT_ROOT/output/package"
    rm -rf "$PROJECT_ROOT/output/sources"
    rm -rf "$PROJECT_ROOT/output/logs"
    
    log_success "All build artifacts cleaned"
}

# =============================================================================
# Show Build Summary
# =============================================================================

show_summary() {
    log_header "Build Summary"
    
    echo ""
    echo -e "${CYAN}Build completed!${NC}"
    echo ""
    
    # Check what was built
    local components_built=()
    
    if [ -f "$PROJECT_ROOT/output/toolchain/environment" ]; then
        components_built+=("Toolchain")
    fi
    
    if [ -f "$PROJECT_ROOT/output/firmware/zImage" ]; then
        components_built+=("Kernel")
    fi
    
    if [ -f "$PROJECT_ROOT/output/firmware/rootfs.img.gz" ]; then
        components_built+=("Root Filesystem")
    fi
    
    if [ -f "$PROJECT_ROOT/output/firmware/yaffs-tools-open.tar.gz" ] || \
       [ -d "$PROJECT_ROOT/output/firmware/yaffs-tools" ]; then
        components_built+=("YAFFS Tools")
    fi
    
    if [ -f "$PROJECT_ROOT/output/firmware/checksums.sha256" ]; then
        components_built+=("Verification")
    fi
    
    if [ -d "$PROJECT_ROOT/output/package" ]; then
        components_built+=("Package")
    fi
    
    echo "Components built:"
    for component in "${components_built[@]}"; do
        echo -e "  ${GREEN}✓${NC} $component"
    done
    echo ""
    
    # Show output locations
    if [ -d "$PROJECT_ROOT/output/package" ]; then
        echo "Package location: $PROJECT_ROOT/output/package/"
        echo ""
        echo "Files in package:"
        ls "$PROJECT_ROOT/output/package/" | sed 's/^/  /'
    fi
    
    if [ -f "$PROJECT_ROOT/output/karotz-open-firmware-*.tar.gz" ]; then
        local tarball=$(ls "$PROJECT_ROOT/output/karotz-open-firmware-*.tar.gz" | head -1)
        echo ""
        echo "Tarball: $tarball"
        echo "  Size: $(du -h "$tarball" | cut -f1)"
        echo "  SHA256: $(sha256sum "$tarball" | cut -d' ' -f1)"
    fi
    
    echo ""
    echo "Build log: $LOG_FILE"
    echo ""
    echo -e "${CYAN}To install on Karotz:${NC}"
    echo "  1. Format a USB key as FAT32"
    echo "  2. Copy all files from $PROJECT_ROOT/output/package/ to USB"
    echo "  3. Power off Karotz"
    echo "  4. Insert USB and hold the back button while powering on"
    echo "  5. Wait for installation to complete (green LED)"
    echo ""
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo "=========================================="
    echo "Karotz Open Firmware - Master Build Script"
    echo "=========================================="
    echo ""
    echo "Starting full firmware build process..."
    echo ""
    
    # Create output directories
    mkdir -p "$PROJECT_ROOT/output/build"
    mkdir -p "$PROJECT_ROOT/output/firmware"
    mkdir -p "$PROJECT_ROOT/output/package"
    mkdir -p "$PROJECT_ROOT/output/logs"
    mkdir -p "$PROJECT_ROOT/output/sources"
    
    # Initialize log file
    echo "Master Build Log - $(date)" > "$LOG_FILE"
    echo "==========================================" >> "$LOG_FILE"
    
    # Handle options
    case "${1:-}" in
        clean)
            clean_all
            exit 0
            ;;
        toolchain)
            build_toolchain
            exit 0
            ;;
        kernel)
            build_kernel
            exit 0
            ;;
        rootfs)
            build_rootfs
            exit 0
            ;;
        yaffs)
            build_yaffs
            exit 0
            ;;
        verify)
            verify_build
            exit 0
            ;;
        package)
            package_build
            exit 0
            ;;
        fast)
            # Skip toolchain
            export KAROTZ_SKIP_TOOLCHAIN=1
            build_kernel
            build_yaffs
            build_rootfs
            verify_build
            package_build
            show_summary
            exit 0
            ;;
    esac
    
    # Full build
    echo ""
    echo -e "${PURPLE}==========================================${NC}"
    echo -e "${PURPLE}  FULL FIRMWARE BUILD${NC}"
    echo -e "${PURPLE}==========================================${NC}"
    echo ""
    
    # Show estimated time
    echo -e "${YELLOW}Note: Full build may take 4-6 hours depending on hardware${NC}"
    echo -e "${YELLOW}  - Toolchain: 2-3 hours${NC}"
    echo -e "${YELLOW}  - Kernel: 30-60 minutes${NC}"
    echo -e "${YELLOW}  - YAFFS Tools: 5-10 minutes${NC}"
    echo -e "${YELLOW}  - RootFS: 45-90 minutes${NC}"
    echo -e "${YELLOW}  - Verification & Packaging: 5 minutes${NC}"
    echo ""
    
    # Run all build steps
    build_toolchain
    build_kernel
    build_yaffs
    build_rootfs
    verify_build
    package_build
    
    # Show summary
    show_summary
    
    echo ""
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}  BUILD COMPLETED SUCCESSFULLY!${NC}"
    echo -e "${GREEN}==========================================${NC}"
}

# Run main function
main "$@"
