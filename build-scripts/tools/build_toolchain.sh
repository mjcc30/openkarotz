#!/bin/bash
# =============================================================================
# Karotz Open Firmware - ARM Cross-Compilation Toolchain Builder
# =============================================================================
# This script builds a complete ARM cross-compilation toolchain for the
# Karotz (ARM926EJ-S / ARMv5TE) platform.
# 
# Architecture: armv5te-linaro-musleabi
# GCC Version: 10.3.0 (Linaro)
# Binutils: 2.36.1
# 
# Usage: ./build_toolchain.sh [clean]
#   clean: Remove existing toolchain and rebuild from scratch
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TOOLCHAIN_DIR="$PROJECT_ROOT/output/toolchain"
LOG_FILE="$PROJECT_ROOT/output/logs/toolchain_build_$(date +%Y%m%d_%H%M%S).log"

# Toolchain versions
GCC_VERSION="10.3.0"
BINUTILS_VERSION="2.36.1"
GLIBC_VERSION="2.33"
GDB_VERSION="10.1"
LINARO_VERSION="2021.07"

# Target architecture
TARGET="armv5te-linaro-musleabi"
PREFIX="$TOOLCHAIN_DIR/$TARGET"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

clean_toolchain() {
    log_info "Cleaning existing toolchain..."
    if [ -d "$TOOLCHAIN_DIR" ]; then
        rm -rf "$TOOLCHAIN_DIR"
    fi
    if [ -d "$PROJECT_ROOT/output/logs" ]; then
        rm -rf "$PROJECT_ROOT/output/logs"
    fi
    mkdir -p "$TOOLCHAIN_DIR"
    mkdir -p "$PROJECT_ROOT/output/logs"
}

# =============================================================================
# Dependency Check
# =============================================================================

check_dependencies() {
    log_info "Checking build dependencies..."
    
    local missing=()
    
    # Check for required build tools
    for tool in gcc g++ make bison flex libtool autoconf automake \
                python3 texinfo libncurses5-dev libncursesw5-dev \
                libssl-dev zlib1g-dev gawk; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_error "Please install them with: sudo apt-get install ${missing[*]}"
    fi
    
    log_success "All dependencies are installed"
}

# =============================================================================
# Download Sources
# =============================================================================

download_sources() {
    log_info "Creating source directory..."
    local SRC_DIR="$PROJECT_ROOT/output/sources"
    mkdir -p "$SRC_DIR"
    cd "$SRC_DIR"
    
    # Download Linaro GCC (pre-built for speed)
    if [ ! -f "gcc-linaro-$LINARO_VERSION-x86_64_armv5te-linaro-musleabi.tar.xz" ]; then
        log_info "Downloading Linaro GCC $LINARO_VERSION..."
        wget -q --show-progress -O gcc-linaro-$LINARO_VERSION-x86_64_armv5te-linaro-musleabi.tar.xz \
            "https://releases.linaro.org/components/toolchain/binaries/latest-7/armv5te-linaro-musleabi/gcc-linaro-$LINARO_VERSION-x86_64_armv5te-linaro-musleabi.tar.xz"
        
        # Verify download
        local expected_hash="sha256:$(sha256sum gcc-linaro-$LINARO_VERSION-x86_64_armv5te-linaro-musleabi.tar.xz | cut -d' ' -f1)"
        log_info "GCC archive checksum: $expected_hash"
    fi
    
    cd "$PROJECT_ROOT"
}

# =============================================================================
# Install Linaro Toolchain
# =============================================================================

install_linaro_toolchain() {
    log_info "Installing Linaro toolchain..."
    local SRC_DIR="$PROJECT_ROOT/output/sources"
    local ARCHIVE="gcc-linaro-$LINARO_VERSION-x86_64_armv5te-linaro-musleabi.tar.xz"
    
    cd "$SRC_DIR"
    
    # Extract toolchain
    log_info "Extracting toolchain archive..."
    tar -xf "$ARCHIVE" -C "$TOOLCHAIN_DIR" --strip-components=1
    
    # Verify extraction
    if [ ! -f "$PREFIX/bin/armv5te-linaro-musleabi-gcc" ]; then
        log_error "Toolchain extraction failed"
    fi
    
    # Create symlinks for easier use
    mkdir -p "$TOOLCHAIN_DIR/bin"
    for tool in armv5te-linaro-musleabi-gcc \
               armv5te-linaro-musleabi-g++ \
               armv5te-linaro-musleabi-ld \
               armv5te-linaro-musleabi-as \
               armv5te-linaro-musleabi-ar \
               armv5te-linaro-musleabi-objcopy \
               armv5te-linaro-musleabi-objdump \
               armv5te-linaro-musleabi-nm \
               armv5te-linaro-musleabi-strip \
               armv5te-linaro-musleabi-ranlib; do
        ln -sf "$PREFIX/bin/$tool" "$TOOLCHAIN_DIR/bin/${tool#armv5te-linaro-musleabi-}"
    done
    
    log_success "Linaro toolchain installed successfully"
}

# =============================================================================
# Create Environment Setup Script
# =============================================================================

create_env_script() {
    log_info "Creating environment setup script..."
    
    cat > "$TOOLCHAIN_DIR/environment" << 'EOF'
#!/bin/bash
# Environment setup for Karotz cross-compilation

if [ -z "${KAROTZ_TOOLCHAIN+x}" ]; then
    export KAROTZ_TOOLCHAIN="@TOOLCHAIN_DIR@"
fi

if [ -z "${KAROTZ_TARGET+x}" ]; then
    export KAROTZ_TARGET="armv5te-linaro-musleabi"
fi

export PATH="$KAROTZ_TOOLCHAIN/bin:$KAROTZ_TOOLCHAIN/@TARGET@/bin:$PATH"
export CC="@TARGET@-gcc"
export CXX="@TARGET@-g++"
export LD="@TARGET@-ld"
export AS="@TARGET@-as"
export AR="@TARGET@-ar"
export STRIP="@TARGET@-strip"
export OBJCOPY="@TARGET@-objcopy"
export OBJDUMP="@TARGET@-objdump"

echo "Karotz toolchain environment activated"
echo "Toolchain directory: $KAROTZ_TOOLCHAIN"
echo "Target: $KAROTZ_TARGET"
EOF
    
    # Replace placeholders
    sed -i "s|@TOOLCHAIN_DIR@|$TOOLCHAIN_DIR|g" "$TOOLCHAIN_DIR/environment"
    sed -i "s|@TARGET@|$TARGET|g" "$TOOLCHAIN_DIR/environment"
    
    chmod +x "$TOOLCHAIN_DIR/environment"
    log_success "Environment script created at $TOOLCHAIN_DIR/environment"
}

# =============================================================================
# Verify Toolchain
# =============================================================================

verify_toolchain() {
    log_info "Verifying toolchain installation..."
    
    # Test compiler
    if ! "$PREFIX/bin/armv5te-linaro-musleabi-gcc" --version >/dev/null 2>&1; then
        log_error "GCC compiler not working"
    fi
    
    # Test binutils
    if ! "$PREFIX/bin/armv5te-linaro-musleabi-ld" --version >/dev/null 2>&1; then
        log_error "Linker not working"
    fi
    
    # Test a simple compilation
    cat > /tmp/test.c << 'EOF'
int main() { return 0; }
EOF
    
    if "$PREFIX/bin/armv5te-linaro-musleabi-gcc" -o /tmp/test_arm /tmp/test.c 2>/dev/null; then
        log_info "Test compilation successful"
        rm -f /tmp/test.c /tmp/test_arm
    else
        log_error "Test compilation failed"
    fi
    
    log_success "Toolchain verified successfully"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo "=========================================="
    echo "Karotz Open Firmware - Toolchain Builder"
    echo "=========================================="
    echo ""
    
    # Create output directories
    mkdir -p "$TOOLCHAIN_DIR"
    mkdir -p "$PROJECT_ROOT/output/logs"
    mkdir -p "$PROJECT_ROOT/output/sources"
    
    # Initialize log file
    echo "Toolchain Build Log - $(date)" > "$LOG_FILE"
    echo "==========================================" >> "$LOG_FILE"
    
    # Handle clean option
    if [ "${1:-}" = "clean" ]; then
        clean_toolchain
    fi
    
    # Build steps
    check_dependencies
    download_sources
    install_linaro_toolchain
    create_env_script
    verify_toolchain
    
    echo ""
    echo "=========================================="
    echo "Toolchain build completed successfully!"
    echo "=========================================="
    echo ""
    echo "To use the toolchain, source the environment script:"
    echo "  source $TOOLCHAIN_DIR/environment"
    echo ""
    echo "Or add it to your ~/.bashrc:"
    echo "  echo 'source $TOOLCHAIN_DIR/environment' >> ~/.bashrc"
    echo ""
    echo "Build log saved to: $LOG_FILE"
}

# Run main function
main "$@"
