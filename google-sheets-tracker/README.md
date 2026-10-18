# 📊 Base de Données Gratuite Google Sheets pour Recall

Ce dossier contient la solution complète permettant d'utiliser **Google Sheets** comme base de données gratuite pour comptabiliser en temps réel chaque téléchargement de votre application **Recall** (macOS et Windows).

---

## ⚡ Pourquoi cette méthode est idéale ?
- **100 % Gratuite à vie** (inclus avec n'importe quel compte Google personnel).
- **Zéro serveur à louer ni à maintenir** (hébergé sur l'infrastructure Google Apps Script).
- **Consultable partout** en temps réel sur votre iPhone, Android ou Mac via Google Drive / Google Sheets.
- **Tableau de bord automatique** : calcul instantané du total des téléchargements, répartition Mac / Windows, date et heure précises, et historique détaillé.

---

## 🚀 Guide d'installation en 2 minutes chrono

### Étape 1 : Créer votre Google Sheet
1. Ouvrez [sheets.new](https://sheets.new) dans votre navigateur.
2. Donnez un nom à votre classeur en haut à gauche, par exemple : `Recall — Suivi Téléchargements`.

### Étape 2 : Ouvrir l'éditeur de script
1. Dans le menu de votre Google Sheet, cliquez sur **Extensions** > **Apps Script**.
2. Une nouvelle page s'ouvre avec un éditeur de code.

### Étape 3 : Coller le code
1. Supprimez tout le texte présent dans la fenêtre (par défaut `function myFunction() { ... }`).
2. Ouvrez le fichier [`Code.gs`](./Code.gs) situé dans ce dossier, copiez **l'intégralité de son contenu** et collez-le dans l'éditeur.
3. Cliquez sur l'icône **Disquette 💾** pour enregistrer (ou faites `Cmd + S` / `Ctrl + S`).

### Étape 4 : Déployer en tant qu'Application Web
1. En haut à droite, cliquez sur le bouton bleu **Déployer** > **Nouveau déploiement**.
2. Cliquez sur l'icône **Engrenage ⚙️** à gauche de *Sélectionner le type*, puis choisissez **Application Web**.
3. Renseignez les paramètres suivants :
   - **Description** : `Tracker Téléchargements Recall`
   - **Exécuter en tant que** : `Moi (votre adresse email)`
   - **Qui a accès** : `Tout le monde` *(indispensable pour que le site web puisse enregistrer les téléchargements sans demander de connexion Google aux visiteurs)*.
4. Cliquez sur le bouton bleu **Déployer**.
5. Si Google affiche une fenêtre demandant l'autorisation :
   - Cliquez sur **Autoriser l'accès**.
   - Choisissez votre compte Google.
   - Si un écran "Google n'a pas validé cette application" apparaît : cliquez sur *Paramètres avancés* en bas à gauche, puis sur *Accéder à Recall (non sécurisé)*.
   - Cliquez sur **Autoriser**.
6. Google vous affiche alors une URL se terminant par `/exec`. **Copiez cette URL**.

### Étape 5 : Activer le tracker sur le site
1. Ouvrez le fichier `docs/assets/js/main.js`.
2. Tout en haut du fichier, collez l'URL copiée dans la variable :
   ```javascript
   const GOOGLE_SHEET_TRACKER_URL = "https://script.google.com/macros/s/VOTRE_IDENTIFIANT_ICI/exec";
   ```
3. C'est terminé ! Dès qu'un visiteur clique sur *Télécharger Recall.dmg* ou *Télécharger Recall-Windows.zip*, une nouvelle ligne s'ajoute instantanément dans votre Google Sheet et le tableau de bord se met à jour en direct.

---

## 💡 NOUVEAU : Onglet « Retours & Suggestions »
Le même script collecte désormais automatiquement toutes les suggestions et retours soumis par les DJs :
- Depuis la modale de feedback sur le site web (`https://revrmusic.github.io/recall/?feedback=1`).
- Depuis l'application Recall (bouton dédié dans les Paramètres et le menu macOS / Windows).

Un onglet intitulé **`💡 Retours & Suggestions`** est généré automatiquement avec :
- **Date & Heure**
- **Catégorie** (Amélioration, Nouvelle fonctionnalité, Compatibilité DJ, Bug, Autre)
- **Message / Idée de suggestion**
- **Nom ou Pseudo DJ** (optionnel)
- **E-mail de contact** (optionnel)
- **Logiciel DJ utilisé** (Serato DJ Pro, Pioneer Rekordbox, etc.)
- **Provenance** (Site web, App macOS, App Windows)
- **Version** (`1.0.0`)

---

## 📈 Ce qui est enregistré dans votre feuille :
- **Date & Heure exacte** (au format `AAAA-MM-JJ HH:mm:ss`)
- **Plateforme** (`macOS` ou `Windows`)
- **Fichier ciblé** (`Recall.dmg`, `Recall-Windows.zip`, `Recall-macOS.zip`)
- **Version** (`1.0.0`)
- **Type d'événement** (`Téléchargement direct` ou `Intention Hero/Nav`)
- **Emplacement du clic** (`Section Téléchargement`, `Hero Header`, `Menu Mobile`, etc.)
- **Langue du site** (`FR` ou `EN`)
- **Langue du navigateur** de l'utilisateur
- **Résolution d'écran**
- **Site référent** (ex: Google, Réseaux Sociaux, GitHub, ou Direct)
- **Navigateur / OS** (User-Agent)

---

## 🔒 Confidentialité & RGPD
Ce tracker ne collecte aucune donnée personnelle non consentie. Pour les suggestions, l'adresse e-mail et le pseudo sont strictement facultatifs et servent uniquement si l'utilisateur souhaite un retour de REVR.

