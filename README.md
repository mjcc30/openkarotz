# OpenKarotz - Firmware Open Source pour Karotz

[![CI/CD](https://github.com/votre-utilisateur/openkarotz/actions/workflows/build.yml/badge.svg)](https://github.com/votre-utilisateur/openkarotz/actions/workflows/build.yml)
[![Verification](https://github.com/votre-utilisateur/openkarotz/actions/workflows/verify.yml/badge.svg)](https://github.com/votre-utilisateur/openkarotz/actions/workflows/verify.yml)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](https://opensource.org/licenses/GPL-3.0)
[![Release](https://img.shields.io/github/v/release/votre-utilisateur/openkarotz)](https://github.com/votre-utilisateur/openkarotz/releases)

---

## 🎯 **Objectif**

Ce projet fournit un **système de build complet** pour créer une firmware **100% open-source** pour le robot Karotz, remplaçant les composants binaires pré-compilés de la distribution miniil originale.

---

## 🏗️ **Architecture**

### Structure du projet
```
openkarotz/
├── .github/
│   └── workflows/
│       ├── build.yml          # CI/CD complet (Build + Tests + Release)
│       └── verify.yml         # Vérification rapide pour les PR
│
├── build-scripts/            # Scripts de build
│   ├── build_all.sh          # Orchestrateur principal
│   ├── kernel/
│   │   └── build_kernel.sh   # Build du noyau Linux
│   ├── rootfs/
│   │   └── build_rootfs.sh   # Build du root filesystem
│   ├── tools/
│   │   ├── build_toolchain.sh # Toolchain ARM
│   │   └── build_yaffs.sh     # Outils YAFFS
│   ├── verification/
│   │   ├── verify_checksums.sh # Vérification SHA256
│   │   └── sign_firmware.sh    # Signature GPG
│   └── package_firmware.sh   # Packaging final
│
├── tests/                    # Tests de vérification
│   ├── verify_artifacts.sh   # Vérifie les artefacts
│   ├── verify_checksums.sh   # Vérifie les checksums
│   └── verify_structure.sh   # Vérifie la structure
│
├── scripts/                 # Scripts utilitaires
│   └── generate-release-notes.sh # Génère les notes de release
│
├── docs/                    # Documentation
│   └── ARCHITECTURE.md       # Architecture matérielle
│
├── output/                  # (Généré par le build)
│   ├── firmware/
│   ├── package/
│   └── logs/
│
└── README.md                # Ce fichier
```

---

## ✨ **Fonctionnalités**

### ✅ Sécurité
- **SHA256 checksums** pour tous les artefacts
- **Signature GPG** optionnelle
- **Aucun téléchargement de binaires externes**
- **Sources vérifiées** et versionnées

### ✅ Transparence
- **100% open-source** - tout est compilé depuis les sources
- **Builds reproductibles** - mêmes sources = mêmes binaires
- **Documentation complète** - chaque étape expliquée

### ✅ Automatisation
- **CI/CD GitHub Actions** - build automatique à chaque push
- **Tests intégrés** - vérification avant merge
- **Releases automatiques** - publication simplifiée

---

## 🚀 **Utilisation**

### Build local
```bash
# Build complet (4-6 heures)
./build-scripts/build_all.sh

# Build rapide (sans toolchain)
./build-scripts/build_all.sh fast

# Build individuel
./build-scripts/kernel/build_kernel.sh
./build-scripts/rootfs/build_rootfs.sh
./build-scripts/tools/build_yaffs.sh
```

### Vérification
```bash
# Vérifier les checksums
./build-scripts/verification/verify_checksums.sh

# Exécuter les tests
chmod +x tests/*.sh
./tests/verify_artifacts.sh
./tests/verify_checksums.sh
./tests/verify_structure.sh
```

### Packaging
```bash
# Créer un package pour USB
./build-scripts/package_firmware.sh

# Le package sera dans output/package/
```

---

## 📦 **GitHub Actions**

### Workflows disponibles

1. **`build.yml`** - Build complet + Tests + Release
   - Déclenché sur: `push` (main, develop), `tags` (v*), `workflow_dispatch`
   - Temps max: 6 heures
   - Cache: toolchain, sources, ccache
   
2. **`verify.yml`** - Vérification rapide
   - Déclenché sur: `pull_request`, `push` (develop)
   - Temps max: 30 minutes
   - Vérifie: syntaxe shell, structure, ShellCheck

### Comment déclencher manuellement
1. Allez dans l'onglet **Actions**
2. Sélectionnez le workflow **Karotz Open Firmware CI/CD**
3. Cliquez sur **Run workflow** > **Run workflow**

### Artéfacts
- Disponibles dans l'onglet **Actions** après chaque build
- Contiennent: firmware, package, checksums
- Conservés 7 jours

### Releases
- Créées automatiquement lors d'un push de tag `v*`
- Exemple: `git tag v1.0.0 && git push origin v1.0.0`
- Contiennent tous les fichiers du package

---

## 📋 **Structure des releases**

Chaque release contient:
```
├── zImage                      # Noyau Linux compilé
├── rootfs.img.gz              # Root filesystem compressé
├── yaffs-tools.tar.gz          # Outils YAFFS
├── checksums.sha256            # Checksums de vérification
├── autorun                    # Script d'installation
├── installfirmware.sh         # Script de flashing
├── functions.sh               # Fonctions utilitaires
├── waitfornetwork.sh          # Configuration réseau
├── VERSION                    # Fichier de version
├── sound/                     # Fichiers audio
└── installpage/               # Interface web
```

---

## 🛠️ **Installation sur Karotz**

### Prérequis
- Une clé USB formatée en **FAT32**
- Un Karotz avec batterie chargée

### Étapes
1. **Télécharger** la dernière release depuis GitHub
2. **Extraire** l'archive sur la clé USB
3. **Insérer** la clé dans le port USB du Karotz
4. **Maintenir** le bouton arrière enfoncé
5. **Allumer** le Karotz
6. **Attendre** que la LED devienne verte (installation terminée)
7. **Relâcher** le bouton - le Karotz redémarre automatiquement

### Vérification
```bash
ssh root@karotz-ip
uname -a
# Doit afficher: Linux karotz 5.4.200-custom ... armv5tel
```

---

## 📊 **Components Sources**

| Composant | Source | Version | Licence |
|-----------|--------|---------|---------|
| **Toolchain** | Linaro GCC | 10.3.0 | GPL |
| **Kernel** | kernel.org | 5.4.200 (LTS) | GPL-2.0 |
| **RootFS** | OpenWrt | 21.02.3 (LTS) | GPL |
| **YAFFS** | yaffs2.git | v5.1.6 | GPL-2.0 |

---

## 🎓 **Architecture Matérielle**

Voir [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) pour les détails complets.

### Résumé
- **CPU**: ARM926EJ-S (ARMv5TE) @ 200 MHz
- **RAM**: 64 MB SDRAM
- **Storage**: 256 MB NAND Flash
- **WiFi**: RTL8187L (802.11b/g)
- **USB**: 1x USB 2.0
- **LEDs**: RGB ears (individually controllable)

### Partitions NAND
```
MTD0: U-Boot (1 MB)
MTD1: Kernel - zImage (4 MB)
MTD2: Root Filesystem - YAFFS2 (~251 MB)
```

---

## 🤝 **Contribution**

1. Fork le dépôt
2. Crée une branche: `git checkout -b feature/ma-fonctionnalite`
3. Commite tes changements: `git commit -m "feat: ajout ma fonctionnalite"`
4. Push: `git push origin feature/ma-fonctionnalite`
5. Ouvre une Pull Request

### Règles
- Tous les commits doivent passer les tests CI
- Les checksums doivent être valides
- La documentation doit être mise à jour

---

## 📜 **Licence**

Ce projet est sous licence **GPL-3.0** - voir [LICENSE](../LICENSE) pour plus de détails.

---

## 🙏 **Remerciements**

- Projet miniil original pour l'architecture de base
- OpenWrt pour la plateforme embedded Linux
- YAFFS pour le système de fichiers NAND
- Tous les contributeurs open-source

---

**📌 Note**: Remplacez `votre-utilisateur` dans les badges par votre vrai nom d'utilisateur GitHub.
