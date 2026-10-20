# 🎧 Recall v1.0.10 — Morceaux déjà joués colorés sur téléphone + Sync thème temps réel

Cette version **v1.0.10** aligne l'affichage des **morceaux déjà joués** du Compagnon Téléphone sur la version Mac (couleur bleue / personnalisable), avec synchronisation **temps réel** du thème DJ et de la couleur des pistes lues.

---

### 🌟 Nouveautés v1.0.10

#### 📱 Compagnon Téléphone — Morceaux déjà joués & sync design
- Les morceaux déjà joués s'affichent en **bleu** (ou dans la couleur choisie dans Paramètres → Couleur des morceaux joués), exactement comme sur Mac.
- Le **style de surbrillance** (Texte & Fond / Texte seul / Fond seul) est respecté sur le téléphone.
- Changement de **thème DJ**, de **couleur des joués** ou de **style** dans les Paramètres Mac → mise à jour **instantanée** sur le téléphone (flux SSE).
- Scroll horizontal verrouillé pour une lecture fluide en live.

#### ⚡ Mise à jour automatique en 1 clic (macOS & Windows)
- **Installation directe intégrée** : cliquer sur **« Installer et relancer »** télécharge l'application en tâche de fond avec barre de progression, remplace automatiquement `/Applications/Recall.app` et relance Recall.
- **Zéro alerte Gatekeeper macOS** : suppression automatique de la quarantaine navigateur (`com.apple.quarantine`) et validation de la signature locale `fr.revr.recall` (vos autorisations macOS sont conservées).

#### 📱 Compagnon Téléphone (Wi‑Fi local, sans Internet)
- Bouton **📱** dans l'en-tête de Recall (ou **⌘⇧P**) → une fenêtre affiche un **QR code**.
- Scannez avec l'appareil photo du téléphone : la page s'ouvre dans le navigateur, **aucune app à installer**.
- Mise à jour **instantanée** à chaque changement de piste, de filtre ou de Sélec.
- Affiche : morceau en cours (titre, artiste, BPM, clé Camelot colorée), suggestions / favoris / Sélec, badges d'enchaînement, écart BPM, thème DJ synchronisé.
- **Code PIN** généré automatiquement (sécurité sur un Wi‑Fi de club partagé), modifiable dans la fenêtre du compagnon.
- Mode club recommandé : activez le **hotspot** du téléphone et connectez-y le Mac — aucune donnée mobile n'est consommée, tout reste en local.
- Lecture seule depuis le téléphone : aucune action ne peut modifier votre set à distance.

---

### 🛠️ Inclus depuis v1.0.6
- Parité Windows (tracklists, thèmes, tray, export image).
- Sessions Serato / Rekordbox de moins de 10 minutes ignorées dans suggestions et stats.
- Compagnon barre des menus Mac + lancement au démarrage.
- Partage web du récapitulatif de set.
