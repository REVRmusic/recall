<p align="center">
  <img src="Resources/AppIcon.png" alt="Recall Logo" width="128" height="128" style="border-radius: 26px; box-shadow: 0 10px 30px rgba(0,0,0,0.35);">
</p>

<h1 align="center">Recall</h1>

<p align="center">
  <strong>Compagnon indépendant d'enchaînements musicaux compatible avec Serato DJ Pro &amp; Rekordbox</strong><br>
  <em>Suggère en temps réel vos meilleures transitions, basées exclusivement sur vos routines et votre historique réel de mix.</em>
</p>

<p align="center">
  <a href="https://github.com/REVRmusic/recall/releases"><img src="https://img.shields.io/github/v/release/REVRmusic/recall?style=flat-square&color=0FA2FF&label=Version" alt="Release"></a>
  <img src="https://img.shields.io/badge/macOS-13.0%2B-black?style=flat-square&logo=apple" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/Windows-10%20%2F%2011-0078D6?style=flat-square&logo=windows" alt="Windows 10/11">
  <img src="https://img.shields.io/badge/Serato%20DJ%20Pro-Compatible-blue?style=flat-square" alt="Compatible Serato DJ Pro">
  <img src="https://img.shields.io/badge/Rekordbox-Compatible-red?style=flat-square" alt="Compatible Rekordbox">
  <img src="https://img.shields.io/badge/Swift%20%26%20.NET%208-Native-orange?style=flat-square" alt="Swift & .NET">
  <a href="LICENSE"><img src="https://img.shields.io/badge/Licence-MIT-green?style=flat-square" alt="Licence MIT"></a>
  <a href="PRIVACY.md"><img src="https://img.shields.io/badge/Confidentialité-100%25%20Hors--ligne-purple?style=flat-square" alt="100% Local"></a>
</p>

<p align="center">
  🌐 <strong>Site Web &amp; Présentation Officielle :</strong> <a href="https://revrmusic.github.io/recall/"><strong>revrmusic.github.io/recall</strong></a>
</p>

---

## 📸 Aperçu en Situation Réelle

<p align="center">
  <em>Recall en mode flottant au-dessus de Serato DJ Pro avec détection live et suggestions harmoniques :</em><br>
  <img src="Resources/Screenshots/recall-serato-dj-mockup.png" alt="Recall en mode flottant au-dessus de Serato DJ Pro" width="100%">
</p>

<p align="center">
  <em>Le nouvel onglet Sélec (Scratchpad DJ avec classement automatique par affinité BPM & Camelot) :</em><br>
  <img src="Resources/Screenshots/recall-serato-selec.png" alt="Recall - Onglet Sélec au-dessus de Serato DJ Pro" width="100%">
</p>

<p align="center">
  <em>Mode Bandeau Compact (78 px) docké en bas d'écran & Compatibilité Pioneer Rekordbox :</em><br>
  <img src="Resources/Screenshots/recall-compact-serato.png" alt="Recall - Mode Bandeau Compact 78px" width="49%">
  <img src="Resources/Screenshots/recall-rekordbox.png" alt="Recall - Compatibilité Pioneer Rekordbox" width="49%">
</p>

<p align="center">
  <em>Panneau de configuration épuré avec estompage doux :</em><br>
  <img src="Resources/Screenshots/recall-settings-backdrop.png" alt="Recall - Panneau des Paramètres et Estompage" width="70%">
</p>

---

## ⚡️ Pourquoi Recall ?

Pendant un set DJ, retrouver rapidement le morceau idéal qui enchaîne parfaitement avec ce qui tourne sur la platine active est crucial. 

Contrairement aux solutions génériques qui se basent sur des algorithmes opaques ou de simples classements de streaming, **Recall analyse directement vos propres sessions passées dans Serato DJ Pro et Rekordbox** :
- **Vos vraies routines** : Si vous avez enchaîné un morceau 12 fois l'an dernier et que le dancefloor a réagi, Recall s'en souvient et vous le propose en tête de liste (`🔥 12x`).
- **Scratchpad "Sélec" intelligent** : Glissez vos pépites repérées en amont depuis Serato directement dans votre Sélec. Elles restent enregistrées et se réordonnent automatiquement en direct selon leur compatibilité harmonique et BPM avec le titre en cours de lecture.
- **Harmonie instantanée** : Respect fidèle des couleurs de la **Roue de Camelot** et filtrage automatique des clés compatibles.
- **Glisser-Déposer direct (`Drag & Drop`)** : Attrapez la suggestion et déposez-la directement sur vos platines Serato ou Rekordbox.
- **Compatibilité Universelle** : Détection automatique intelligente de votre logiciel DJ actif (Serato DJ Pro ou Pioneer DJ Rekordbox) avec zéro surcharge processeur.

---

## 📥 Téléchargement & Installation (v1.0.13)

| Plateforme | Fichier à télécharger | Recommandation |
| :--- | :--- | :--- |
| 🍏 **macOS (13.0+)** | [**Recall.dmg**](https://github.com/REVRmusic/recall/releases/download/v1.0.13/Recall.dmg) | ⭐️ **Recommandé Mac** — Image disque officielle prête à glisser dans Applications |
| 🍏 **macOS (13.0+)** | [**Recall-macOS.zip**](https://github.com/REVRmusic/recall/releases/download/v1.0.13/Recall-macOS.zip) | Archive application autonome macOS |
| 🪟 **Windows (10 / 11)** | [**Recall-Windows-x64.zip**](https://github.com/REVRmusic/recall/releases/download/v1.0.13/Recall-Windows-x64.zip) | ⭐️ **Recommandé Windows** — Archive complète avec `Recall.exe` |
| 🪟 **Windows (10 / 11)** | [**Recall.exe**](https://github.com/REVRmusic/recall/releases/download/v1.0.13/Recall.exe) | Exécutable Windows autonome 64-bit |

### 🍏 Pour macOS

#### Option 1 : Téléchargement Direct (Recommandé)
1. Téléchargez [**Recall.dmg**](https://github.com/REVRmusic/recall/releases/download/v1.0.13/Recall.dmg).
3. Ouvrez le fichier `.dmg` et glissez **Recall** dans votre dossier **Applications**.
4. Lancez **Serato DJ Pro**, puis ouvrez **Recall** : la détection est automatique et immédiate !

> **Note macOS (Gatekeeper)** : Au premier lancement, si macOS affiche un avertissement de sécurité, faites un clic droit (ou Contrôle + clic) sur **Recall.app** dans `/Applications` puis cliquez sur **Ouvrir**.

#### Option 2 : Installation en 1 ligne dans le Terminal
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/REVRmusic/recall/main/install.sh)"
```

#### Option 3 : Compilation depuis les Sources (macOS)
```bash
git clone https://github.com/REVRmusic/recall.git
cd recall
chmod +x build.sh && ./build.sh --dmg
```

---

### 🪟 Pour Windows (10 & 11)

#### Option 1 : Téléchargement Direct (Recommandé)
1. Téléchargez [**Recall-Windows-x64.zip**](https://github.com/REVRmusic/recall/releases/download/v1.0.13/Recall-Windows-x64.zip) ou l'exécutable autonome [**Recall.exe**](https://github.com/REVRmusic/recall/releases/download/v1.0.13/Recall.exe).
2. Dézippez l'archive dans le dossier de votre choix (ex: `C:\Program Files\Recall` ou sur votre Bureau).
3. Lancez **Serato DJ Pro** ou **Rekordbox**, puis double-cliquez sur **`Recall.exe`** : la détection est instantanée !

#### Option 2 : Compilation depuis les Sources (Windows)
Prérequis : PC sous Windows 10/11 avec le SDK [.NET 8](https://dotnet.microsoft.com/download/dotnet/8.0) installé.
```cmd
git clone https://github.com/REVRmusic/recall.git
cd recall\Windows
build-windows.bat
```
L'exécutable autonome optimisé est généré directement dans `Windows\build-win\Recall.exe`.

---

## 🌟 Fonctionnalités Détaillées

### 1. ⏱️ Détection Intelligente Serato DJ Pro & Rekordbox
- **Serato DJ Pro** : Détection sub-milliseconde des platines actives (Deck 1 / Deck 2) via accès direct sécurisé en lecture seule (`PRAGMA query_only = ON`) au fichier SQLite WAL.
- **Pioneer DJ Rekordbox** : Lecture et analyse ultra-rapide de votre collection et de vos historiques de playlists (format standard XML Rekordbox). Détecte des dizaines de milliers d'enchaînements passés en quelques fractions de seconde.
- **Détection Automatique ou Choix Manuel** : Bascule instantanément sur le logiciel DJ actif (Serato ou Rekordbox) sans surcharge CPU.
- Mode **MANUEL** avec recherche instantanée dans toute votre bibliothèque pour préparer une transition à froid.

### 2. 📈 Algorithme de Routines Historiques (30 à 730 jours)
- Priorise strictement les titres que vous avez **réellement enchaînés** dans vos sets passés.
- Exclusion des lectures isolées ou des pré-écoutes rapides.
- Décompte visuel dynamique : `🔥 15x`, `🔥 6x`, `2x`.

### 3. 🔖 Scratchpad "Sélec" & Classement Dynamique en Direct
- **Préparation de sets sans friction** : Glissez n'importe quel morceau depuis le browser de Serato DJ Pro directement sur la fenêtre de Recall (ou cliquez sur le marque-page 🔖) pour l'ajouter à votre sélection de titres à jouer prochainement.
- **Persistance totale inter-sessions** : Contrairement aux bacs temporaires ou aux réinitialisations de session, votre Sélec n'est **jamais vidée automatiquement**. Vos morceaux restent enregistrés même si vous redémarrez l'ordinateur ou actualisez votre set.
- **Tri intelligent en direct selon le morceau actif** : Dès qu'un nouveau morceau démarre sur vos platines, votre liste Sélec se réordonne automatiquement en tête de liste :
  - **BPM prioritaire** : Les morceaux au tempo le plus proche sont placés en haut (avec prise en compte native des relations double-time et half-time).
  - **Harmonie Camelot** : Bonus de compatibilité harmonique (clés identiques, voisines ±1, relatives majeures/mineures ou boosts +2).
  - **Bonus de combos & favoris** : Vos enchaînements éprouvés remontent naturellement.
- **Suppression unitaire & vidage facile** : Chaque titre dispose d'une icône de corbeille 🗑️ pour le retirer dès qu'il a été joué, avec un bouton global « Vider la sélec » pour repartir à zéro.

### 4. 🎯 Glisser-Déposer Bidirectionnel (Drag & Drop)
- Glissez n'importe quelle ligne de suggestion directement sur vos platines Serato DJ Pro ou Rekordbox.
- Glissez n'importe quel fichier audio depuis Serato vers Recall pour l'ajouter instantanément à votre **Sélec**.
- Intégration double flux macOS (`NSFilenamesPboardType` et `public.file-url`) et Windows (`DataFormats.FileDrop`) garantissant une réactivité instantanée.

### 5. 🎼 Clés Camelot Officielles & Filtre BPM Intelligent
- Couleurs authentiques de la roue Camelot pour les 24 tonalités (Mineures `A` et Majeures `B`).
- Filtre rapide **Harmonie** (clés compatibles : Identique, Parfaite ±1, Relative, Boost +2).
- Filtre **BPM ±10%** prenant automatiquement en compte les relations half-time et double-time (ex: 75 BPM compatible avec 150 BPM).

### 6. 🔵 Marquage des Morceaux Déjà Joués
- Identification visuelle instantanée des morceaux déjà joués au cours de votre set pour éviter les doublons accidentels.
- Rendu fidèle : surbrillance en **Bleu officiel (`#0FA2FF`)**.
- **Palette de couleurs personnalisable** dans les paramètres (Bleu officiel, Cyan Électrique, Violet, Émeraude, Orange, Rose, ou sélecteur libre).
- **3 styles d'affichage** : Texte & Fond, Texte seul, ou Fond seul.
- Bouton de remise à zéro rapide de session en un clic.

### 7. ⭐ Combinaisons Favorites & Filtre "Favs"
- Enregistrement immédiat d'une alchimie parfaite entre deux morceaux via le bouton **Favori** avec modal de confirmation rapide.
- Filtre rapide **Favoris** pour isoler vos enchaînements fétiches en situation de mix intense.

### 8. 🪟 Interface Flottante & Bandeau Compact 78 px (`Always-on-top`)
- Se positionne discrètement au-dessus de Serato sans jamais gêner les platines ou les crates.
- Verre dépoli translucide moderne natif (`NSVisualEffectView` avec flou d'arrière-plan réglable de 20% à 100%).
- Bouton de réduction en **Bandeau Compact (78 px)** affichant le Top Match en cours d'un simple coup d'œil.

### 9. ⌨️ Raccourcis Clavier Globaux Système (Hotkeys)
- **Le concept : Pouvoir contrôler Recall sans jamais quitter Rekordbox/Serato de l'écran :**
  - `⌘ + ⇧ + R` (ou `Ctrl + Shift + R`) : **Afficher / Masquer Recall**.
  - `⌘ + ⇧ + C` (ou `Ctrl + Shift + C`) : **Basculer instantanément entre mode normal et bandeau compact**.
  - `⌘ + ⇧ + F` (ou `Ctrl + Shift + F`) : **Ouvrir la recherche Recall par-dessus votre logiciel DJ**.
- **🛡️ Protection Anti-Conflit Rekordbox & Serato :**
  - Dans **Rekordbox** (Mode Performance), `⌘ + ⇧ + R` déclenche le saut arrière (**Jump Reverse Deck 1**).
  - Dans **Serato DJ Pro**, `⌘ + ⇧ + F` déclenche la recherche dans toutes les caisses (**All Crates Search**).
  - Pour un mix sans aucun risque en live, Recall supporte également en parallèle le mode **`⌥⌘` (Cmd + Option sur Mac / Ctrl + Alt sur Windows)** (`⌥⌘R`, `⌥⌘C`, `⌥⌘F`), **100 % libre et garanti sans aucun conflit**.

### 10. 📊 Récapitulatif de Set & Statistiques de Fin de Mix
- **Durée réelle de mix** : Le chrono reste figé à `00m 00s` et ne démarre qu'au moment précis où votre premier morceau est joué (élimination totale du temps fantôme).
- **Genre Musical Dominant & Top 5 des Genres** : Détection en temps réel du genre le plus joué et affichage graphique des 5 genres principaux avec barres de progression colorées et pourcentages.
- **Métriques clés** : Morceaux joués, cadence moyenne (titres/heure), transitions uniques enchaînées, BPM moyen et amplitude de tempo, tonalité Camelot dominante et top artistes.
- **Export 1-clic** : Copie instantanée de la synthèse formatée dans le presse-papier pour vos réseaux sociaux et tracklists.

### 11. 🪟 Refonte Complète de l'Interface Windows (Parité macOS)
- **Design sombre néon & Verre dépoli** : Application d'un conteneur moderne avec coins arrondis, bordures subtiles et fond sombre semi-translucide identique à la version Mac.
- **Boutons circulaires d'action** : Fermer, Réduire en bandeau, Épingler (*Always-on-top*), Guide & Légende, Statistiques, Recherche de bibliothèque et Paramètres.
- **Contrôles personnalisés** : Menus déroulants sombres, scrollbars fines de 6 px et disque vinyle dynamique texturé dont le macaron s'adapte en temps réel à la tonalité Camelot du morceau en cours.
- **Raccourcis Windows intégrés** : `Ctrl+Shift+C` (Bandeau compact), `Ctrl+Shift+F` (Recherche), `Ctrl+Shift+S` (Paramètres).

### 12. 🔍 Recherche Bibliothèque & Guide Interactif
- **Recherche instantanée** (`Ctrl+Shift+F` sur Windows, `Cmd+Shift+F` sur Mac) : Trouvez n'importe quel morceau par titre ou artiste dans Serato DJ Pro ou Rekordbox pour prévisualiser les enchaînements sans charger le deck.
- **Guide & Légende** (`?`) : Explication détaillée des codes couleur de la roue de Camelot, de la tolérance BPM, du décompte de fréquence de mix (`🔥 15x`), et du glisser-déposer.

### 13. 🎨 Ambiance Visuelle & Thèmes DJ
- 4 palettes néon conçues pour la nuit et les cabines de DJ : **Cyan Neon**, **Purple Haze**, **Amber Sunset**, **Lime Club**.
- Flou d'arrière-plan natif en verre dépoli (`NSVisualEffectView`) avec curseur de translucidité intuitif de 20% à 100%.

### 14. 📝 Générateur de Tracklists 1-Clic
- Export immédiat minuté et formaté compatible 1001Tracklists, Mixcloud, SoundCloud et YouTube.

### 15. 🚀 Mises à Jour en un Clic dans les Paramètres
- Détection automatique au lancement (asynchrone sans impact audio) et bouton de vérification manuelle (**« Vérifier maintenant »**) dans la modale des paramètres sous macOS et Windows avec lien de téléchargement direct.

---

## 🔒 Confidentialité & Sécurité Absolue

- **100% Hors-ligne** : Aucune donnée ne quitte votre machine. Zéro serveur, zéro télémétrie, zéro traceur.
- **Accès en Lecture Seule** : Recall ne modifie jamais votre base Serato, vos fichiers audio ou vos tags ID3.
- **Conception Native Double-Plateforme** :
  - **macOS** : Développé exclusivement en **Swift pur** avec les frameworks natifs d'Apple (SwiftUI, AppKit, SQLite3).
  - **Windows** : Développé en **C# / .NET 8 WPF** haute performance avec `Microsoft.Data.Sqlite` et support autonome sans dépendance.

---

## 🛠️ Structure du Projet

```
Recall/
├── Package.swift               # Configuration Swift Package Manager (macOS)
├── build.sh                    # Script de compilation Release macOS (Recall.app & Recall.dmg)
├── install.sh                  # Script d'installation automatique macOS en une ligne
├── run.sh                      # Lanceur rapide en mode développement macOS
├── LICENSE                     # Licence MIT
├── PRIVACY.md                  # Politique de confidentialité 100% hors-ligne
├── Resources/                  # Icônes haute définition et captures d'écran
├── Sources/                    # Code source natif macOS (SwiftUI / AppKit)
│   └── Recall/
│       ├── App/                # Cycle de vie Cocoa, NSApplication et FloatingWindowController
│       ├── Models/             # Modèles de données (Track, CamelotKey, UserSettings)
│       ├── Services/           # SQLite Serato (WAL), Rekordbox (XML), ToPlayService (Sélec), Drag & Drop
│       ├── Views/              # Vues SwiftUI modernes (Main, NowPlaying, Suggestions, Settings, Bandeau)
│       └── Utils/              # Extensions graphiques et configurateurs de défilement
└── Windows/                    # Version native Windows (10 & 11 - C# / .NET 8 WPF)
    ├── Recall.sln              # Solution Visual Studio
    ├── build-windows.bat       # Script de compilation 1-clic (.exe autonome)
    ├── run-windows.bat         # Lanceur rapide Windows
    └── Recall/
        ├── Recall.csproj       # Projet .NET 8 WPF x64
        ├── MainWindow.xaml     # Interface flottante sombre & bandeau compact
        ├── SettingsWindow.xaml # Modale de configuration (Serato, Rekordbox, filtres)
        ├── Models/             # Modèles Track, CamelotKey, UserSettings
        ├── Services/           # SeratoDatabaseService, RekordboxService, ToPlayService (Sélec), Combos
        └── Resources/          # Icône Windows AppIcon.ico
```

---

## ⚖️ Mentions Légales & Marques Déposées

- **Serato Limited** : *Serato*, *Serato DJ*, *Serato DJ Pro*, *Serato DJ Lite* et leurs logos respectifs sont des marques déposées appartenant à **Serato Limited**.
- **AlphaTheta Corporation** : *Rekordbox*, *Pioneer DJ* et leurs logos respectifs sont des marques déposées appartenant à **AlphaTheta Corporation**.
- **Clause de non-affiliation** : Recall est un logiciel indépendant développé par **REVR** pour la communauté DJ. Recall n'est en aucun cas affilié, sponsorisé, associé, validé ou certifié par Serato Limited ou AlphaTheta Corporation. L'utilisation des noms de marque dans cette documentation et dans l'application est faite à titre purement descriptif afin d'indiquer la compatibilité technique du logiciel (*Nominative Fair Use*).
- **Protection de la vie privée** : Pour consulter notre engagement de confidentialité 100 % hors-ligne, reportez-vous au fichier [PRIVACY.md](PRIVACY.md).

---

## 📄 Licence

Ce projet est distribué sous licence libre **MIT**. Consultez le fichier [LICENSE](LICENSE) pour plus de détails.

---

<p align="center">
  Développé avec passion pour la communauté DJ par <strong>REVR</strong>.
</p>
