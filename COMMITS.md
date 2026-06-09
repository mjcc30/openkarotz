# 🚀 Première Utilisation & Commandes Git

## Initialisation du dépôt GitHub

### 1. Créer un nouveau dépôt sur GitHub

```bash
# Sur GitHub.com, créez un nouveau dépôt:
# Nom: openkarotz
# Description: Open-source firmware for Karotz robot
# Public/Private: Public (recommandé pour le CI/CD gratuit)
# Ajoutez un README.md (optionnel)
# Ajoutez .gitignore (optionnel)
```

### 2. Initialiser Git localement (si ce n'est pas déjà fait)

```bash
# Dans le dossier openkarotz
cd openkarotz

# Initialiser git
git init

# Ajouter tous les fichiers
git add .

# Commiter
git commit -m "Initial commit: Open-source Karotz firmware build system"

# Ajouter le remote GitHub
git remote add origin https://github.com/VOTRE_UTILISATEUR/openkarotz.git

# Pousser sur GitHub
git push -u origin main
```

---

## 📝 Commandes Git de base

### Pousser les changements
```bash
git add .
git commit -m "votre message de commit"
git push
```

### Créer une nouvelle branche
```bash
git checkout -b feature/nouvelle-fonctionnalite
git add .
git commit -m "feat: ajoute nouvelle fonctionnalite"
git push origin feature/nouvelle-fonctionnalite
```

### Fusionner une PR
```bash
git checkout main
git pull origin main
git merge feature/nouvelle-fonctionnalite
git push origin main
```

---

## 🏷️ Créer une Release

### Méthode 1: Via GitHub Actions (recommandé)

1. Poussez un tag versionné:
```bash
# Créer un tag annoté
git tag -a v1.0.0 -m "Release v1.0.0: Première version stable"

# Pousser le tag
git push origin v1.0.0
```

Le workflow GitHub Actions créera automatiquement:
- ✅ Une release sur GitHub
- ✅ Avec tous les artefacts (firmware, package, checksums)
- ✅ Des notes de release générées automatiquement

### Méthode 2: Manuellement sur GitHub

1. Allez dans **Releases** → **Draft a new release**
2. Tag version: `v1.0.0`
3. Release title: `v1.0.0 - Première version stable`
4. Description: Copiez la sortie de `scripts/generate-release-notes.sh`
5. Attachez les fichiers depuis `output/package/`
6. Publiez la release

---

## 🔧 Configuration GitHub Actions

### Activer les workflows

Les workflows sont déjà configurés dans `.github/workflows/`:

1. **`build.yml`** - Build complet + Tests + Release automatique
   - ⚡ Déclenché sur: push (main, develop), tags (v*), workflow_dispatch
   - ⏱️  Temps max: 6 heures
   - 💾 Cache: toolchain, sources, ccache

2. **`verify.yml`** - Vérification rapide pour les PR
   - ⚡ Déclenché sur: pull_request, push (develop)
   - ⏱️  Temps max: 30 minutes
   - 🔍 Vérifie: syntaxe shell, structure, ShellCheck

### Vérifier que tout fonctionne

1. Poussez un petit changement:
```bash
echo "# Test" > TEST.md
git add TEST.md
git commit -m "test: vérification CI"
git push
```

2. Allez dans l'onglet **Actions** sur GitHub
3. Vérifiez que le workflow **Quick Verification** s'exécute
4. Attendez la fin (✅ vert = succès)

### Déclencher manuellement un build

1. Allez dans **Actions** → **Karotz Open Firmware CI/CD**
2. Cliquez sur **Run workflow** (bouton à droite)
3. Sélectionnez la branche (main)
4. Cliquez sur **Run workflow**

---

## 📊 Suivre les builds

### Voir l'historique
- **Actions** → Liste tous les workflows exécutés
- Cliquez sur un workflow pour voir les détails
- **Artifacts** → Téléchargez les artefacts générés

### Voir les artefacts
1. Allez dans **Actions**
2. Sélectionnez un workflow terminé
3. Défilez vers le bas
4. Dans **Artifacts**, cliquez sur le lien pour télécharger

### Voir les releases
- **Releases** → Liste toutes les versions publiées
- Chaque release contient les fichiers du firmware

---

## 🛠️ Dépannage

### Problème: Workflow échoue avec "permission denied"

**Solution:**
```bash
# Donner les permissions d'exécution
git update-index --chmod=+x build-scripts/*.sh
git update-index --chmod=+x build-scripts/**/*.sh
git update-index --chmod=+x tests/*.sh
git update-index --chmod=+x scripts/*.sh
```

### Problème: Cache ne fonctionne pas

**Solution:** Vérifiez que les chemins dans le workflow sont corrects:
```yaml
paths: |
  ${{ env.BUILD_DIR }}/toolchain
  ${{ env.BUILD_DIR }}/sources
```

### Problème: Build trop long (>6h)

**Solution:**
- Utilisez un runner plus puissant (ubuntu-latest a 2 CPU, 7GB RAM)
- Réduisez la taille du cache
- Build en plusieurs étapes

### Problème: Pas assez d'espace disque

**Solution:** Ajoutez une étape de nettoyage:
```yaml
- name: Cleanup
  run: |
    rm -rf output/sources/*
    rm -rf output/build/*
```

---

## 🎯 Bonnes pratiques

### 1. Messages de commit clairs

```bash
# ❌ Mauvaise pratique
git commit -m "fix"
git commit -m "changements"

# ✅ Bonne pratique
git commit -m "fix: correction du checksum dans verify_checksums.sh"
git commit -m "feat: ajout du support WiFi RTL8188EU"
git commit -m "docs: mise à jour de l'architecture matérielle"
git commit -m "chore: nettoyage des fichiers temporaires"
```

### 2. Branches bien nommées

```bash
# ❌ Mauvaise pratique
git checkout -b test
git checkout -b fix

# ✅ Bonne pratique
git checkout -b feature/ajout-gpg-signing
git checkout -b fix/verification-checksums
git checkout -b docs/mise-a-jour-readme
git checkout -b chore/cleanup-build-scripts
```

### 3. Tags sémantiques

Utilisez [Semantic Versioning](https://semver.org/):

```bash
# vMAJOR.MINOR.PATCH
# MAJOR: changements incompatibles
# MINOR: nouvelles fonctionnalités (rétro-compatibles)
# PATCH: corrections de bugs (rétro-compatibles)

git tag -a v1.0.0 -m "Release v1.0.0: Première version stable"
git tag -a v1.1.0 -m "Release v1.1.0: Ajout du support GPG"
git tag -a v1.1.1 -m "Release v1.1.1: Correction bug checksums"
```

---

## 📚 Ressources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)

---

## 💬 Support

Si vous avez des questions ou des problèmes:

1. Vérifiez les **logs des workflows** dans l'onglet Actions
2. Consultez la [documentation GitHub Actions](https://docs.github.com/en/actions)
3. Ouvrez une **Issue** dans ce dépôt

---

**Bon développement !** 🎉
