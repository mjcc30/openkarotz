#!/bin/bash
# Vérifie l'intégrité des checksums

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKSUM_FILE="$PROJECT_ROOT/output/firmware/checksums.sha256"

echo "🔍 Vérification des checksums..."

if [ ! -f "$CHECKSUM_FILE" ]; then
    echo "❌ ERREUR: Fichier checksums.sha256 introuvable"
    exit 1
fi

errors=0
while IFS='|' read -r filename expected_sha256 expected_md5 _; do
    [[ "$filename" =~ ^# ]] && continue
    [[ -z "$filename" ]] && continue

    filepath="$PROJECT_ROOT/output/firmware/$filename"

    if [ ! -f "$filepath" ]; then
        echo "❌ Fichier manquant: $filename"
        errors=$((errors + 1))
        continue
    fi

    actual_sha256=$(sha256sum "$filepath" | cut -d' ' -f1)
    actual_md5=$(md5sum "$filepath" | cut -d' ' -f1)

    if [ "$actual_sha256" != "$expected_sha256" ]; then
        echo "❌ SHA256 invalide: $filename"
        echo "   Attendu: $expected_sha256"
        echo "   Actuel:  $actual_sha256"
        errors=$((errors + 1))
    fi

    if [ "$actual_md5" != "$expected_md5" ]; then
        echo "❌ MD5 invalide: $filename"
        errors=$((errors + 1))
    fi
done < "$CHECKSUM_FILE"

if [ $errors -gt 0 ]; then
    echo "❌ $errors erreurs de checksum trouvées"
    exit 1
fi

echo "✅ Tous les checksums sont valides"
