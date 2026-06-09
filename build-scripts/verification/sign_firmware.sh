#!/bin/bash
# =============================================================================
# Karotz Open Firmware - Firmware Signing Script
# =============================================================================
# This script creates cryptographic signatures for firmware artifacts.
# It supports both simple SHA256 hashes and GPG signing for maximum security.
# 
# Usage: ./sign_firmware.sh [sha256|gpg|verify]
#   sha256: Create SHA256 signatures (default)
#   gpg: Create GPG signatures (requires GPG key)
#   verify: Verify existing signatures
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FIRMWARE_DIR="$PROJECT_ROOT/output/firmware"
SIGNATURE_DIR="$PROJECT_ROOT/output/signatures"
LOG_FILE="$PROJECT_ROOT/output/logs/signing_$(date +%Y%m%d_%H%M%S).log"

# Signing configuration
GPG_KEY_ID=""  # Set to your GPG key ID for production signing
SIGNING_KEY="karotz-open-firmware"  # Key identifier

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
# Create Directories
# =============================================================================

create_dirs() {
    mkdir -p "$FIRMWARE_DIR"
    mkdir -p "$SIGNATURE_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
}

# =============================================================================
# SHA256 Signing
# =============================================================================

sign_sha256() {
    log_header "Creating SHA256 Signatures"
    
    create_dirs
    
    local files_signed=0
    
    # Sign all firmware files
    for file in "$FIRMWARE_DIR"/*; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            local signature="$SIGNATURE_DIR/${filename}.sha256"
            
            # Create SHA256 hash
            sha256sum "$file" > "$signature"
            
            # Add metadata
            echo "# Signed by: $SIGNING_KEY" >> "$signature"
            echo "# Date: $(date)" >> "$signature"
            echo "# File: $filename" >> "$signature"
            echo "# Size: $(stat -c%s "$file") bytes" >> "$signature"
            
            ((files_signed++))
            log_info "Signed: $filename"
        fi
    done
    
    # Also sign checksum file if it exists
    if [ -f "$FIRMWARE_DIR/checksums.sha256" ]; then
        sha256sum "$FIRMWARE_DIR/checksums.sha256" > "$SIGNATURE_DIR/checksums.sha256.sha256"
        echo "# Master signature" >> "$SIGNATURE_DIR/checksums.sha256.sha256"
        echo "# Date: $(date)" >> "$SIGNATURE_DIR/checksums.sha256.sha256"
        ((files_signed++))
        log_info "Signed: checksums.sha256"
    fi
    
    log_success "Created SHA256 signatures for $files_signed files"
    log_success "Signatures saved to: $SIGNATURE_DIR/"
}

# =============================================================================
# GPG Signing
# =============================================================================

sign_gpg() {
    log_header "Creating GPG Signatures"
    
    create_dirs
    
    # Check if GPG is available
    if ! command -v gpg >/dev/null 2>&1; then
        log_error "GPG not found. Please install gpg: sudo apt-get install gnupg"
    fi
    
    # Check if key exists
    if [ -z "$GPG_KEY_ID" ]; then
        log_warning "No GPG_KEY_ID specified. Using default or first available key."
        GPG_KEY_ID=$(gpg --list-secret-keys 2>/dev/null | grep "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)
        if [ -z "$GPG_KEY_ID" ]; then
            log_error "No GPG secret key found. Please create one first."
        fi
    fi
    
    log_info "Using GPG key: $GPG_KEY_ID"
    
    local files_signed=0
    
    # Sign all firmware files
    for file in "$FIRMWARE_DIR"/*; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            local signature="$SIGNATURE_DIR/${filename}.sig"
            local ascii_signature="$SIGNATURE_DIR/${filename}.asc"
            
            # Create detached signature
            gpg --batch --yes --detach-sign --armor --output "$signature" "$file" 2>&1 | tee -a "$LOG_FILE" || \
                log_error "Failed to sign $filename"
            
            # Create ASCII-armored signature
            gpg --batch --yes --clearsign --output "$ascii_signature" "$file" 2>&1 | tee -a "$LOG_FILE" || \
                log_warning "Failed to create ASCII signature for $filename"
            
            ((files_signed++))
            log_info "Signed: $filename"
        fi
    done
    
    # Sign checksum file
    if [ -f "$FIRMWARE_DIR/checksums.sha256" ]; then
        gpg --batch --yes --detach-sign --armor --output "$SIGNATURE_DIR/checksums.sha256.sig" \
            "$FIRMWARE_DIR/checksums.sha256" 2>&1 | tee -a "$LOG_FILE" || true
        gpg --batch --yes --clearsign --output "$SIGNATURE_DIR/checksums.sha256.asc" \
            "$FIRMWARE_DIR/checksums.sha256" 2>&1 | tee -a "$LOG_FILE" || true
        ((files_signed++))
        log_info "Signed: checksums.sha256"
    fi
    
    log_success "Created GPG signatures for $files_signed files"
    log_success "Signatures saved to: $SIGNATURE_DIR/"
}

# =============================================================================
# Verify Signatures
# =============================================================================

verify_signatures() {
    log_header "Verifying Firmware Signatures"
    
    create_dirs
    
    local total=0
    local passed=0
    local failed=0
    
    # Verify SHA256 signatures
    log_info "Verifying SHA256 signatures..."
    for sig in "$SIGNATURE_DIR"/*.sha256; do
        if [ -f "$sig" ]; then
            ((total++))
            local filename=$(basename "$sig" .sha256)
            local filepath="$FIRMWARE_DIR/$filename"
            
            if [ ! -f "$filepath" ]; then
                log_warning "File missing: $filename"
                ((failed++))
                continue
            fi
            
            # Extract hash from signature (first line only)
            local expected_hash=$(head -1 "$sig" | cut -d' ' -f1)
            local actual_hash=$(sha256sum "$filepath" | cut -d' ' -f1)
            
            if [ "$expected_hash" = "$actual_hash" ]; then
                log_info "OK: $filename"
                ((passed++))
            else
                log_error "FAILED: $filename"
                log_error "  Expected: $expected_hash"
                log_error "  Actual:   $actual_hash"
                ((failed++))
            fi
        fi
    done
    
    # Verify GPG signatures if available
    if command -v gpg >/dev/null 2>&1; then
        log_info "Verifying GPG signatures..."
        for sig in "$SIGNATURE_DIR"/*.sig; do
            if [ -f "$sig" ]; then
                ((total++))
                local filename=$(basename "$sig" .sig)
                local filepath="$FIRMWARE_DIR/$filename"
                
                if [ ! -f "$filepath" ]; then
                    log_warning "File missing: $filename"
                    ((failed++))
                    continue
                fi
                
                if gpg --batch --verify "$sig" "$filepath" 2>&1 | grep -q "Good signature"; then
                    log_info "GPG OK: $filename"
                    ((passed++))
                else
                    log_warning "GPG WARNING: $filename (signature issue)"
                    ((failed++))
                fi
            fi
        done
    fi
    
    # Summary
    echo ""
    echo "=========================================="
    echo "Verification Summary"
    echo "=========================================="
    echo "Total checked: $total"
    echo -e "${GREEN}Passed:       $passed${NC}"
    echo -e "${RED}Failed:       $failed${NC}"
    echo ""
    
    if [ $failed -gt 0 ]; then
        log_error "Verification FAILED: $failed signatures invalid"
    else
        log_success "Verification PASSED: All $passed signatures are valid"
    fi
}

# =============================================================================
# Export Public Key
# =============================================================================

export_public_key() {
    log_header "Exporting Public Key"
    
    if ! command -v gpg >/dev/null 2>&1; then
        log_error "GPG not found"
    fi
    
    if [ -z "$GPG_KEY_ID" ]; then
        GPG_KEY_ID=$(gpg --list-secret-keys 2>/dev/null | grep "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)
    fi
    
    if [ -z "$GPG_KEY_ID" ]; then
        log_error "No GPG key found"
    fi
    
    local pubkey_file="$SIGNATURE_DIR/public_key.asc"
    
    gpg --batch --yes --armor --export "$GPG_KEY_ID" > "$pubkey_file" 2>&1 | tee -a "$LOG_FILE" || \
        log_error "Failed to export public key"
    
    log_success "Public key exported to: $pubkey_file"
    log_info "Share this file with users to verify firmware signatures"
}

# =============================================================================
# Main Execution
# =============================================================================

log_header() {
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
}

main() {
    echo "=========================================="
    echo "Karotz Open Firmware - Signing Script"
    echo "=========================================="
    echo ""
    
    create_dirs
    
    # Initialize log file
    echo "Signing Log - $(date)" > "$LOG_FILE"
    echo "==========================================" >> "$LOG_FILE"
    
    # Handle options
    case "${1:-}" in
        gpg)
            sign_gpg
            ;;
        verify)
            verify_signatures
            ;;
        export-key)
            export_public_key
            ;;
        *)
            # Default: SHA256 signing
            sign_sha256
            verify_signatures
            ;;
    esac
    
    echo ""
    echo "=========================================="
    echo "Signing process completed"
    echo "=========================================="
    echo ""
    echo "Signatures location: $SIGNATURE_DIR/"
    echo "Build log: $LOG_FILE"
}

# Run main function
main "$@"
