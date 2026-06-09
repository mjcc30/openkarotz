# 📦 OpenKarotz - Résumé du dépôt

## 🎯 **Objectif**

Ce dépôt contient un **système de build complet open-source** pour créer une firmware personnalisée pour le robot **Karotz** (anciennement Nabaztag).

---

## 📁 **Structure complète du dépôt**

```
openkarotz/
├── .github/                          # ✅ Configuration GitHub Actions
│   └── workflows/
│       ├── build.yml                 # Build complet + Release (6h max)
│       └── verify.yml                # Vérification rapide (30min max)
│
├── .gitignore                        # ✅ Fichier d'exclusion Git
├── README.md                         # ✅ Documentation principale
├── COMMITS.md                        # ✅ Guide Git & CI/CD
├── SUMMARY.md                        # ✅ Ce fichier
│
├── build-scripts/                    # ✅ Scripts de build
│   ├── build_all.sh                  # Orchestrateur principal
│   ├── package_firmware.sh          # Packaging final
│   │
│   ├── kernel/
│   │   └── build_kernel.sh           # Build du noyau Linux
│   │
│   ├── rootfs/
│   │   └── build_rootfs.sh           # Build du root filesystem
│   │
│   ├── tools/
│   │   ├── build_toolchain.sh        # Toolchain ARM cross-compilation
│   │   └── build_yaffs.sh             # Outils YAFFS2
│   │
│   └── verification/
│       ├── verify_checksums.sh       # Vérification SHA256
│       └── sign_firmware.sh          # Signature GPG optionnelle
│
├── tests/                            # ✅ Tests de vérification
│   ├── verify_artifacts.sh           # Vérifie les artefacts existants
│   ├── verify_checksums.sh           # Vérifie l'intégrité des checksums
│   └── verify_structure.sh           # Vérifie la structure du package
│
├── scripts/                          # ✅ Scripts utilitaires
│   └── generate-release-notes.sh      # Génère les notes de release
│
├── docs/                             # ✅ Documentation technique
│   └── ARCHITECTURE.md                # Architecture matérielle Karotz
│
├── sound/                            # ✅ Fichiers audio pour l'installation
│   ├── bepatient.mp3
│   ├── bip1.mp3
│   ├── biprobot.mp3
│   ├── congrat.mp3
│   ├── error.mp3
│   ├── finstall.mp3
│   ├── firststep.mp3
│   ├── installok.mp3
│   ├── installweb.mp3
│   ├── installwebok.mp3
│   ├── netconfig.mp3
│   ├── netconfigOK.mp3
│   ├── noturnoff.mp3
│   ├── rabbitreboot.mp3
│   ├── reboot.mp3
│   ├── step2.mp3
│   ├── step3.mp3
│   ├── step4.mp3
│   ├── step5.mp3
│   ├── steptime.mp3
│   ├── toolssetup.mp3
│   ├── toolssetupOK.mp3
│   ├── Usb.mp3
│   ├── usbok.mp3
│   └── writeef.mp3
│
├── installpage/                      # ✅ Interface web d'installation
│   ├── cgi-bin/
│   │   ├── info.sh
│   │   ├── miniilopenkarotz.sh
│   │   ├── openkarotz.sh
│   │   ├── package-reset.sh
│   │   ├── package-run.sh
│   │   └── package-showlog.sh
│   ├── install/
│   │   └── index.html
│   ├── welcome/
│   │   └── index.html
│   ├── installpage.zip
│   ├── info.sh
│   ├── miniilopenkarotz.sh
│   ├── openkarotz.sh
│   ├── package-reset.sh
│   ├── package-run.sh
│   └── package-showlog.sh
│
├── output/                           # ⏳ Généré par le build (exclu par .gitignore)
│   ├── firmware/
│   │   └── .gitkeep
│   ├── package/
│   │   └── .gitkeep
│   └── logs/
│       └── .gitkeep
│
└── Fichiers racine                  # ✅ Fichiers de base
    ├── autorun                       # Script d'installation automatique
    ├── autorun.sig                   # Signature du script
    ├── functions.sh                  # Fonctions utilitaires (LEDs, sons)
    ├── installfirmware.sh            # Script de flashing firmware
    ├── waitfornetwork.sh             # Configuration réseau
    ├── installpage.zip               # Interface web compressée
    ├── zImage                        # Noyau Linux original
    ├── rootfs.miniilos02.img.gz      # RootFS original
    ├── yaffs-12.07.19.00.tar.gz      # Outils YAFFS originaux
    └── tools2.tar                    # Outils supplémentaires originaux
```

---

## 🚀 **Ce que vous pouvez faire**

### 1. **Builder localement**
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

### 2. **Vérifier les builds**
```bash
# Vérifier les checksums
./build-scripts/verification/verify_checksums.sh

# Exécuter les tests
chmod +x tests/*.sh
./tests/verify_artifacts.sh
./tests/verify_checksums.sh
./tests/verify_structure.sh
```

### 3. **Pousser sur GitHub**
```bash
cd openkarotz
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/VOTRE_UTILISATEUR/openkarotz.git
git push -u origin main
```

---

## 🤖 **GitHub Actions - Automatisation**

### Workflows configurés

| Workflow | Fichier | Déclencheurs | Durée | Description |
|----------|---------|--------------|-------|-------------|
| **Build complet** | `.github/workflows/build.yml` | push (main/develop), tags (v*), manuel | 6h max | Build + Tests + Release |
| **Vérification rapide** | `.github/workflows/verify.yml` | pull_request, push (develop) | 30min max | Vérification syntaxe et structure |

### Ce qui est automatique

✅ **À chaque push sur `main` ou `develop`**
- Le firmware est built
- Les tests sont exécutés
- Les artefacts sont stockés (7 jours)

✅ **À chaque tag `v*` (ex: v1.0.0)**
- Une **release GitHub** est créée automatiquement
- Tous les artefacts sont attachés
- Les notes de release sont générées

✅ **À chaque Pull Request**
- Vérification rapide de la syntaxe
- Vérification de la structure
- Exécution de ShellCheck

### Comment déclencher manuellement

1. Allez sur GitHub → votre dépôt → onglet **Actions**
2. Sélectionnez **"Karotz Open Firmware CI/CD"**
3. Cliquez sur **"Run workflow"** (bouton dropdown à droite)
4. Choisissez la branche (`main`)
5. Cliquez sur **"Run workflow"**

---

## 📦 **Ce qui est généré par le build**

Après un build réussi, vous trouverez dans `output/`: 

```
output/
├── firmware/
│   ├── zImage                        # Noyau Linux compilé
│   ├── rootfs.img.gz                 # Root filesystem compressé
│   ├── yaffs-tools-open.tar.gz       # Outils YAFFS compilés
│   ├── checksums.sha256              # Checksums de vérification
│   └── *.checksum                    # Checksums individuels
│
├── package/
│   ├── zImage                        # Copie pour le package
│   ├── rootfs.img.gz                 # Copie pour le package
│   ├── yaffs-tools.tar.gz            # Package des outils
│   ├── checksums.sha256              # Checksums
│   ├── autorun                       # Script d'installation
│   ├── installfirmware.sh            # Script de flashing
│   ├── functions.sh                  # Fonctions utilitaires
│   ├── waitfornetwork.sh             # Configuration réseau
│   ├── VERSION                       # Fichier de version
│   ├── sound/                        # Fichiers audio
│   └── installpage/                  # Interface web
│
└── logs/
    ├── build_all_*.log               # Log du build complet
    ├── toolchain_build_*.log         # Log du toolchain
    ├── kernel_build_*.log            # Log du kernel
    ├── rootfs_build_*.log            # Log du rootfs
    ├── yaffs_build_*.log             # Log des outils YAFFS
    └── verification_*.log            # Log de vérification
```

---

## 🔍 **Tests inclus**

| Test | Fichier | Vérifie |
|------|---------|----------|
| **verify_artifacts.sh** | `tests/` | Tous les artefacts sont présents |
| **verify_checksums.sh** | `tests/` | Intégrité des checksums SHA256/MD5 |
| **verify_structure.sh** | `tests/` | Structure complète du package |
| **ShellCheck** | `.github/workflows/verify.yml` | Syntaxe des scripts shell |

---

## 📊 **Statistiques**

### Taille du dépôt
- **Fichiers sources**: ~500 Ko
- **Fichiers audio**: ~500 Ko
- **Fichiers web**: ~250 Ko
- **Fichiers binaires originaux**: ~27 Mo
- **Total**: ~28 Mo

### Temps de build
| Composant | Temps estimé | Taille output |
|-----------|--------------|---------------|
| Toolchain | 2-3 heures | 2-3 Go |
| Kernel | 30-60 min | 2-3 Mo |
| YAFFS Tools | 5-10 min | ~500 Ko |
| RootFS | 45-90 min | 15-20 Mo |
| **Total** | **4-6 heures** | **~50 Mo** |

### Espace disque requis
- **Minimum**: 50 Go
- **Recommandé**: 100 Go
- **Pour CI/CD**: 15 Go (limite GitHub Actions)

---

## 🎯 **Pourquoi ce projet ?**

### Problèmes de la firmware originale miniil
❌ **Binaires pré-compilés** - On ne sait pas ce qu'il y a dedans  
❌ **Téléchargements externes** - Les CGI scripts téléchargent des packages depuis miniil.be  
❌ **Checksums MD5** - Vulnérables aux collisions  
❌ **Pas de transparence** - Impossible de vérifier la provenance  

### Solutions apportées par OpenKarotz
✅ **100% open-source** - Tout est compilé depuis les sources  
✅ **Aucun téléchargement externe** - Tout est inclus dans le dépôt  
✅ **Checksums SHA256** - Sécurité cryptographique  
✅ **Builds reproductibles** - Mêmes sources = mêmes binaires  
✅ **CI/CD automatique** - Vérification et release automatiques  
✅ **Documentation complète** - Chaque étape expliquée  

---

## 📚 **Documentation**

| Fichier | Description |
|---------|-------------|
| **[README.md](./README.md)** | Guide complet d'utilisation |
| **[COMMITS.md](./COMMITS.md)** | Guide Git et CI/CD |
| **[docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)** | Architecture matérielle Karotz |
| **[IMPLEMENTATION-SUMMARY.md](../IMPLEMENTATION-SUMMARY.md)** | Résumé de l'implémentation |

---

## 🤝 **Comment contribuer**

1. **Fork** ce dépôt
2. **Clone** votre fork
3. Créez une **branche** pour votre fonctionnalité
4. **Commitez** vos changements avec des messages clairs
5. **Poussez** votre branche
6. **Ouvrez une Pull Request**

### Règles de contribution
- ✅ Tous les commits doivent passer les tests CI
- ✅ Les checksums doivent être valides
- ✅ La documentation doit être mise à jour
- ✅ Utilisez des messages de commit clairs (Conventional Commits)

---

## 📜 **Licence**

**GPL-3.0** - Tous les fichiers sont sous licence GPL-3.0 sauf indication contraire.

Voir [LICENSE](../LICENSE) pour plus de détails.

---

## 🙏 **Remerciements**

- **Projet miniil** - Pour l'architecture de base et les scripts originaux
- **OpenWrt** - Pour la plateforme embedded Linux
- **YAFFS2** - Pour le système de fichiers NAND
- **Linaro** - Pour la toolchain ARM
- **Tous les contributeurs open-source** - Sans qui ce projet n'existerait pas

---

## 🚀 **Prochaines étapes**

### Après avoir poussé sur GitHub
1. ✅ Vérifiez que le workflow **Quick Verification** passe
2. ✅ Déclenchez un **build manuel** pour tester
3. ✅ Créez une **release** avec `git tag v1.0.0`
4. ✅ Testez l'installation sur un Karotz

### Améliorations possibles
- [ ] Ajouter un système de build avec Buildroot
- [ ] Créer une interface de configuration web
- [ ] Ajouter le support OTA (Over-The-Air updates)
- [ ] Optimiser pour le matériel spécifique Karotz
- [ ] Ajouter la gestion avancée de la batterie
- [ ] Intégrer un système de packages

---

**Prêt à pusher sur GitHub et à commencer à builder ?** 🎉

```bash
cd openkarotz
git init
git add .
git commit -m "Initial commit: Open-source Karotz firmware"
git remote add origin https://github.com/VOTRE_UTILISATEUR/openkarotz.git
git push -u origin main
```
