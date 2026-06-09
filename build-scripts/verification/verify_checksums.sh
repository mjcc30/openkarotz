#!/bin/bash
# =============================================================================
# Karotz Open Firmware - Verification Framework
# =============================================================================
# This script verifies the integrity of all firmware components using SHA256
# checksums. It ensures that:
# 1. All components are present
# 2. All checksums match expected values
# 3. No files have been tampered with
# 
# Usage: ./verify_checksums.sh [check|generate|verify-only]
#   check: Verify existing checksums (default)
#   generate: Generate new checksums for all files
#   verify-only: Only verify, don't generate
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FIRMWARE_DIR="$PROJECT_ROOT/output/firmware"
CHECKSUM_FILE="$FIRMWARE_DIR/checksums.sha256"
LOG_FILE="$PROJECT_ROOT/output/logs/verification_$(date +%Y%m%d_%H%M%S).log"

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
# Generate Checksums
# =============================================================================

generate_checksums() {
    log_info "Generating SHA256 checksums for all firmware components..."
    
    local checksums=""
    local files_found=0
    
    # Create output directory if it doesn't exist
    mkdir -p "$FIRMWARE_DIR"
    
    # Check for kernel
    if [ -f "$FIRMWARE_DIR/zImage" ]; then
        local sha256=$(sha256sum "$FIRMWARE_DIR/zImage" | cut -d' ' -f1)
        local md5=$(md5sum "$FIRMWARE_DIR/zImage" | cut -d' ' -f1)
        local size=$(stat -c%s "$FIRMWARE_DIR/zImage")
        checksums+="zImage|$sha256|$md5|$size\n"
        ((files_found++))
        log_info "  zImage: SHA256=$sha256, MD5=$md5, Size=$size bytes"
    else
        log_warning "  zImage not found"
    fi
    
    # Check for rootfs
    if [ -f "$FIRMWARE_DIR/rootfs.img.gz" ]; then
        local sha256=$(sha256sum "$FIRMWARE_DIR/rootfs.img.gz" | cut -d' ' -f1)
        local md5=$(md5sum "$FIRMWARE_DIR/rootfs.img.gz" | cut -d' ' -f1)
        local size=$(stat -c%s "$FIRMWARE_DIR/rootfs.img.gz")
        checksums+="rootfs.img.gz|$sha256|$md5|$size\n"
        ((files_found++))
        log_info "  rootfs.img.gz: SHA256=$sha256, MD5=$md5, Size=$size bytes"
    else
        log_warning "  rootfs.img.gz not found"
    fi
    
    # Check for YAFFS tools
    if [ -f "$FIRMWARE_DIR/yaffs-tools/yaffs-tools-open.tar.gz" ]; then
        local sha256=$(sha256sum "$FIRMWARE_DIR/yaffs-tools/yaffs-tools-open.tar.gz" | cut -d' ' -f1)
        local md5=$(md5sum "$FIRMWARE_DIR/yaffs-tools/yaffs-tools-open.tar.gz" | cut -d' ' -f1)
        local size=$(stat -c%s "$FIRMWARE_DIR/yaffs-tools/yaffs-tools-open.tar.gz")
        checksums+="yaffs-tools/yaffs-tools-open.tar.gz|$sha256|$md5|$size\n"
        ((files_found++))
        log_info "  yaffs-tools: SHA256=$sha256, MD5=$md5, Size=$size bytes"
    elif [ -d "$FIRMWARE_DIR/yaffs-tools" ]; then
        # Check individual tools
        for tool in "$FIRMWARE_DIR/yaffs-tools/"*; do
            if [ -f "$tool" ]; then
                local sha256=$(sha256sum "$tool" | cut -d' ' -f1)
                local md5=$(md5sum "$tool" | cut -d' ' -f1)
                local size=$(stat -c%s "$tool")
                local relpath="yaffs-tools/$(basename "$tool")"
                checksums+="$relpath|$sha256|$md5|$size\n"
                ((files_found++))
                log_info "  $relpath: SHA256=$sha256, MD5=$md5, Size=$size bytes"
            fi
        done
    else
        log_warning "  yaffs-tools not found"
    fi
    
    # Check for original files (if they exist)
    for file in autorun installfirmware.sh functions.sh waitfornetwork.sh; do
        if [ -f "$PROJECT_ROOT/$file" ]; then
            local sha256=$(sha256sum "$PROJECT_ROOT/$file" | cut -d' ' -f1)
            local md5=$(md5sum "$PROJECT_ROOT/$file" | cut -d' ' -f1)
            local size=$(stat -c%s "$PROJECT_ROOT/$file")
            checksums+="$file|$sha256|$md5|$size\n"
            ((files_found++))
            log_info "  $file: SHA256=$sha256, MD5=$md5, Size=$size bytes"
        fi
    done
    
    # Check sound files
    if [ -d "$PROJECT_ROOT/sound" ]; then
        for mp3 in "$PROJECT_ROOT/sound"/*.mp3; do
            if [ -f "$mp3" ]; then
                local sha256=$(sha256sum "$mp3" | cut -d' ' -f1)
                local md5=$(md5sum "$mp3" | cut -d' ' -f1)
                local size=$(stat -c%s "$mp3")
                local relpath="sound/$(basename "$mp3")"
                checksums+="$relpath|$sha256|$md5|$size\n"
                ((files_found++))
            fi
        done
    fi
    
    # Save checksums
    echo -e "# Firmware Checksums - Generated $(date)" > "$CHECKSUM_FILE"
    echo -e "# Format: filename|sha256|md5|size\n" >> "$CHECKSUM_FILE"
    echo -e "$checksums" >> "$CHECKSUM_FILE"
    
    log_success "Generated checksums for $files_found files"
    log_success "Checksum file saved to: $CHECKSUM_FILE"
}

# =============================================================================
# Verify Checksums
# =============================================================================

verify_checksums() {
    log_info "Verifying firmware checksums..."
    
    if [ ! -f "$CHECKSUM_FILE" ]; then
        log_error "Checksum file not found: $CHECKSUM_FILE"
        log_error "Please generate checksums first with: ./verify_checksums.sh generate"
    fi
    
    local total=0
    local passed=0
    local failed=0
    local missing=0
    
    # Read checksum file
    while IFS='|' read -r filename expected_sha256 expected_md5 expected_size; do
        # Skip comments and empty lines
        [[ "$filename" =~ ^#.*$ ]] && continue
        [[ -z "$filename" ]] && continue
        
        ((total++))
        local filepath="$FIRMWARE_DIR/$filename"
        
        # Check if file exists
        if [ ! -f "$filepath" ]; then
            log_warning "MISSING: $filename"
            ((missing++))
            continue
        fi
        
        # Calculate actual checksums
        local actual_sha256=$(sha256sum "$filepath" | cut -d' ' -f1)
        local actual_md5=$(md5sum "$filepath" | cut -d' ' -f1)
        local actual_size=$(stat -c%s "$filepath")
        
        # Compare
        if [ "$actual_sha256" != "$expected_sha256" ]; then
            log_error "FAILED: $filename"
            log_error "  Expected SHA256: $expected_sha256"
            log_error "  Actual SHA256:   $actual_sha256"
            ((failed++))
        elif [ "$actual_md5" != "$expected_md5" ]; then
            log_error "FAILED: $filename (MD5 mismatch)"
            log_error "  Expected MD5: $expected_md5"
            log_error "  Actual MD5:   $actual_md5"
            ((failed++))
        elif [ "$actual_size" != "$expected_size" ]; then
            log_warning "WARNING: $filename (size mismatch)"
            log_warning "  Expected size: $expected_size"
            log_warning "  Actual size:   $actual_size"
            ((passed++))
        else
            log_info "OK: $filename"
            ((passed++))
        fi
        
    done < "$CHECKSUM_FILE"
    
    # Summary
    echo ""
    echo "=========================================="
    echo "Verification Summary"
    echo "=========================================="
    echo "Total files:  $total"
    echo -e "${GREEN}Passed:       $passed${NC}"
    echo -e "${RED}Failed:       $failed${NC}"
    echo -e "${YELLOW}Missing:      $missing${NC}"
    echo ""
    
    if [ $failed -gt 0 ] || [ $missing -gt 0 ]; then
        log_error "Verification FAILED: $failed failed, $missing missing"
    else
        log_success "Verification PASSED: All $passed files are valid"
    fi
}

# =============================================================================
# Verify Only (without generation)
# =============================================================================

verify_only() {
    verify_checksums
}

# =============================================================================
# Sign Firmware (optional)
# =============================================================================

sign_firmware() {
    log_info "Signing firmware (optional)..."
    
    if [ ! -f "$CHECKSUM_FILE" ]; then
        log_error "Checksum file not found. Generate checksums first."
    fi
    
    # Create signature using SHA256 of checksum file
    local signature=$(sha256sum "$CHECKSUM_FILE" | cut -d' ' -f1)
    echo "$signature" > "$FIRMWARE_DIR/checksums.sha256.sig"
    
    log_success "Firmware signed with SHA256: $signature"
    log_success "Signature saved to: $FIRMWARE_DIR/checksums.sha256.sig"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo "=========================================="
    echo "Karotz Open Firmware - Verification Framework"
    echo "=========================================="
    echo ""
    
    # Create directories
    mkdir -p "$FIRMWARE_DIR"
    mkdir -p "$PROJECT_ROOT/output/logs"
    
    # Initialize log file
    echo "Verification Log - $(date)" > "$LOG_FILE"
    echo "==========================================" >> "$LOG_FILE"
    
    # Handle options
    case "${1:-}" in
        generate)
            generate_checksums
            ;;
        verify-only|verify)
            verify_only
            ;;
        sign)
            sign_firmware
            ;;
        *)
            # Default: verify if checksums exist, else generate
            if [ -f "$CHECKSUM_FILE" ]; then
                log_info "Checksum file found. Verifying..."
                verify_checksums
            else
                log_info "No checksum file found. Generating..."
                generate_checksums
                log_info "Verifying generated checksums..."
                verify_checksums
            fi
            ;;
    esac
    
    echo ""
    echo "=========================================="
    echo "Verification process completed"
    echo "=========================================="
    echo ""
    echo "Build log saved to: $LOG_FILE"
}

# Run main function
main "$@"
