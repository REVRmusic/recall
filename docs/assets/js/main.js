/* ==========================================================================
   RECALL — Main Interactive Scripts & Bilingual i18n
   ========================================================================== */

// ==========================================================================
// CONFIGURATION : Tracker Google Sheets (Comptabilisation des Téléchargements)
// ==========================================================================
// Collez ici l'URL de votre application Web Google Apps Script (/exec).
// Guide complet d'installation en 2 min : voir `google-sheets-tracker/README.md`
const GOOGLE_SHEET_TRACKER_URL = "https://script.google.com/macros/s/AKfycbwRVVec0m7BxPfDXL_06kkrfc75AUU5U2D_YLRL8YcMKCqZEXG6cd77EpEEKiIX-6Ad7g/exec";

// --- Dictionnaire Bilingue (FR / EN) ---
const translations = {
  fr: {
    // Nav
    "nav-features": "Fonctionnalités",
    "nav-demo": "Démonstration",
    "nav-mockups": "Aperçu Réel",
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
    "hero-subtitle": "Le copilote intelligent qui fouille vos historiques Serato et Rekordbox pour vous suggérer instantanément vos transitions éprouvées, vos sélections préparées et vos enchaînements harmoniques Camelot en plein set.",
    "hero-btn-mac": "Télécharger pour macOS",
    "hero-btn-win": "Télécharger pour Windows",
    "hero-btn-github": "Code source GitHub",
    "trust-offline": "100 % Hors-ligne (Zéro Wi-Fi)",
    "trust-cpu": "0 % CPU au repos (< 25 Mo RAM)",
    "trust-safe": "Lecture seule (Zéro risque de crash)",
    "trust-free": "Gratuit & Open-Source",
    
    // Mockups Showcase Section
    "mockups-tag": "EN SITUATION RÉELLE",
    "mockups-title": "Conçu pour s'intégrer discrètement dans votre workflow DJ.",
    "mockups-subtitle": "Découvrez comment Recall s'incruste naturellement au-dessus de Serato DJ Pro et Pioneer Rekordbox en club ou en festival.",
    "mockup-tab-serato-floating": "Serato DJ Pro · Fenêtre Flottante",
    "mockup-tab-serato-selec": "Serato DJ Pro · Onglet Sélec",
    "mockup-tab-serato-compact": "Serato DJ Pro · Bandeau Compact (78 px)",
    "mockup-tab-rekordbox": "Pioneer Rekordbox · Mode Pro",
    "mockup-tab-settings": "Paramètres & Clés Harmoniques",
    "mockup-caption-serato-floating": "Recall flottant au-dessus du browser Serato, affichant en temps réel vos routines éprouvées et vos enchaînements harmoniques.",
    "mockup-caption-serato-selec": "L'onglet Sélec : glissez vos morceaux repérés depuis Serato pour les garder sous la main. Recall les trie automatiquement en direct selon l'affinité BPM et harmonique avec le titre en cours de lecture.",
    "mockup-caption-serato-compact": "Mode Bandeau ultra-compact de 78 px : surveillance discrète au bas de l'écran, laissant 100 % d'espace pour les waveforms et les platines.",
    "mockup-caption-rekordbox": "Compatibilité totale avec Pioneer Rekordbox en mode Performance : suggestions instantanées à chaque sélection de track.",
    "mockup-caption-settings": "Panneau de configuration avec estompage doux : ajustez la tolérance BPM, choisissez entre Camelot et Musicale, et activez le mode Always on Top.",

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
    "f-selec-title": "Sélec : Votre Scratchpad DJ & Match Dynamique",
    "f-selec-desc": "Préparez vos sets sans stress : glissez vos pépites depuis Serato directement dans votre Sélec. Vos morceaux restent mémorisés d'une session à l'autre et se réordonnent automatiquement en direct selon leur compatibilité (BPM et clé Camelot) avec le morceau en cours de lecture.",
    "f-selec-badge": "Tri automatique par BPM & Camelot",
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
    "row6-name": "Scratchpad \"Sélec\" avec tri dynamique",
    "row6-val-recall": "✅ OUI (Persistant & Trié en direct)",
    "row6-val-spotify": "❌ Non",
    "row6-val-notes": "❌ Non (Bacs fixes ou papier)",
    
    // Downloads
    "dl-tag": "Téléchargement Gratuit",
    "dl-title": "Installez Recall sur votre machine de mix",
    "dl-subtitle": "Téléchargez la version officielle 1.0.0 pour macOS ou Windows. Aucun compte requis, installez et mixez.",
    "dl-mac-title": "macOS",
    "dl-mac-specs": "macOS 12.0+ Monterey, Ventura, Sonoma, Sequoia (Universal Apple Silicon M1-M4 & Intel)",
    "dl-mac-btn": "Télécharger Recall.dmg (Recommandé)",
    "dl-mac-zip": "Format .zip (Option alternative)",
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
    "nav-mockups": "Live Mockups",
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
    "hero-subtitle": "The smart DJ copilot that mines your Serato & Rekordbox history to instantly recommend proven routines, prepped selections, and Camelot harmonic transitions in live sets.",
    "hero-btn-mac": "Download for macOS",
    "hero-btn-win": "Download for Windows",
    "hero-btn-github": "GitHub Source Code",
    "trust-offline": "100% Offline (No Wi-Fi needed)",
    "trust-cpu": "0% Idle CPU (< 25 MB RAM)",
    "trust-safe": "Read-Only (Zero crash risk)",
    "trust-free": "Free & Open-Source",
    
    // Mockups Showcase Section
    "mockups-tag": "IN REAL CONDITIONS",
    "mockups-title": "Engineered to blend seamlessly into your live DJ setup.",
    "mockups-subtitle": "See how Recall sits discreetly above Serato DJ Pro and Pioneer Rekordbox in the club or at festival stages.",
    "mockup-tab-serato-floating": "Serato DJ Pro · Floating Window",
    "mockup-tab-serato-selec": "Serato DJ Pro · Sélec Tab",
    "mockup-tab-serato-compact": "Serato DJ Pro · Compact Dock (78 px)",
    "mockup-tab-rekordbox": "Pioneer Rekordbox · Pro Mode",
    "mockup-tab-settings": "Settings & Harmonic Keys",
    "mockup-caption-serato-floating": "Recall floating over Serato crate browser, delivering real-time harmonic matches and proven DJ routines on the fly.",
    "mockup-caption-serato-selec": "The Sélec tab: drop your prep tracks directly from Serato to keep them handy. Recall ranks them live based on BPM and harmonic match with the currently playing track.",
    "mockup-caption-serato-compact": "78px Ultra-Compact Dock mode: subtle monitoring docked at screen bottom, preserving 100% visibility for waveforms and decks.",
    "mockup-caption-rekordbox": "Full compatibility with Pioneer Rekordbox in Performance mode: instant harmonic suggestions on every track transition.",
    "mockup-caption-settings": "Clean settings sheet with soft dimming backdrop: customize BPM tolerance, harmonic key formats, and Always on Top mode.",

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
    "f-selec-title": "Sélec: Smart DJ Scratchpad & Dynamic Match",
    "f-selec-desc": "Prep your sets with zero stress: drop your hidden gems directly from Serato into your Sélec crate. Your tracks stay saved across sessions and automatically re-order in real time based on BPM and Camelot harmonic compatibility with what's currently playing.",
    "f-selec-badge": "Live BPM & Camelot Match Ranking",
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
    "row6-name": "Smart 'Sélec' scratchpad with dynamic match",
    "row6-val-recall": "✅ YES (Persistent & Live-sorted)",
    "row6-val-spotify": "❌ No",
    "row6-val-notes": "❌ No (Static crates or paper)",
    
    // Downloads
    "dl-tag": "Free Download",
    "dl-title": "Get Recall for your DJ machine",
    "dl-subtitle": "Download the official v1.0.0 release for macOS or Windows. No sign-up required, install and mix.",
    "dl-mac-title": "macOS",
    "dl-mac-specs": "macOS 12.0+ Monterey, Ventura, Sonoma, Sequoia (Universal Apple Silicon M1-M4 & Intel)",
    "dl-mac-btn": "Download Recall.dmg (Recommended)",
    "dl-mac-zip": "Format .zip (Alternative option)",
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

// --- DOM Initializer ---
document.addEventListener("DOMContentLoaded", () => {
  initLanguage();
  initMobileMenu();
  initNavbarScroll();
  initMockupTabs();
  initFAQ();
  initDownloadTracker();
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

  // Update mockup title in current language
  if (typeof getMockupTitles === "function") {
    const activeTab = document.querySelector(".mockup-tab-btn.active");
    const titleText = document.getElementById("mockup-title-text");
    if (activeTab && titleText) {
      const targetId = activeTab.getAttribute("data-mockup-target");
      const titles = getMockupTitles(currentLang);
      if (titles[targetId]) titleText.textContent = titles[targetId];
    }
  }

  document.documentElement.lang = currentLang;
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

// --- Mockups Showcase Tabs ---
function getMockupTitles(lang) {
  if (lang === "en") {
    return {
      "mockup-serato-floating": "Serato DJ Pro — Recall 1.0 (Floating Mode)",
      "mockup-serato-selec": "Serato DJ Pro — Recall 1.0 (Sélec Scratchpad)",
      "mockup-serato-compact": "Serato DJ Pro — Recall 1.0 (78px Compact Dock Mode)",
      "mockup-rekordbox": "Pioneer Rekordbox — Recall 1.0 (Performance Mode)",
      "mockup-settings": "Recall 1.0 — Settings Sheet & Soft Dimming"
    };
  }
  return {
    "mockup-serato-floating": "Serato DJ Pro — Recall 1.0 (Mode Flottant)",
    "mockup-serato-selec": "Serato DJ Pro — Recall 1.0 (Onglet Sélec & Scratchpad)",
    "mockup-serato-compact": "Serato DJ Pro — Recall 1.0 (Mode Bandeau Compact 78 px)",
    "mockup-rekordbox": "Pioneer Rekordbox — Recall 1.0 (Mode Performance)",
    "mockup-settings": "Recall 1.0 — Panneau des Paramètres & Estompage"
  };
}

function initMockupTabs() {
  const tabs = document.querySelectorAll(".mockup-tab-btn");
  const panels = document.querySelectorAll(".mockup-panel");
  const titleText = document.getElementById("mockup-title-text");

  if (!tabs.length || !panels.length) return;

  tabs.forEach(tab => {
    tab.addEventListener("click", () => {
      const targetId = tab.getAttribute("data-mockup-target");
      if (!targetId) return;

      tabs.forEach(t => {
        t.classList.remove("active");
        t.setAttribute("aria-selected", "false");
      });
      panels.forEach(p => p.classList.remove("active"));

      tab.classList.add("active");
      tab.setAttribute("aria-selected", "true");

      const activePanel = document.getElementById(targetId);
      if (activePanel) activePanel.classList.add("active");

      const titles = getMockupTitles(currentLang);
      if (titleText && titles[targetId]) {
        titleText.textContent = titles[targetId];
      }
    });
  });
}

// ==========================================================================
// Tracker de Téléchargements Google Sheets
// ==========================================================================
let lastDownloadTrackerTime = 0;
let lastDownloadTrackerFile = "";

function sendDownloadEvent(eventData) {
  const now = Date.now();
  const file = eventData.file || "Recall.dmg";

  // Protection Anti-Double Clic / Debounce : ignore les clics rapprochés (< 3s)
  if (now - lastDownloadTrackerTime < 3000 && lastDownloadTrackerFile === file) {
    console.log("⏳ [Recall Tracker] Clic ignoré (anti-double comptabilisation)");
    return;
  }
  lastDownloadTrackerTime = now;
  lastDownloadTrackerFile = file;

  const url = localStorage.getItem("recall_tracker_url") || 
              (new URLSearchParams(window.location.search)).get("tracker_url") || 
              GOOGLE_SHEET_TRACKER_URL;

  const payload = {
    platform: eventData.platform || "macOS",
    file: file,
    version: "1.0.0",
    event: "Téléchargement direct",
    location: eventData.location || "Section Téléchargement",
    site_lang: (typeof currentLang !== "undefined" ? currentLang : "fr").toUpperCase(),
    browser_lang: navigator.language || "",
    resolution: `${window.screen.width}x${window.screen.height}`,
    referrer: document.referrer || "Direct",
    ua: navigator.userAgent
  };

  // 1. Sauvegarde locale immédiate (utile pour tests / debug)
  try {
    const localCount = parseInt(localStorage.getItem("recall_downloads_count") || "0", 10) + 1;
    localStorage.setItem("recall_downloads_count", localCount.toString());
    const history = JSON.parse(localStorage.getItem("recall_downloads_history") || "[]");
    history.push({ date: new Date().toISOString(), ...payload });
    localStorage.setItem("recall_downloads_history", JSON.stringify(history.slice(-50)));
  } catch (e) {}

  // 2. Si l'URL Google Sheets n'a pas encore été configurée
  if (!url || url.includes("VOTRE_ID_GOOGLE_SCRIPT_ICI")) {
    console.log("📥 [Recall Tracker - Mode Simulation] Téléchargement capté avec succès :", payload);
    console.info("💡 Pour enregistrer ce téléchargement dans votre Google Sheet, suivez les instructions dans 'google-sheets-tracker/README.md'");
    return;
  }

  // 3. Envoi asynchrone non-bloquant vers Google Sheets (GET avec URLSearchParams)
  try {
    const params = new URLSearchParams();
    for (const key in payload) {
      params.append(key, payload[key]);
    }
    const fullUrl = url + (url.includes("?") ? "&" : "?") + params.toString();

    // Le mode 'no-cors' permet d'ignorer la redirection 302 de Google Apps Script
    fetch(fullUrl, {
      method: "GET",
      mode: "no-cors",
      cache: "no-cache",
      priority: "high"
    }).catch(err => {
      console.warn("Erreur envoi tracker Google Sheet :", err);
    });
  } catch (err) {
    console.warn("Exception tracker Google Sheet :", err);
  }
}

function initDownloadTracker() {
  // Attache un écouteur UNIQUE exclusivement sur les vrais liens de téléchargement de fichier
  document.querySelectorAll("[data-track-download]").forEach(btn => {
    btn.addEventListener("click", () => {
      sendDownloadEvent({
        platform: btn.getAttribute("data-track-download") || "macOS",
        file: btn.getAttribute("data-track-file") || "Recall.dmg",
        location: btn.getAttribute("data-track-location") || "Section Téléchargement"
      });
    });
  });

  // Chargement optionnel des statistiques en direct
  loadDownloadStats();
}

function loadDownloadStats() {
  const url = localStorage.getItem("recall_tracker_url") || 
              (new URLSearchParams(window.location.search)).get("tracker_url") || 
              GOOGLE_SHEET_TRACKER_URL;

  const counterBox = document.getElementById("download-live-counter");
  const counterText = document.getElementById("download-counter-text");
  if (!counterBox || !counterText) return;

  if (!url || url.includes("VOTRE_ID_GOOGLE_SCRIPT_ICI")) {
    const local = parseInt(localStorage.getItem("recall_downloads_count") || "0", 10);
    if (local > 0) {
      counterText.textContent = `${local} téléchargement${local > 1 ? "s" : ""} enregistré${local > 1 ? "s" : ""} (local)`;
      counterBox.style.display = "inline-flex";
    }
    return;
  }

  fetch(url + (url.includes("?") ? "&" : "?") + "action=stats")
    .then(res => res.json())
    .then(data => {
      if (data && data.status === "success" && data.totalDownloads >= 0) {
        const count = data.totalDownloads;
        const msg = (typeof currentLang !== "undefined" && currentLang === "en")
          ? `${count} downloads on macOS & Windows`
          : `${count} téléchargement${count > 1 ? "s" : ""} sur macOS & Windows`;
        counterText.textContent = msg;
        counterBox.style.display = "inline-flex";
      }
    })
    .catch(() => {});
}
