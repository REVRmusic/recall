# Politique de Confidentialité — Recall

*Dernière mise à jour : 15 octobre 2026*

La protection de votre vie privée et de vos données personnelles est une priorité absolue dans la conception de **Recall**. Cette politique de confidentialité détaille en toute transparence la manière dont l'application fonctionne et traite vos données.

---

## 1. Principe Fondamental : Traitement 100 % Hors-Ligne et Local

Recall est une application d'assistance pour DJs conçue pour fonctionner de manière **entièrement autonome et hors-ligne** sur votre ordinateur (macOS) :

- **Aucune connexion réseau requise** : Recall ne se connecte à aucun serveur distant pour fonctionner.
- **Aucune transmission de données** : Vos données musicales, vos historiques de set, vos routines et vos préférences ne quittent jamais votre Mac.
- **Zéro télémétrie, zéro traceur** : L'application n'intègre aucun outil d'analyse (comme Google Analytics, Mixpanel, Firebase ou Sentry), aucun traceur publicitaire et aucun identifiant unique d'appareil.

---

## 2. Données Consultées sur Votre Ordinateur

Pour vous proposer des suggestions d'enchaînements basées sur vos vrais sets, Recall accède localement à la base de données de votre logiciel DJ :

- **Fichiers consultés** : Le fichier d'historique local `master.sqlite` situé dans `~/Library/Application Support/Serato/Library/`.
- **Accès strictement en lecture seule** : L'accès est verrouillé au niveau du système par les indicateurs `SQLITE_OPEN_READONLY` et `PRAGMA query_only = ON`. Recall ne modifie jamais, n'altère jamais et n'écrit jamais dans la base de données ou les fichiers de Serato DJ Pro.
- **Données lues en mémoire vive** : Titre du morceau, nom de l'artiste, BPM, tonalité harmonique (clé Camelot), date/heure de lecture dans le set, platine (Deck 1 / Deck 2) et chemin d'accès local du fichier audio.

---

## 3. Données Enregistrées par Recall

Toutes les données générées par l'utilisation de Recall sont enregistrées exclusivement sur votre machine dans un répertoire dédié :

- **Emplacement local** : `~/Library/Application Support/Recall/`
- **Données stockées** :
  - `favorite_combos.json` : Vos combinaisons favorites de morceaux enregistrées manuellement.
  - Préférences d'interface utilisateur (stockées via les `UserDefaults` de macOS) : choix du thème de couleur, style de surbrillance des morceaux joués, durée minimale de lecture avant validation, etc.
- **Suppression des données** : La suppression de l'application Recall et de son dossier dans `Application Support` efface l'intégralité de ces données de manière définitive.

---

## 4. Respect des Droits (RGPD / CCPA)

Puisque Recall ne collecte, ne stocke et ne transmet aucune information personnelle à des tiers ou sur des serveurs distants, vos droits fondamentaux (droit d'accès, de rectification, de portabilité et d'effacement) sont garantis nativement par le contrôle total que vous conservez sur vos fichiers locaux sur votre Mac.

---

## 5. Mentions Légales & Marques Déposées

- **Serato Limited** : *Serato*, *Serato DJ*, *Serato DJ Pro*, *Serato DJ Lite* et leurs logos respectifs sont des marques déposées appartenant à **Serato Limited**.
- **Indépendance** : Recall est un logiciel indépendant développé par **REVR** à destination de la communauté DJ. Il n'est en aucun cas affilié, sponsorisé, approuvé ou certifié par Serato Limited.

---

## 6. Contact

Pour toute question ou suggestion concernant la présente politique de confidentialité ou le fonctionnement technique de Recall, vous pouvez ouvrir une issue sur le dépôt officiel :  
**GitHub** : [https://github.com/REVRmusic/recall](https://github.com/REVRmusic/recall)
