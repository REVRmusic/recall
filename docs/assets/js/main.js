/* ==========================================================================
   RECALL — Main Interactive Scripts & Bilingual i18n
   ========================================================================== */

// --- Dictionnaire Bilingue (FR / EN) ---
const translations = {
  fr: {
    // Nav
    "nav-features": "Fonctionnalités",
    "nav-demo": "Démonstration",
    "nav-compatibility": "Compatibilité",
    "nav-problem": "Pourquoi Recall&nbsp;?",
    "nav-download": "Télécharger",
    "nav-faq": "FAQ",
    "nav-legal": "Mentions Légales",
    "nav-cta-download": "Télécharger v1.0",
    
    // Hero
    "hero-pill-badge": "NOUVEAU",
    "hero-pill-text": "Compagnon DJ Indépendant & 100 % Hors-Ligne",
    "hero-title-part1": "Ne perdez plus jamais le fil",
    "hero-title-part2": "de vos meilleurs mixes.",
    "hero-subtitle": "Le copilote intelligent qui fouille vos historiques Serato et Rekordbox pour vous suggérer instantanément vos transitions éprouvées et vos enchaînements harmoniques Camelot en plein set.",
    "hero-btn-mac": "Télécharger pour macOS",
    "hero-btn-win": "Télécharger pour Windows",
    "hero-btn-github": "Code source GitHub",
    "trust-offline": "100 % Hors-ligne (Zéro Wi-Fi)",
    "trust-cpu": "0 % CPU au repos (< 25 Mo RAM)",
    "trust-safe": "Lecture seule (Zéro risque de crash)",
    "trust-free": "Gratuit & Open-Source",
    
    // Showcase & Real App Simulator
    "showcase-sim-title": "Recall 1.0 — Simulation Interactive de l'Application",
    "sim-mode-floating": "Vue Flottante",
    "sim-mode-compact": "Bandeau Compact (78 px)",
    "sim-status-active": "Surveillance active (1.5s)",
    "sim-settings-heading": "Paramètres Recall",
    "sim-sett-dj-label": "Logiciel DJ Actif",
    "sim-sett-key-label": "Format des Clés Harmoniques",
    "sim-sett-bpm-label": "Tolérance Tempo (BPM)",
    "sim-sett-opt-label": "Options d'Affichage",
    "sim-sett-always-top": "Toujours au premier plan (Floating Window)",
    "sim-sett-hide-played": "Masquer les morceaux déjà joués dans la session",
    "sim-sett-save": "Enregistrer et fermer",
    "sim-app-reduce": "Réduire",
    "sim-guide-title": "Guide des Clés & Routines",
    "sim-g1": "Même clé harmonique. Transition parfaite.",
    "sim-g2": "Énergie descendante (-1) ou montante (+1).",
    "sim-g3": "Bascule Majeur / Mineur (A ↔ B) sans fausse note.",
    "sim-g4": "Montée d'adrénaline énergique pour peak time.",
    "sim-g5": "Nombre de fois où vous avez joué ce mix en live.",
    "sim-now-playing-label": "EN COURS",
    "sim-save-combo-text": "Sauvegarder ce combo",
    "sim-filter-bpm": "BPM ±10%",
    "sim-filter-harm": "Harmonie",
    "sim-filter-favs": "Favs",
    "sim-matches-label": "matchs",
    "sim-compact-expand": "Déplier",
    "sim-interactive-hint": "Simulation interactive temps réel : cliquez sur n'importe quel morceau pour l'enchaîner, filtrez par BPM et harmonie, ou ouvrez les réglages (⚙️) pour tester le fond obscurci et le format des clés.",
    
    // Problem Section
    "problem-tag": "Le Dilemme du DJ en Club",
    "problem-title": "Pourquoi vos meilleurs mixes tombent dans l'oubli&nbsp;?",
    "problem-subtitle": "Pendant un set de 3 heures à 128 BPM, le cerveau d'un DJ est saturé. Recall veille sur vos platines pour ranimer vos plus belles inspirations sans vous déranger.",
    "p1-title": "Le trou de mémoire à 30 secondes de la fin",
    "p1-desc": "La fin du morceau approche. Vous cherchez fébrilement dans 10 000 titres un enchaînement magique que vous avez déjà fait par le passé, mais le titre exact vous échappe.",
    "p2-title": "Des gig logs et playlists sous-exploités",
    "p2-desc": "Vos logiciels DJ stockent des milliers d'heures d'historiques dans des bases de données dormantes. Personne ne les analyse pour vous faire profiter de votre propre expérience.",
    "p3-title": "Le piège des algorithmes en ligne",
    "p3-desc": "Les recommandations de streaming génériques ne connaissent ni votre style de mix, ni votre public, et tombent en panne au moindre trou de réseau en sous-sol.",
    
    // Simulator Section
    "sim-tag": "Simulateur Interactif",
    "sim-title": "Testez la logique de recommandation Recall",
    "sim-subtitle": "Sélectionnez un titre ou choisissez une clé Camelot et un BPM pour voir comment Recall combine instantanément vos routines historiques et la compatibilité harmonique.",
    "sim-label-track": "1. Choisissez un titre en cours de lecture :",
    "sim-label-bpm": "2. Tempo en direct (BPM) :",
    "sim-now-playing-badge": "Platine Active (En cours)",
    "sim-suggestions-badge": "Suggestions calculées (Top Routines & Clés)",
    
    // Bento Features
    "features-tag": "Fonctionnalités Clés",
    "features-title": "Conçu par et pour les DJs exigeants",
    "features-subtitle": "Chaque détail de Recall a été pensé pour s'intégrer discrètement dans votre workflow sans jamais accaparer votre écran.",
    "f1-title": "Mining Intelligent de vos Routines",
    "f1-desc": "Recall fouille vos sessions passées (Serato `master.sqlite` et Rekordbox XML) pour détecter vos paires de morceaux les plus jouées. Les flammes 🔥 7x vous indiquent immédiatement vos transitions éprouvées.",
    "f1-badge": "20 000+ transitions détectées",
    "f2-title": "Harmonie Camelot Wheel",
    "f2-desc": "Chaque suggestion affiche sa clé Camelot exacte, ses clés voisines (+1/-1 heure), ses relatifs majeurs/mineurs ou ses boosts d'énergie (+2 heures) pour un mix harmonieux sans fausse note.",
    "f2-badge": "Compatible Clés Musicales & Open Key",
    "f3-title": "Glisser-Déposer Direct (Drag & Drop)",
    "f3-desc": "Attrapez un titre depuis Recall et glissez-le directement sur la platine 1, 2 ou dans vos bacs de Serato et Rekordbox. Zéro manipulation fastidieuse.",
    "f3-badge": "Natif macOS & Windows",
    "f4-title": "Bandeau Compact Ultra-Fin (78 px)",
    "f4-desc": "Passez en un clic en mode bandeau minimaliste docké en bas à droite de votre écran. Vos formes d'ondes Serato restent 100 % visibles.",
    "f4-badge": "Fenêtre toujours au premier plan",
    "f5-title": "Détection Automatique (0,1 ms)",
    "f5-desc": "Recall détecte automatiquement si Serato DJ Pro ou Rekordbox est lancé et bascule sans effort. Aucune surcharge processeur.",
    "f5-badge": "Zéro impact sur la latence audio",
    "f6-title": "100 % Hors-Ligne & Respect Absolu de la Vie Privée",
    "f6-desc": "Aucun compte requis, aucune télémétrie, aucune connexion Internet. Recall lit uniquement vos historiques locaux sans jamais modifier vos fichiers.",
    "f6-badge": "100 % Local & Sandboxé",
    
    // Compatibility Section
    "compat-tag": "Écosystème",
    "compat-title": "Compatibilité Logicielle & Matérielle",
    "compat-subtitle": "Développé en Swift natif pour macOS et en C# / .NET 8 moderne pour Windows.",
    "compat-serato-title": "Serato DJ Pro",
    "compat-serato-ver": "v2.5, v3.0, v3.1, v3.2+",
    "compat-serato-1": "Lecture temps réel du deck actif via base SQLite (WAL)",
    "compat-serato-2": "Détection automatique des changements de platine (< 1s)",
    "compat-serato-3": "Drag & Drop natif vers les platines et crates",
    "compat-serato-4": "Accès 100 % en lecture seule sans modifier Serato",
    
    "compat-rekordbox-title": "Pioneer DJ Rekordbox",
    "compat-rekordbox-ver": "v6.x & v7.x",
    "compat-rekordbox-1": "Lecture haute performance du pont Rekordbox XML",
    "compat-rekordbox-2": "Analyse de 15 000+ morceaux et playlists en 0,45 s",
    "compat-rekordbox-3": "Recherche sub-milliseconde et suggestions harmoniques",
    "compat-rekordbox-4": "Drag & Drop direct vers les decks Rekordbox",
    
    // Comparison Table
    "table-col-feature": "Fonctionnalité",
    "table-col-recall": "Recall Copilot",
    "table-col-spotify": "Algorithmes Streaming",
    "table-col-notes": "Notes papier / Bacs fixes",
    "row1-name": "Basé sur VOS routines passées réelles",
    "row1-val-recall": "✅ OUI (Historique local)",
    "row1-val-spotify": "❌ Non (Générique)",
    "row1-val-notes": "🟡 Partiel (Mémoire humaine)",
    "row2-name": "Fonctionne sans Internet (Club / Sous-sol)",
    "row2-val-recall": "✅ 100 % Hors-ligne",
    "row2-val-spotify": "❌ Impossible sans réseau",
    "row2-val-notes": "✅ Oui",
    "row3-name": "Harmonie Camelot en temps réel",
    "row3-val-recall": "✅ Automatique & Trié",
    "row3-val-spotify": "❌ Non",
    "row3-val-notes": "❌ Calcul mental manuel",
    "row4-name": "Glisser-déposer vers le logiciel DJ",
    "row4-val-recall": "✅ Direct dans Decks",
    "row4-val-spotify": "❌ Non",
    "row4-val-notes": "❌ Non",
    "row5-name": "Consommation RAM & CPU",
    "row5-recall": "< 25 Mo / 0 % CPU",
    "row5-spotify": "> 400 Mo + Connexion",
    "row5-notes": "0 Mo (mais statique)",
    
    // Downloads
    "dl-tag": "Téléchargement Gratuit",
    "dl-title": "Installez Recall sur votre machine de mix",
    "dl-subtitle": "Téléchargez la version officielle 1.0.0 pour macOS ou Windows. Aucun compte requis, installez et mixez.",
    "dl-mac-title": "macOS",
    "dl-mac-specs": "macOS 12.0+ Monterey, Ventura, Sonoma, Sequoia (Universal Apple Silicon M1-M4 & Intel)",
    "dl-mac-btn": "Télécharger Recall.dmg",
    "dl-mac-zip": "Télécharger au format .zip",
    "dl-win-title": "Windows",
    "dl-win-specs": "Windows 10 & 11 (64-bit x64, .NET 8 WPF)",
    "dl-win-btn": "Télécharger Recall-Windows.zip",
    "dl-win-exe": "Exécutable autonome prêt à l'emploi",
    "dl-github-note": "Consultez également les releases officielles et le code source sur ",
    
    // FAQ
    "faq-tag": "Questions Fréquentes",
    "faq-title": "Tout ce que vous devez savoir avant de mixer avec Recall",
    "q1": "Est-ce que Recall risque de faire planter mon logiciel DJ en plein set ?",
    "a1": "Absolument aucun risque. Recall fonctionne dans un processus système totalement distinct et indépendant. Il accède aux bases de données Serato et Rekordbox en mode strictement **lecture seule** (`read-only`), sans jamais verrouiller ni altérer les fichiers en cours d'utilisation.",
    "q2": "Recall modifie-t-il mes fichiers audio, tags ID3 ou crates ?",
    "a2": "Non, jamais. Recall ne modifie pas un seul octet de vos MP3, FLAC, WAV, ni vos fichiers de configuration. Vos métadonnées musicales restent intouchées.",
    "q3": "Ai-je besoin d'une connexion Internet en soirée ?",
    "a3": "Non ! Recall est conçu pour la réalité des clubs, festivals et caves sans réseau. L'application est 100 % autonome et hors-ligne. Aucun port réseau n'est ouvert.",
    "q4": "Comment fonctionne la détection automatique entre Serato et Rekordbox ?",
    "a4": "Recall inspecte la liste des processus applicatifs en cours d'exécution toutes les 1,5 secondes. Cette vérification consomme moins de 0,1 milliseconde de CPU. Si Rekordbox est lancé, Recall bascule sur Rekordbox. Si Serato est lancé, il surveille le deck Serato. Vous pouvez aussi forcer un logiciel manuellement dans les réglages.",
    "q5": "Comment importer ma collection Rekordbox dans Recall ?",
    "a5": "Dans Rekordbox, faites simplement un clic droit sur votre Collection > 'Exporter la collection au format XML'. Recall détecte automatiquement le fichier dans vos Documents. Vous pouvez également sélectionner manuellement votre fichier XML dans la modale des paramètres de Recall.",
    "q6": "Est-ce gratuit ? Y a-t-il un abonnement ou des fonctionnalités bridées ?",
    "a6": "Recall est un projet open-source entièrement gratuit sous licence MIT, développé par REVR pour la communauté DJ. Toutes les fonctionnalités sont disponibles sans aucune restriction.",
    
    // Legal Section
    "legal-tag": "Transparence & Conformité",
    "legal-title": "Mentions Légales & Marques Déposées",
    "legal-subtitle": "Déclaration d'indépendance, propriété intellectuelle et respect absolu de la vie privée.",
    "legal-col1-title": "Éditeur & Hébergement",
    "legal-col1-text": "Le logiciel Recall et ce site web sont édités en tant que projet open-source indépendant développé par <strong>REVR</strong> pour la communauté DJ. Code source sous licence libre MIT.<br><strong>Hébergement :</strong> GitHub Pages (GitHub Inc., 88 Colin P Kelly Jr St, San Francisco, CA 94107, USA).",
    "legal-col2-title": "Clause de Non-Affiliation (Fair Use)",
    "legal-col2-text": "<strong>Serato Limited :</strong> <em>Serato</em>, <em>Serato DJ</em>, <em>Serato DJ Pro</em> sont des marques déposées de Serato Limited.<br><strong>AlphaTheta Corporation :</strong> <em>Rekordbox</em>, <em>Pioneer DJ</em> sont des marques déposées d'AlphaTheta Corporation.<br>Recall est un utilitaire tiers indépendant. Recall n'est en aucun cas affilié, sponsorisé, approuvé ou certifié par Serato Limited ou AlphaTheta Corporation. L'usage de ces noms est fait à titre strictement descriptif (<em>Nominative Fair Use</em>).",
    "legal-col3-title": "Protection de la Vie Privée (100% Offline)",
    "legal-col3-text": "Recall ne collecte <strong>aucune donnée personnelle</strong>, ne dispose d'aucun traceur publicitaire et n'utilise aucun serveur distant. Votre collection musicale, vos historiques et vos réglages demeurent exclusivement stockés en local sur votre ordinateur.",
    
    "legal-highlight": "<strong>Engagement Open Source & Transparence :</strong> Le code source complet de Recall pour macOS et Windows est auditable publiquement sur notre dépôt GitHub. Vous pouvez vérifier par vous-même l'absence totale d'appels réseau, de cookies, ou de télémétrie cachée.",

    // General & Meta
    "lang-label": "Langue :",
    "page-title": "Recall — Le Copilote Intelligent Hors-Ligne pour DJs Serato & Rekordbox",
    "page-desc": "Recall est le compagnon DJ open-source 100% hors-ligne pour macOS et Windows. Rallumez vos meilleures transitions historiques, mixez harmoniquement en roue Camelot et glissez vos morceaux directement dans Serato DJ Pro ou Pioneer DJ Rekordbox.",
    "sim-key-relative": "Relatif",
    "sim-key-boost": "Boost",
    
    // Footer
    "footer-desc": "Compagnon intelligent hors-ligne pour Serato DJ Pro & Pioneer DJ Rekordbox.",
    "footer-rights": "Tous droits réservés. Développé avec passion pour les DJs.",
    "footer-github-link": "Dépôt GitHub"
  },
  
  en: {
    // Nav
    "nav-features": "Features",
    "nav-demo": "Live Demo",
    "nav-compatibility": "Compatibility",
    "nav-problem": "Why Recall?",
    "nav-download": "Download",
    "nav-faq": "FAQ",
    "nav-legal": "Legal Notice",
    "nav-cta-download": "Download v1.0",
    
    // Hero
    "hero-pill-badge": "NEW",
    "hero-pill-text": "Independent & 100% Offline DJ Companion",
    "hero-title-part1": "Never lose track",
    "hero-title-part2": "of your best mixes.",
    "hero-subtitle": "The smart DJ copilot that mines your Serato & Rekordbox history to instantly recommend proven routines and Camelot harmonic transitions in live sets.",
    "hero-btn-mac": "Download for macOS",
    "hero-btn-win": "Download for Windows",
    "hero-btn-github": "GitHub Source Code",
    "trust-offline": "100% Offline (No Wi-Fi needed)",
    "trust-cpu": "0% Idle CPU (< 25 MB RAM)",
    "trust-safe": "Read-Only (Zero crash risk)",
    "trust-free": "Free & Open-Source",
    
    // Showcase & Real App Simulator
    "showcase-sim-title": "Recall 1.0 — Live Interactive App Simulator",
    "sim-mode-floating": "Floating View",
    "sim-mode-compact": "Compact Bar (78 px)",
    "sim-status-active": "Active monitoring (1.5s)",
    "sim-settings-heading": "Recall Settings",
    "sim-sett-dj-label": "Active DJ Software",
    "sim-sett-key-label": "Harmonic Key Format",
    "sim-sett-bpm-label": "Tempo Tolerance (BPM)",
    "sim-sett-opt-label": "Display Options",
    "sim-sett-always-top": "Always on top (Floating Window)",
    "sim-sett-hide-played": "Hide tracks already played in session",
    "sim-sett-save": "Save and close",
    "sim-app-reduce": "Collapse",
    "sim-guide-title": "Harmonic Keys & Routines Guide",
    "sim-g1": "Same harmonic key. Flawless transition.",
    "sim-g2": "Energy down (-1) or energy up (+1).",
    "sim-g3": "Major / Minor toggle (A ↔ B) without pitch clash.",
    "sim-g4": "Peak time energy boost (+2h).",
    "sim-g5": "Times you have played this transition live.",
    "sim-now-playing-label": "NOW PLAYING",
    "sim-save-combo-text": "Save this combo",
    "sim-filter-bpm": "BPM ±10%",
    "sim-filter-harm": "Harmony",
    "sim-filter-favs": "Favs",
    "sim-matches-label": "matches",
    "sim-compact-expand": "Expand",
    "sim-interactive-hint": "Live interactive simulation: click any track to transition, filter by BPM and harmony, or open settings (⚙️) to test the dimmed backdrop and key format.",
    
    // Problem Section
    "problem-tag": "The Club DJ Dilemma",
    "problem-title": "Why do your greatest mixes get forgotten?",
    "problem-subtitle": "During a high-energy 3-hour set at 128 BPM, a DJ's working memory is pushed to the limit. Recall watches your decks and sparks your best ideas without getting in your way.",
    "p1-title": "The brain fade 30 seconds before track end",
    "p1-desc": "The outro is ticking down. You frantically search through 10,000 files for a killer transition you played months ago, but the exact track name slips your mind.",
    "p2-title": "Untapped gig logs and playlists",
    "p2-desc": "Your DJ software logs thousands of past performances in dormant SQLite databases. Traditional tools never tap into this goldmine of your own proven routines.",
    "p3-title": "The trap of online streaming algorithms",
    "p3-desc": "Generic streaming algorithms don't know your crowd, don't understand transition energy, and fail completely in underground basement club booths with zero reception.",
    
    // Simulator Section
    "sim-tag": "Interactive Simulator",
    "sim-title": "Experience Recall's recommendation engine",
    "sim-subtitle": "Pick a track or choose a Camelot key and BPM to see how Recall combines your past routines with harmonic compatibility in real-time.",
    "sim-label-track": "1. Pick a currently playing track:",
    "sim-label-bpm": "2. Live Tempo (BPM):",
    "sim-now-playing-badge": "Active Deck (Now Playing)",
    "sim-suggestions-badge": "Computed Matches (Top Routines & Keys)",
    
    // Bento Features
    "features-tag": "Key Features",
    "features-title": "Engineered by and for performing DJs",
    "features-subtitle": "Every design choice in Recall ensures minimal footprint and zero distraction during your set.",
    "f1-title": "Smart Historical Routine Mining",
    "f1-desc": "Recall digs into your past Serato (`master.sqlite`) and Rekordbox XML databases to identify your most played transitions. Flame badges 🔥 7x instantly surface your favorite routines.",
    "f1-badge": "20,000+ transitions indexed",
    "f2-title": "Camelot Wheel Harmonic Mixing",
    "f2-desc": "Every suggestion displays exact Camelot keys, adjacent keys (+1/-1 hr), relative major/minor, or +2 energy boost keys for harmonious blends without clashing frequencies.",
    "f2-badge": "Supports Classic & Musical Key modes",
    "f3-title": "Direct Drag & Drop",
    "f3-desc": "Grab any suggested track right out of Recall and drag it onto Deck 1, Deck 2, or your crates in Serato and Rekordbox. No tedious searching.",
    "f3-badge": "macOS & Windows Native",
    "f4-title": "Ultra-Slim Compact Dock (78 px)",
    "f4-desc": "Shrink Recall with one click into a sleek 78 px floating bar docked at the bottom-right of your screen, keeping 100% of your DJ waveform visibility.",
    "f4-badge": "Always-On-Top floating window",
    "f5-title": "Instant Auto-Detection (< 0.1 ms)",
    "f5-desc": "Recall detects whether Serato DJ Pro or Rekordbox is running and switches automatically. Virtually 0% CPU consumption.",
    "f5-badge": "Zero audio latency impact",
    "f6-title": "100% Offline & Absolute Privacy",
    "f6-desc": "No user account, no tracking telemetry, no Internet access required. Recall only reads local databases without ever modifying your files.",
    "f6-badge": "100% Local & Sandboxed",
    
    // Compatibility Section
    "compat-tag": "Ecosystem",
    "compat-title": "Software & Hardware Compatibility",
    "compat-subtitle": "Built in native Swift for macOS and modern C# / .NET 8 for Windows.",
    "compat-serato-title": "Serato DJ Pro",
    "compat-serato-ver": "v2.5, v3.0, v3.1, v3.2+",
    "compat-serato-1": "Real-time deck monitoring via WAL SQLite database",
    "compat-serato-2": "Instant deck change detection (< 1s)",
    "compat-serato-3": "Native drag and drop to decks and crates",
    "compat-serato-4": "100% read-only access without altering Serato data",
    
    "compat-rekordbox-title": "Pioneer DJ Rekordbox",
    "compat-rekordbox-ver": "v6.x & v7.x",
    "compat-rekordbox-1": "High-performance Rekordbox XML bridge parser",
    "compat-rekordbox-2": "Parses 15,000+ tracks & playlists in 0.45s",
    "compat-rekordbox-3": "Sub-millisecond harmonic & BPM matching",
    "compat-rekordbox-4": "Direct drag and drop to Rekordbox decks",
    
    // Comparison Table
    "table-col-feature": "Feature",
    "table-col-recall": "Recall Copilot",
    "table-col-spotify": "Streaming Algorithms",
    "table-col-notes": "Paper Notes / Fixed Crates",
    "row1-name": "Trained on YOUR actual past routines",
    "row1-val-recall": "✅ YES (Local History)",
    "row1-val-spotify": "❌ No (Generic)",
    "row1-val-notes": "🟡 Partial (Human Memory)",
    "row2-name": "Works with zero Internet (Club / Basement)",
    "row2-val-recall": "✅ 100% Offline",
    "row2-val-spotify": "❌ Requires Internet",
    "row2-val-notes": "✅ Yes",
    "row3-name": "Real-time Camelot harmonic wheel matches",
    "row3-val-recall": "✅ Automatic & Ranked",
    "row3-val-spotify": "❌ No",
    "row3-val-notes": "❌ Manual mental calculation",
    "row4-name": "Direct drag & drop into DJ decks",
    "row4-val-recall": "✅ Direct into Decks",
    "row4-val-spotify": "❌ No",
    "row4-val-notes": "❌ No",
    "row5-name": "RAM & CPU footprint",
    "row5-recall": "< 25 MB / 0% CPU",
    "row5-spotify": "> 400 MB + Internet",
    "row5-notes": "0 MB (Static & rigid)",
    
    // Downloads
    "dl-tag": "Free Download",
    "dl-title": "Get Recall for your DJ machine",
    "dl-subtitle": "Download the official v1.0.0 release for macOS or Windows. No sign-up required, install and mix.",
    "dl-mac-title": "macOS",
    "dl-mac-specs": "macOS 12.0+ Monterey, Ventura, Sonoma, Sequoia (Universal Apple Silicon M1-M4 & Intel)",
    "dl-mac-btn": "Download Recall.dmg",
    "dl-mac-zip": "Download as .zip",
    "dl-win-title": "Windows",
    "dl-win-specs": "Windows 10 & 11 (64-bit x64, .NET 8 WPF)",
    "dl-win-btn": "Download Recall-Windows.zip",
    "dl-win-exe": "Self-contained executable ready to run",
    "dl-github-note": "Explore official releases and source code on ",
    
    // FAQ
    "faq-tag": "Frequently Asked Questions",
    "faq-title": "Everything you need to know before gigging with Recall",
    "q1": "Can Recall cause Serato or Rekordbox to freeze or crash during a set?",
    "a1": "Absolutely not. Recall operates in a completely isolated, independent process. It accesses Serato and Rekordbox databases in strict **read-only** mode, never locking or modifying files in use by your DJ software.",
    "q2": "Does Recall alter my audio files, ID3 tags, or crates?",
    "a2": "No, never. Recall never writes a single byte to your MP3, FLAC, or WAV files, nor does it touch your configuration files. Your musical library remains 100% untouched.",
    "q3": "Do I need an Internet connection during a gig?",
    "a3": "No! Recall is built specifically for real-world club booths, basements, and festival stages where Wi-Fi or mobile data is nonexistent. It is 100% local and offline.",
    "q4": "How does automatic detection between Serato and Rekordbox work?",
    "a4": "Recall inspects running application processes once every 1.5 seconds (< 0.1 ms CPU execution time). If Rekordbox is open, Recall queries Rekordbox. If Serato is open, it listens to Serato decks. You can also manually lock your software preference in Settings.",
    "q5": "How do I import my Rekordbox collection into Recall?",
    "a5": "In Rekordbox, simply right-click your Collection > 'Export Collection in XML format'. Recall automatically finds this file in your Documents folder. You can also select a custom location in Recall Settings.",
    "q6": "Is it completely free? Are there any subscriptions or locked features?",
    "a6": "Recall is a 100% free open-source project published under the MIT license by REVR for the DJ community. All features are fully unlocked without restrictions.",
    
    // Legal Section
    "legal-tag": "Transparency & Compliance",
    "legal-title": "Legal Notice & Trademarks",
    "legal-subtitle": "Non-affiliation disclaimer, intellectual property, and absolute commitment to offline privacy.",
    "legal-col1-title": "Publisher & Hosting",
    "legal-col1-text": "The Recall software and this website are published as an independent open-source project created by <strong>REVR</strong> for the DJ community. Source code released under the MIT License.<br><strong>Hosting:</strong> GitHub Pages (GitHub Inc., 88 Colin P Kelly Jr St, San Francisco, CA 94107, USA).",
    "legal-col2-title": "Non-Affiliation Disclaimer (Nominative Fair Use)",
    "legal-col2-text": "<strong>Serato Limited:</strong> <em>Serato</em>, <em>Serato DJ</em>, <em>Serato DJ Pro</em> are registered trademarks of Serato Limited.<br><strong>AlphaTheta Corporation:</strong> <em>Rekordbox</em>, <em>Pioneer DJ</em> are registered trademarks of AlphaTheta Corporation.<br>Recall is an independent third-party companion. Recall is not affiliated, sponsored, endorsed, or certified by Serato Limited or AlphaTheta Corporation. All trademark mentions are purely descriptive (<em>Nominative Fair Use</em>).",
    "legal-col3-title": "Privacy & 100% Offline Commitment",
    "legal-col3-text": "Recall collects <strong>zero personal data</strong>, includes no tracking cookies or telemetry, and connects to no external remote servers. Your music library, gig history, and user settings stay strictly local on your computer.",
    
    "legal-highlight": "<strong>Open-Source Transparency Commitment:</strong> The complete source code of Recall for macOS and Windows is publicly auditable on our GitHub repository. You can verify for yourself the complete absence of network calls, cookies, or telemetry.",

    // General & Meta
    "lang-label": "Language:",
    "page-title": "Recall — Smart Offline DJ Memory Copilot for Serato & Rekordbox",
    "page-desc": "Recall is an independent 100% offline open-source DJ companion for macOS and Windows. Spark your best historical routines, mix harmonically on the Camelot wheel, and drag & drop tracks directly into Serato DJ Pro or Rekordbox.",
    "sim-key-relative": "Relative",
    "sim-key-boost": "Boost",
    
    // Footer
    "footer-desc": "Smart offline memory copilot for Serato DJ Pro & Pioneer DJ Rekordbox.",
    "footer-rights": "All rights reserved. Built with passion for DJs worldwide.",
    "footer-github-link": "GitHub Repository"
  }
};

// --- Clean Library of Tracks for Simulation (Strictly NO Remix Names) ---
const cleanTracks = [
  { id: "rudeboy", title: "Rude Boy", artist: "Rihanna", bpm: 102, key: "8A", musical: "Am" },
  { id: "crazyluv", title: "Crazy in Love", artist: "Beyoncé", bpm: 104, key: "7A", musical: "Dm" },
  { id: "woman", title: "Woman", artist: "Doja Cat", bpm: 108, key: "8A", musical: "Am" },
  { id: "levitating", title: "Levitating", artist: "Dua Lipa", bpm: 103, key: "7A", musical: "Dm" },
  { id: "essence", title: "Essence", artist: "Wizkid", bpm: 104, key: "8A", musical: "Am" },
  { id: "onthelow", title: "On the Low", artist: "Burna Boy", bpm: 100, key: "9A", musical: "Em" },
  { id: "djadja", title: "Djadja", artist: "Aya Nakamura", bpm: 98, key: "8A", musical: "Am" },
  { id: "allthestars", title: "All The Stars", artist: "Kendrick Lamar & SZA", bpm: 97, key: "8A", musical: "Am" },
  { id: "onedance", title: "One Dance", artist: "Drake", bpm: 104, key: "12A", musical: "Dbm" },
  { id: "wannabe", title: "Wannabe", artist: "Spice Girls", bpm: 107, key: "1B", musical: "B" },
  { id: "calmdown", title: "Calm Down", artist: "Rema", bpm: 107, key: "11B", musical: "A" },
  { id: "rush", title: "Rush", artist: "Ayra Starr", bpm: 100, key: "12B", musical: "E" },
  { id: "lastlast", title: "Last Last", artist: "Burna Boy", bpm: 98, key: "4A", musical: "Fm" },
  { id: "lovenwantiti", title: "Love Nwantiti", artist: "CKay", bpm: 93, key: "11A", musical: "F#m" },
  { id: "pookie", title: "Pookie", artist: "Aya Nakamura", bpm: 100, key: "5A", musical: "Cm" },
  { id: "water", title: "Water", artist: "Tyla", bpm: 117, key: "1A", musical: "G#m" },
  { id: "shapeofyou", title: "Shape of You", artist: "Ed Sheeran", bpm: 96, key: "1A", musical: "G#m" },
  { id: "blinding", title: "Blinding Lights", artist: "The Weeknd", bpm: 171, key: "1A", musical: "G#m" },
  { id: "asitwas", title: "As It Was", artist: "Harry Styles", bpm: 174, key: "9B", musical: "G" },
  { id: "getlucky", title: "Get Lucky", artist: "Daft Punk", bpm: 116, key: "6A", musical: "Gm" },
  { id: "flowers", title: "Flowers", artist: "Miley Cyrus", bpm: 118, key: "8A", musical: "Am" },
  { id: "badguy", title: "Bad Guy", artist: "Billie Eilish", bpm: 135, key: "8A", musical: "Am" },
  { id: "magic", title: "24K Magic", artist: "Bruno Mars", bpm: 107, key: "1A", musical: "G#m" },
  { id: "despecha", title: "Despechá", artist: "Rosalía", bpm: 130, key: "9B", musical: "G" }
];

// Curated routine transition histories (play counts for verified routines)
const routinePairs = {
  "rudeboy": { "crazyluv": 7, "woman": 6, "levitating": 5, "essence": 4, "onthelow": 4, "djadja": 3, "allthestars": 3, "onedance": 4, "rush": 3, "wannabe": 2 },
  "crazyluv": { "levitating": 8, "rudeboy": 6, "woman": 5, "onedance": 5, "essence": 4, "magic": 3 },
  "woman": { "rudeboy": 7, "crazyluv": 6, "levitating": 5, "essence": 5, "onthelow": 4, "djadja": 3 },
  "levitating": { "crazyluv": 8, "woman": 6, "onedance": 6, "rudeboy": 5, "calmdown": 4 },
  "essence": { "rudeboy": 6, "woman": 5, "onedance": 5, "crazyluv": 4, "calmdown": 3 },
  "onthelow": { "rudeboy": 6, "rush": 5, "essence": 4, "lastlast": 4, "djadja": 3 },
  "djadja": { "pookie": 7, "rudeboy": 5, "woman": 4, "onthelow": 3 },
  "allthestars": { "rudeboy": 5, "essence": 4, "woman": 3, "blinding": 3 },
  "onedance": { "crazyluv": 6, "rush": 5, "essence": 5, "calmdown": 4, "levitating": 3 },
  "wannabe": { "rudeboy": 7, "calmdown": 5, "pookie": 4, "magic": 3 },
  "calmdown": { "rush": 7, "wannabe": 5, "onedance": 4, "lovenwantiti": 4 },
  "rush": { "lastlast": 8, "lovenwantiti": 6, "calmdown": 5, "rudeboy": 4 },
  "lastlast": { "rush": 8, "lovenwantiti": 5, "pookie": 4 },
  "lovenwantiti": { "rush": 7, "calmdown": 5, "lastlast": 4, "water": 3 },
  "pookie": { "djadja": 7, "rudeboy": 5, "lastlast": 4, "wannabe": 3 },
  "water": { "getlucky": 6, "flowers": 5, "magic": 4, "blinding": 3 },
  "shapeofyou": { "blinding": 6, "asitwas": 5, "getlucky": 3 },
  "blinding": { "asitwas": 8, "water": 5, "shapeofyou": 4, "getlucky": 3 },
  "asitwas": { "blinding": 8, "despecha": 4, "flowers": 3 },
  "getlucky": { "flowers": 7, "water": 5, "magic": 4, "blinding": 3 },
  "flowers": { "getlucky": 7, "badguy": 4, "asitwas": 3 },
  "badguy": { "flowers": 5, "despecha": 4, "rudeboy": 3 },
  "magic": { "crazyluv": 5, "getlucky": 4, "water": 4, "wannabe": 3 },
  "despecha": { "asitwas": 5, "badguy": 4, "calmdown": 3 }
};

// Camelot Key Colors matching Recall app
const camelotColors = {
  "1A": "#00E5FF", "1B": "#00E5FF",
  "2A": "#00B0FF", "2B": "#00B0FF",
  "3A": "#2979FF", "3B": "#2979FF",
  "4A": "#651FFF", "4B": "#651FFF",
  "5A": "#D500F9", "5B": "#D500F9",
  "6A": "#F50057", "6B": "#F50057",
  "7A": "#FF1744", "7B": "#FF1744",
  "8A": "#FF5722", "8B": "#FF5722",
  "9A": "#FF9100", "9B": "#FF9100",
  "10A": "#FFEA00", "10B": "#FFEA00",
  "11A": "#76FF03", "11B": "#76FF03",
  "12A": "#00E676", "12B": "#00E676"
};


// --- State & Device Language Detection ---
function getInitialLanguage() {
  // 1. Check if user previously made an explicit choice
  const saved = localStorage.getItem("recall_lang");
  if (saved === "fr" || saved === "en") {
    return saved;
  }

  // 2. Check browser / device languages list
  const navLangs = (navigator.languages && navigator.languages.length)
    ? navigator.languages
    : [navigator.language || navigator.userLanguage || ""];

  for (const l of navLangs) {
    if (!l) continue;
    const clean = l.toLowerCase();
    if (clean.startsWith("fr")) return "fr";
    if (clean.startsWith("en")) return "en";
  }

  // 3. Fallback based on primary navigator language
  const primary = (navigator.language || navigator.userLanguage || "").toLowerCase();
  if (primary.startsWith("fr")) return "fr";

  // Default to English for international visitors
  return "en";
}

let currentLang = getInitialLanguage();
let updateSimulationFn = null;

// --- DOM Initializer ---
document.addEventListener("DOMContentLoaded", () => {
  initLanguage();
  initMobileMenu();
  initNavbarScroll();
  initRecallAppSimulator();
  initFAQ();
});

// --- Language Switching ---
function initLanguage() {
  setLanguage(currentLang);

  // Desktop buttons
  const frBtn = document.getElementById("lang-fr");
  const enBtn = document.getElementById("lang-en");
  if (frBtn) frBtn.addEventListener("click", () => setLanguage("fr"));
  if (enBtn) enBtn.addEventListener("click", () => setLanguage("en"));

  // Mobile buttons
  const frMob = document.getElementById("lang-fr-mobile");
  const enMob = document.getElementById("lang-en-mobile");
  if (frMob) frMob.addEventListener("click", () => setLanguage("fr"));
  if (enMob) enMob.addEventListener("click", () => setLanguage("en"));
}

function setLanguage(lang) {
  currentLang = (lang === "en") ? "en" : "fr";
  localStorage.setItem("recall_lang", currentLang);

  const dict = translations[currentLang] || translations["fr"];

  document.querySelectorAll("[data-i18n]").forEach(el => {
    const key = el.getAttribute("data-i18n");
    if (dict[key]) {
      el.innerHTML = dict[key];
    }
  });

  // Update page title and description
  if (dict["page-title"]) {
    document.title = dict["page-title"];
  }
  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc && dict["page-desc"]) {
    metaDesc.setAttribute("content", dict["page-desc"]);
  }

  // Update button active state on desktop and mobile
  document.querySelectorAll(".lang-btn").forEach(btn => btn.classList.remove("active"));
  const activeDesktopBtn = document.getElementById(`lang-${currentLang}`);
  if (activeDesktopBtn) activeDesktopBtn.classList.add("active");
  const activeMobileBtn = document.getElementById(`lang-${currentLang}-mobile`);
  if (activeMobileBtn) activeMobileBtn.classList.add("active");

  document.documentElement.lang = currentLang;

  // Refresh simulator labels
  if (typeof updateSimulationFn === "function") {
    updateSimulationFn();
  }
}

// --- Mobile Navigation Menu Drawer ---
function initMobileMenu() {
  const toggleBtn = document.getElementById("mobile-menu-toggle");
  const closeBtn = document.getElementById("mobile-nav-close");
  const drawer = document.getElementById("mobile-nav-drawer");
  const backdrop = document.getElementById("mobile-nav-backdrop");
  const mobileLinks = document.querySelectorAll(".mobile-nav-link, .mobile-cta");

  if (!toggleBtn || !drawer || !backdrop) return;

  function openMenu() {
    drawer.classList.add("open");
    backdrop.classList.add("open");
    toggleBtn.classList.add("active");
    toggleBtn.setAttribute("aria-expanded", "true");
    drawer.setAttribute("aria-hidden", "false");
    document.body.style.overflow = "hidden";
  }

  function closeMenu() {
    drawer.classList.remove("open");
    backdrop.classList.remove("open");
    toggleBtn.classList.remove("active");
    toggleBtn.setAttribute("aria-expanded", "false");
    drawer.setAttribute("aria-hidden", "true");
    document.body.style.overflow = "";
  }

  toggleBtn.addEventListener("click", () => {
    if (drawer.classList.contains("open")) {
      closeMenu();
    } else {
      openMenu();
    }
  });

  if (closeBtn) closeBtn.addEventListener("click", closeMenu);
  backdrop.addEventListener("click", closeMenu);

  mobileLinks.forEach(link => {
    link.addEventListener("click", () => {
      closeMenu();
    });
  });
}

// --- Navbar Blur on Scroll ---
function initNavbarScroll() {
  const navbar = document.querySelector(".navbar");
  if (!navbar) return;

  window.addEventListener("scroll", () => {
    if (window.scrollY > 25) {
      navbar.classList.add("scrolled");
    } else {
      navbar.classList.remove("scrolled");
    }
  });
}

// --- Live Interactive Recall App Simulator ---
function initRecallAppSimulator() {
  const container = document.getElementById("recall-sim-container");
  if (!container) return;

  // Simulator State
  let currentTrack = cleanTracks[0]; // "Rude Boy" - Rihanna
  let deck1Track = cleanTracks[0];
  let deck2Track = cleanTracks[1];
  let activeDeck = "auto";
  let keyDisplayMode = 0; // 0: Camelot, 1: Musicale, 2: Combiné
  let bpmTolerancePercent = 10;
  let activeSoftware = "serato";
  let isCompact = false;
  let isBpmFilterActive = true;
  let isHarmonicFilterActive = true;
  let isFavoritesFilterActive = false;
  let hidePlayedTracks = false;
  let alwaysOnTop = true;
  let toastTimer = null;

  const playedTrackIds = new Set([cleanTracks[0].id]);
  const favoriteCombos = new Set(["rudeboy:crazyluv", "crazyluv:levitating"]);

  // Toast Feedback Helper
  function showToast(message, icon = "✨") {
    const toast = document.getElementById("sim-toast");
    const toastIcon = document.getElementById("sim-toast-icon");
    const toastMsg = document.getElementById("sim-toast-msg");
    if (!toast || !toastMsg) return;

    if (toastTimer) clearTimeout(toastTimer);
    if (toastIcon) toastIcon.textContent = icon;
    toastMsg.textContent = message;

    toast.classList.add("show");
    toastTimer = setTimeout(() => {
      toast.classList.remove("show");
    }, 2400);
  }

  // Format key label based on user key format setting
  function formatKey(track) {
    if (!track) return "";
    if (keyDisplayMode === 1) return track.musical;
    if (keyDisplayMode === 2) return `${track.key} · ${track.musical}`;
    return track.key;
  }

  function getKeyColor(key) {
    return camelotColors[key] || "#00E5FF";
  }

  // Calculate Camelot Harmonic Relationship
  function calculateHarmonicRelation(sourceKey, targetKey) {
    const sNum = parseInt(sourceKey, 10);
    const sLet = sourceKey.slice(-1).toUpperCase();
    const tNum = parseInt(targetKey, 10);
    const tLet = targetKey.slice(-1).toUpperCase();

    const isEn = currentLang === "en";

    if (sourceKey === targetKey) {
      return { type: "exact", score: 100, label: isEn ? "Exact match" : "Harmonie exacte", tag: isEn ? "Exact" : "Exacte" };
    }
    if (sNum === tNum && sLet !== tLet) {
      return { type: "relative", score: 85, label: isEn ? "Relative Major/Minor" : "Relatif Maj/Min", tag: isEn ? "Relative" : "Relatif" };
    }
    if (sLet === tLet) {
      const diff = (tNum - sNum + 12) % 12;
      if (diff === 1) return { type: "energy_up", score: 90, label: isEn ? "Energy +1" : "Énergie +1", tag: isEn ? "Energy +1" : "Énergie +1" };
      if (diff === 11) return { type: "energy_down", score: 90, label: isEn ? "Energy -1" : "Énergie -1", tag: isEn ? "Energy -1" : "Énergie -1" };
      if (diff === 2) return { type: "boost", score: 75, label: isEn ? "Energy Boost (+2)" : "Boost d'énergie (+2)", tag: "Boost +2" };
    }
    if (sLet !== tLet) {
      const diff = (tNum - sNum + 12) % 12;
      if (diff === 1 || diff === 11) {
        return { type: "compatible", score: 70, label: isEn ? "Compatible Relative" : "Voisin Relatif", tag: isEn ? "Compatible" : "Compatible" };
      }
    }
    return { type: "out_of_key", score: 25, label: isEn ? "Out of key" : "Hors clé", tag: isEn ? "Off" : "Hors clé" };
  }

  // Check BPM tolerance including half and double tempo
  function isBpmCompatible(baseBpm, targetBpm, tolerancePercent) {
    const tol = tolerancePercent / 100.0;
    if (Math.abs((targetBpm / baseBpm) - 1.0) <= tol) return true;
    if (Math.abs(((targetBpm / 2.0) / baseBpm) - 1.0) <= tol) return true;
    if (Math.abs(((targetBpm * 2.0) / baseBpm) - 1.0) <= tol) return true;
    return false;
  }

  // Calculate and sort suggestion matches for current track
  function computeMatches() {
    const current = currentTrack;
    const history = routinePairs[current.id] || {};
    let candidates = cleanTracks.filter(t => t.id !== current.id);

    if (hidePlayedTracks) {
      candidates = candidates.filter(t => !playedTrackIds.has(t.id));
    }

    const scored = candidates.map(t => {
      const rel = calculateHarmonicRelation(current.key, t.key);
      const flameCount = history[t.id] || 0;
      const isFav = favoriteCombos.has(`${current.id}:${t.id}`) || favoriteCombos.has(`${t.id}:${current.id}`);
      const bpmDiff = t.bpm - current.bpm;
      const bpmCompatible = isBpmCompatible(current.bpm, t.bpm, bpmTolerancePercent);
      const harmonicCompatible = rel.type !== "out_of_key";

      let finalScore = (flameCount * 30) + rel.score;
      if (Math.abs(bpmDiff) <= 5) finalScore += 15;
      if (isFav) finalScore += 35;

      return {
        track: t,
        relation: rel,
        flame: flameCount,
        isFav: isFav,
        bpmDiff: bpmDiff,
        bpmCompatible: bpmCompatible,
        harmonicCompatible: harmonicCompatible,
        score: finalScore
      };
    });

    let filtered = scored;
    if (isBpmFilterActive) {
      filtered = filtered.filter(item => item.bpmCompatible);
    }
    if (isHarmonicFilterActive) {
      filtered = filtered.filter(item => item.harmonicCompatible);
    }
    if (isFavoritesFilterActive) {
      filtered = filtered.filter(item => item.isFav);
    }

    filtered.sort((a, b) => b.score - a.score);
    return filtered;
  }

  // Render Full Application UI
  function renderApp() {
    // 1. Now Playing Card
    const currentTitleEl = document.getElementById("sim-current-title");
    const currentArtistEl = document.getElementById("sim-current-artist");
    const currentKeyEl = document.getElementById("sim-current-key-badge");
    const currentBpmEl = document.getElementById("sim-current-bpm-badge");
    const vinylCenter = document.getElementById("sim-vinyl-center");
    const softBadge = document.getElementById("sim-np-soft-badge");
    const favBtn = document.getElementById("sim-current-fav-btn");
    const sessionCountEl = document.getElementById("sim-session-count");

    if (currentTitleEl) currentTitleEl.textContent = currentTrack.title;
    if (currentArtistEl) currentArtistEl.textContent = currentTrack.artist;
    if (currentKeyEl) {
      currentKeyEl.textContent = formatKey(currentTrack);
      currentKeyEl.style.backgroundColor = getKeyColor(currentTrack.key);
    }
    if (currentBpmEl) currentBpmEl.textContent = `${currentTrack.bpm} BPM`;
    if (vinylCenter) {
      vinylCenter.style.backgroundColor = getKeyColor(currentTrack.key);
      vinylCenter.style.boxShadow = `0 0 8px ${getKeyColor(currentTrack.key)}`;
    }
    if (softBadge) softBadge.textContent = activeSoftware.toUpperCase();
    if (sessionCountEl) sessionCountEl.textContent = `${35 + playedTrackIds.size}`;

    // Active deck pill highlight
    document.querySelectorAll(".np-deck-btn").forEach(btn => {
      btn.classList.toggle("active", btn.getAttribute("data-deck") === activeDeck);
    });

    // Favorite heart on Now Playing
    const isComboFav = Array.from(favoriteCombos).some(k => k.startsWith(`${currentTrack.id}:`) || k.endsWith(`:${currentTrack.id}`));
    if (favBtn) {
      favBtn.textContent = isComboFav ? "♥" : "♡";
      favBtn.classList.toggle("active", isComboFav);
    }

    // 2. Suggestions List
    const matches = computeMatches();
    const countNumEl = document.getElementById("sim-matches-num");
    const countLblEl = document.getElementById("sim-matches-label");
    const containerEl = document.getElementById("sim-suggestions-container");

    if (countNumEl) countNumEl.textContent = matches.length;
    if (countLblEl) countLblEl.textContent = currentLang === "en" ? (matches.length > 1 ? "matches" : "match") : (matches.length > 1 ? "matchs" : "match");

    if (containerEl) {
      containerEl.innerHTML = "";
      if (matches.length === 0) {
        containerEl.innerHTML = `
          <div style="padding: 24px 12px; text-align: center; color: var(--text-muted); font-size: 0.78rem;">
            ${currentLang === "en" ? "No tracks match your current filters. Try relaxing BPM or Harmonic filter." : "Aucun titre ne correspond à ces filtres. Essayez d'élargir le tempo ou l'harmonie."}
          </div>
        `;
      } else {
        matches.forEach((item, index) => {
          const t = item.track;
          const card = document.createElement("div");
          card.className = "sim-track-card";
          card.setAttribute("role", "listitem");
          card.setAttribute("tabindex", "0");

          const offsetStr = item.bpmDiff >= 0 ? `+${item.bpmDiff}` : `${item.bpmDiff}`;
          const isPlayed = playedTrackIds.has(t.id);

          card.innerHTML = `
            <div class="sim-track-left">
              <span class="sim-track-rank">#${index + 1}</span>
              <div class="sim-track-info">
                <div class="sim-track-title-text" style="${isPlayed ? 'color: rgba(255,255,255,0.55);' : ''}">${t.title}</div>
                <div class="sim-track-artist-text">${t.artist}</div>
              </div>
            </div>
            <div class="sim-track-right">
              ${item.flame > 0 ? `<span class="sim-flame-badge" title="${item.flame} fois joué">🔥 ${item.flame}x</span>` : ''}
              <span class="sim-rel-pill ${item.relation.type}">${item.relation.tag}</span>
              <span class="sim-key-badge mini" style="background-color: ${getKeyColor(t.key)};">${formatKey(t)}</span>
              <span class="sim-bpm-offset">${offsetStr}</span>
              <span class="sim-row-fav ${item.isFav ? 'active' : ''}" data-fav-id="${t.id}" title="Favori">${item.isFav ? '♥' : '♡'}</span>
            </div>
          `;

          // Click on row transitions to this track
          card.addEventListener("click", (e) => {
            if (e.target.classList.contains("sim-row-fav")) {
              e.stopPropagation();
              const comboKey = `${currentTrack.id}:${t.id}`;
              if (favoriteCombos.has(comboKey)) {
                favoriteCombos.delete(comboKey);
                showToast(currentLang === "en" ? "Removed from favorites" : "Retiré des favoris", "💔");
              } else {
                favoriteCombos.add(comboKey);
                showToast(currentLang === "en" ? "Combo saved to favorites!" : "Combo mémorisé dans vos favoris !", "⭐");
              }
              renderApp();
              return;
            }

            transitionToTrack(t);
          });

          containerEl.appendChild(card);
        });
      }
    }

    // 3. Compact Bandeau View
    const topMatch = matches.length > 0 ? matches[0] : null;
    const compactTitle = document.getElementById("sim-compact-title");
    const compactArtist = document.getElementById("sim-compact-artist");
    const compactFlame = document.getElementById("sim-compact-flame");
    const compactKey = document.getElementById("sim-compact-key");
    const compactBpm = document.getElementById("sim-compact-bpm");

    if (topMatch) {
      if (compactTitle) compactTitle.textContent = topMatch.track.title;
      if (compactArtist) compactArtist.textContent = topMatch.track.artist;
      if (compactFlame) compactFlame.textContent = topMatch.flame > 0 ? `🔥 ${topMatch.flame}x` : `✨ Top`;
      if (compactKey) {
        compactKey.textContent = formatKey(topMatch.track);
        compactKey.style.backgroundColor = getKeyColor(topMatch.track.key);
      }
      if (compactBpm) compactBpm.textContent = `${topMatch.track.bpm}`;
    }
  }

  // Load and transition to track
  function transitionToTrack(track) {
    if (activeDeck === "auto") {
      deck2Track = deck1Track;
      deck1Track = track;
      currentTrack = track;
    } else if (activeDeck === "1") {
      deck1Track = track;
      currentTrack = track;
    } else {
      deck2Track = track;
      currentTrack = track;
    }

    playedTrackIds.add(track.id);

    // Spin vinyl animation kick
    const vinyl = document.getElementById("sim-vinyl-disc");
    if (vinyl) {
      vinyl.classList.remove("spinning");
      void vinyl.offsetWidth; // trigger reflow
      vinyl.classList.add("spinning");
    }

    showToast(`${currentLang === "en" ? "Now playing:" : "Morceau chargé :"} ${track.artist} — ${track.title}`, "🎵");
    renderApp();
  }

  // Set View Mode (Floating vs Compact)
  function setCompactMode(compact) {
    isCompact = compact;
    const normalApp = document.getElementById("recall-app-normal");
    const compactApp = document.getElementById("recall-app-compact");
    const btnFloating = document.getElementById("sim-btn-floating");
    const btnCompact = document.getElementById("sim-btn-compact");

    if (isCompact) {
      if (normalApp) normalApp.style.display = "none";
      if (compactApp) compactApp.style.display = "flex";
      if (btnFloating) btnFloating.classList.remove("active");
      if (btnCompact) btnCompact.classList.add("active");
      showToast(currentLang === "en" ? "78px Compact Dock View active" : "Mode Bandeau Compact (78 px) activé", "📏");
    } else {
      if (compactApp) compactApp.style.display = "none";
      if (normalApp) normalApp.style.display = "flex";
      if (btnCompact) btnCompact.classList.remove("active");
      if (btnFloating) btnFloating.classList.add("active");
      showToast(currentLang === "en" ? "Floating Window restored" : "Fenêtre Principale restaurée", "🪟");
    }
  }

  // Top Bar View Switchers
  const btnFloating = document.getElementById("sim-btn-floating");
  const btnCompact = document.getElementById("sim-btn-compact");
  if (btnFloating) btnFloating.addEventListener("click", () => setCompactMode(false));
  if (btnCompact) btnCompact.addEventListener("click", () => setCompactMode(true));

  // In-App Collapse and Expand Buttons
  const appCollapseBtn = document.getElementById("sim-app-collapse");
  const appExpandBtn = document.getElementById("sim-compact-expand");
  if (appCollapseBtn) appCollapseBtn.addEventListener("click", () => setCompactMode(true));
  if (appExpandBtn) appExpandBtn.addEventListener("click", () => setCompactMode(false));

  // Reset Session
  const resetBtn = document.getElementById("sim-app-reset");
  const closeBtn = document.getElementById("sim-app-close");
  function resetSession() {
    playedTrackIds.clear();
    currentTrack = cleanTracks[0];
    deck1Track = cleanTracks[0];
    deck2Track = cleanTracks[1];
    playedTrackIds.add(cleanTracks[0].id);
    showToast(currentLang === "en" ? "New session started! History cleared." : "Nouvelle session lancée ! Morceaux réinitialisés.", "↺");
    renderApp();
  }
  if (resetBtn) resetBtn.addEventListener("click", resetSession);
  if (closeBtn) closeBtn.addEventListener("click", resetSession);

  // Search Drawer
  const searchToggle = document.getElementById("sim-app-search-toggle");
  const searchDrawer = document.getElementById("sim-search-drawer");
  const searchInput = document.getElementById("sim-search-input");
  const searchClear = document.getElementById("sim-search-clear");
  const searchResults = document.getElementById("sim-search-results");

  function renderSearchResults(query = "") {
    if (!searchResults) return;
    searchResults.innerHTML = "";
    const q = query.trim().toLowerCase();
    const filtered = cleanTracks.filter(t => !q || t.title.toLowerCase().includes(q) || t.artist.toLowerCase().includes(q));

    filtered.forEach(t => {
      const item = document.createElement("div");
      item.className = "search-res-item";
      item.innerHTML = `
        <span><strong>${t.title}</strong> — ${t.artist}</span>
        <span class="sim-key-badge mini" style="background-color: ${getKeyColor(t.key)};">${formatKey(t)}</span>
      `;
      item.addEventListener("click", () => {
        transitionToTrack(t);
        if (searchDrawer) searchDrawer.classList.remove("open");
        if (searchInput) searchInput.value = "";
      });
      searchResults.appendChild(item);
    });
  }

  if (searchToggle && searchDrawer) {
    searchToggle.addEventListener("click", () => {
      const isOpen = searchDrawer.classList.toggle("open");
      searchToggle.classList.toggle("active", isOpen);
      if (isOpen) {
        renderSearchResults("");
        if (searchInput) searchInput.focus();
      }
    });
  }

  if (searchInput) {
    searchInput.addEventListener("input", (e) => {
      renderSearchResults(e.target.value);
    });
  }

  if (searchClear && searchInput) {
    searchClear.addEventListener("click", () => {
      searchInput.value = "";
      renderSearchResults("");
    });
  }

  // Guide Drawer
  const guideToggle = document.getElementById("sim-app-guide-toggle");
  const guideDrawer = document.getElementById("sim-guide-drawer");
  const guideClose = document.getElementById("sim-guide-close");

  if (guideToggle && guideDrawer) {
    guideToggle.addEventListener("click", () => {
      const isOpen = guideDrawer.classList.toggle("open");
      guideToggle.classList.toggle("active", isOpen);
    });
  }
  if (guideClose && guideDrawer) {
    guideClose.addEventListener("click", () => {
      guideDrawer.classList.remove("open");
      if (guideToggle) guideToggle.classList.remove("active");
    });
  }

  // Pin Button (Always On Top)
  const pinBtn = document.getElementById("sim-app-pin");
  if (pinBtn) {
    pinBtn.addEventListener("click", () => {
      alwaysOnTop = !alwaysOnTop;
      pinBtn.classList.toggle("active", alwaysOnTop);
      const optCheck = document.getElementById("sim-opt-always-top");
      if (optCheck) optCheck.checked = alwaysOnTop;
      showToast(alwaysOnTop ? (currentLang === "en" ? "Always On Top enabled" : "Premier plan activé") : (currentLang === "en" ? "Always On Top disabled" : "Premier plan désactivé"), "📌");
    });
  }

  // Decks Switcher (AUTO, DECK 1, DECK 2)
  document.querySelectorAll(".np-deck-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      activeDeck = btn.getAttribute("data-deck");
      if (activeDeck === "1") currentTrack = deck1Track;
      if (activeDeck === "2") currentTrack = deck2Track;
      renderApp();
    });
  });

  // Favorite Button & Save Combo Button
  const saveComboBtn = document.getElementById("sim-save-combo-btn");
  if (saveComboBtn) {
    saveComboBtn.addEventListener("click", () => {
      const partner = (activeDeck === "2") ? deck1Track : deck2Track;
      const key = `${currentTrack.id}:${partner.id}`;
      favoriteCombos.add(key);
      showToast(currentLang === "en" ? "Combo saved to favorites!" : "Combo mémorisé dans vos favoris !", "⭐");
      renderApp();
    });
  }

  // Filter Pills (BPM, Harmonie, Favs)
  const pillBpm = document.getElementById("sim-pill-bpm");
  const pillHarm = document.getElementById("sim-pill-harmonic");
  const pillFavs = document.getElementById("sim-pill-favs");

  if (pillBpm) {
    pillBpm.addEventListener("click", () => {
      isBpmFilterActive = !isBpmFilterActive;
      pillBpm.classList.toggle("active", isBpmFilterActive);
      renderApp();
    });
  }

  if (pillHarm) {
    pillHarm.addEventListener("click", () => {
      isHarmonicFilterActive = !isHarmonicFilterActive;
      pillHarm.classList.toggle("active", isHarmonicFilterActive);
      renderApp();
    });
  }

  if (pillFavs) {
    pillFavs.addEventListener("click", () => {
      isFavoritesFilterActive = !isFavoritesFilterActive;
      pillFavs.classList.toggle("active", isFavoritesFilterActive);
      renderApp();
    });
  }

  // Settings Modal with Full-Screen Dimmed Backdrop
  const settingsOverlay = document.getElementById("sim-settings-overlay");
  const settingsOpenNormal = document.getElementById("sim-app-settings-btn");
  const settingsOpenCompact = document.getElementById("sim-compact-settings-btn");
  const settingsCloseBtn = document.getElementById("sim-settings-close");
  const settingsSaveBtn = document.getElementById("sim-settings-save");
  const settingsBackdrop = document.getElementById("sim-settings-backdrop");

  function openSettings() {
    if (!settingsOverlay) return;
    settingsOverlay.classList.add("open");
    settingsOverlay.setAttribute("aria-hidden", "false");
  }

  function closeSettings() {
    if (!settingsOverlay) return;
    settingsOverlay.classList.remove("open");
    settingsOverlay.setAttribute("aria-hidden", "true");
  }

  if (settingsOpenNormal) settingsOpenNormal.addEventListener("click", openSettings);
  if (settingsOpenCompact) settingsOpenCompact.addEventListener("click", openSettings);
  if (settingsCloseBtn) settingsCloseBtn.addEventListener("click", closeSettings);
  if (settingsSaveBtn) settingsSaveBtn.addEventListener("click", () => {
    closeSettings();
    showToast(currentLang === "en" ? "Settings saved!" : "Paramètres enregistrés !", "✅");
  });
  if (settingsBackdrop) settingsBackdrop.addEventListener("click", closeSettings);

  // Keyboard Escape listener
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      if (settingsOverlay && settingsOverlay.classList.contains("open")) {
        closeSettings();
      }
      if (searchDrawer && searchDrawer.classList.contains("open")) {
        searchDrawer.classList.remove("open");
        if (searchToggle) searchToggle.classList.remove("active");
      }
      if (guideDrawer && guideDrawer.classList.contains("open")) {
        guideDrawer.classList.remove("open");
        if (guideToggle) guideToggle.classList.remove("active");
      }
    }
  });

  // Settings: Active DJ Software Toggle
  document.querySelectorAll("[data-sett-dj]").forEach(btn => {
    btn.addEventListener("click", () => {
      document.querySelectorAll("[data-sett-dj]").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      activeSoftware = btn.getAttribute("data-sett-dj");

      const topStatus = document.getElementById("showcase-software-status");
      if (topStatus) {
        topStatus.textContent = activeSoftware === "serato" ? "Serato DJ Pro (WAL)" : "Pioneer Rekordbox (XML)";
      }

      showToast(activeSoftware === "serato" ? "Bascule vers Serato DJ Pro" : "Bascule vers Pioneer Rekordbox", "🎛️");
      renderApp();
    });
  });

  // Settings: Key Format Radio Buttons (Camelot vs Musical vs Combined)
  document.querySelectorAll("[data-sett-key]").forEach(btn => {
    btn.addEventListener("click", () => {
      document.querySelectorAll("[data-sett-key]").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      keyDisplayMode = parseInt(btn.getAttribute("data-sett-key"), 10);

      const modeNames = currentLang === "en" ? ["Camelot (8A)", "Musical (Am)", "Combined (8A · Am)"] : ["Camelot (8A)", "Musicale (Am)", "Combiné (8A · Am)"];
      showToast(`${currentLang === "en" ? "Key format:" : "Format des clés :"} ${modeNames[keyDisplayMode]}`, "🎼");
      renderApp();
    });
  });

  // Settings: BPM Tolerance
  document.querySelectorAll("[data-sett-tol]").forEach(btn => {
    btn.addEventListener("click", () => {
      document.querySelectorAll("[data-sett-tol]").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      bpmTolerancePercent = parseInt(btn.getAttribute("data-sett-tol"), 10);
      showToast(`Tolérance BPM : ±${bpmTolerancePercent}%`, "⚡");
      renderApp();
    });
  });

  // Settings: Checkboxes
  const optAlwaysTop = document.getElementById("sim-opt-always-top");
  if (optAlwaysTop) {
    optAlwaysTop.addEventListener("change", (e) => {
      alwaysOnTop = e.target.checked;
      if (pinBtn) pinBtn.classList.toggle("active", alwaysOnTop);
    });
  }

  const optHidePlayed = document.getElementById("sim-opt-hide-played");
  if (optHidePlayed) {
    optHidePlayed.addEventListener("change", (e) => {
      hidePlayedTracks = e.target.checked;
      renderApp();
    });
  }

  // Language update hook
  updateSimulationFn = renderApp;

  // Initial render
  renderApp();

  // Support direct deep-linking or testing via hash or URL param
  if (window.location.hash === "#compact" || window.location.search.includes("mode=compact")) {
    setCompactMode(true);
  }
  if (window.location.hash === "#settings" || window.location.search.includes("mode=settings")) {
    openSettings();
  }
}

// --- FAQ Accordions ---
function initFAQ() {
  const items = document.querySelectorAll(".faq-item");

  items.forEach(item => {
    const question = item.querySelector(".faq-question");
    const answer = item.querySelector(".faq-answer");

    if (!question || !answer) return;

    question.addEventListener("click", () => {
      const isActive = item.classList.contains("active");

      // Close all
      items.forEach(i => {
        i.classList.remove("active");
        const a = i.querySelector(".faq-answer");
        if (a) a.style.maxHeight = null;
      });

      // Toggle clicked
      if (!isActive) {
        item.classList.add("active");
        answer.style.maxHeight = answer.scrollHeight + 30 + "px";
      }
    });
  });
}
