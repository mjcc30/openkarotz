#!/bin/bash
# Vérifie que tous les artefacts nécessaires existent

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIRMWARE_DIR="$PROJECT_ROOT/output/firmware"
PACKAGE_DIR="$PROJECT_ROOT/output/package"

echo "🔍 Vérification des artefacts..."

required_files=(
    "$FIRMWARE_DIR/zImage"
    "$FIRMWARE_DIR/rootfs.img.gz"
    "$FIRMWARE_DIR/checksums.sha256"
    "$FIRMWARE_DIR/yaffs-tools-open.tar.gz"
    "$PACKAGE_DIR/zImage"
    "$PACKAGE_DIR/rootfs.img.gz"
    "$PACKAGE_DIR/yaffs-tools.tar.gz"
    "$PACKAGE_DIR/checksums.sha256"
    "$PACKAGE_DIR/autorun"
    "$PACKAGE_DIR/installfirmware.sh"
    "$PACKAGE_DIR/functions.sh"
    "$PACKAGE_DIR/waitfornetwork.sh"
    "$PACKAGE_DIR/VERSION"
)

missing=()
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        missing+=("$file")
    fi
done

if [ ${#missing[@]} -gt 0 ]; then
    echo "❌ ERREUR: Fichiers manquants:"
    for file in "${missing[@]}"; do
        echo "   - $file"
    done
    exit 1
fi

if [ $(stat -c%s "$FIRMWARE_DIR/zImage" 2>/dev/null || echo 0) -lt 1000000 ]; then
    echo "❌ ERREUR: zImage trop petit"
    exit 1
fi

if [ $(stat -c%s "$FIRMWARE_DIR/rootfs.img.gz" 2>/dev/null || echo 0) -lt 1000000 ]; then
    echo "❌ ERREUR: rootfs.img.gz trop petit"
    exit 1
fi

echo "✅ Tous les artefacts sont présents et valides"
