#!/bin/bash
# Vérifie la structure du package final

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$PROJECT_ROOT/output/package"

echo "🔍 Vérification de la structure du package..."

if [ ! -d "$PACKAGE_DIR" ]; then
    echo "❌ ERREUR: Dossier package introuvable"
    exit 1
fi

essential_files=(
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

for file in "${essential_files[@]}"; do
    if [ ! -f "$PACKAGE_DIR/$file" ]; then
        echo "❌ ERREUR: Fichier manquant dans package: $file"
        exit 1
    fi
done

if [ ! -d "$PACKAGE_DIR/installpage" ]; then
    echo "❌ ERREUR: Dossier installpage manquant"
    exit 1
fi

if [ ! -d "$PACKAGE_DIR/sound" ]; then
    echo "❌ ERREUR: Dossier sound manquant"
    exit 1
fi

mp3_count=$(find "$PACKAGE_DIR/sound" -name "*.mp3" 2>/dev/null | wc -l || echo 0)
if [ "$mp3_count" -lt 10 ]; then
    echo "❌ ERREUR: Trop peu de fichiers MP3 ($mp3_count < 10)"
    exit 1
fi

echo "✅ Structure du package valide"
