import Foundation

/// Utilitaire haute performance de nettoyage et de résolution intelligente des métadonnées des morceaux.
/// Détecte et élimine les tags promotionnels, handles de réseaux sociaux (Instagram, SoundCloud, etc.),
/// les tags de record pools, et extrait le véritable artiste depuis le titre, le nom de fichier ou le genre.
public struct TrackMetadataCleaner {
    
    // MARK: - Ensemble des genres musicaux génériques connus (Recherche O(1) ultra-rapide)
    public static let genericGenres: Set<String> = [
        "house", "tech house", "deep house", "afro house", "melodic house", "electro house",
        "progressive house", "bass house", "future house", "tropical house", "acid house",
        "funky house", "soulful house", "jackin house", "g-house", "slap house", "piano house",
        "vocal house", "techno", "peak time", "melodic techno", "hard techno", "minimal",
        "minimal techno", "industrial techno", "acid techno", "detroit techno", "berlin techno",
        "hip hop", "hip-hop", "rap", "trap", "drill", "uk drill", "ny drill", "boom bap",
        "french rap", "rap francais", "rap us", "us rap", "r&b", "rnb", "soul", "neo soul",
        "funk", "disco", "nu disco", "nu-disco", "boogie", "pop", "dance", "electro pop",
        "synth pop", "indie", "indie pop", "indie dance", "rock", "hard rock", "alternative",
        "metal", "punk", "acoustic", "afro", "afrobeats", "afrobeat", "amapiano", "coupe decale",
        "ndombolo", "highlife", "kizomba", "zouk", "kompa", "shatta", "bouyon",
        "latin", "reggaeton", "dancehall", "reggae", "moombahton", "dembow", "bachata",
        "salsa", "merengue", "baile funk", "cumbia", "electronic", "electro", "edm", "trance",
        "psytrance", "dubstep", "drum & bass", "drum and bass", "dnb", "jungle", "uk garage",
        "ukg", "2-step", "bassline", "breakbeat", "breaks", "hardstyle", "hardcore", "ambient",
        "chillout", "lounge", "downtempo", "lo-fi", "lofi", "jazz", "blues", "classical",
        "soundtrack", "world", "folk", "country", "gospel", "general", "other", "autre",
        "divers", "inconnu", "unknown", "club", "dj tools", "acapella", "instrumental",
        "intro", "outro", "transition", "scratch", "sfx", "mashup", "bootleg", "edit", "remix"
    ]
    
    // MARK: - Expressions Régulières Compilées (Instanciées une seule fois pour une fluidité maximale)
    
    private static let audioExtRegex = try! NSRegularExpression(
        pattern: "\\.(mp3|wav|aiff|flac|m4a|aac|ogg|alac)$",
        options: .caseInsensitive
    )
    
    private static let trackNoPrefixRegex = try! NSRegularExpression(
        pattern: "^([0-9]{1,3}[A-Za-z]?[\\.-]\\s*|[0-9]{1,3}\\s+-\\s+|[0-9]{1,3}_)",
        options: []
    )
    
    private static let multiSeparatorRegex = try! NSRegularExpression(
        pattern: "(\\s+[-–—]\\s+|\\s+\\/\\/\\s+|\\s+\\|\\s+|\\s+_\\s+)",
        options: []
    )
    
    private static let socialPrefixRegex = try! NSRegularExpression(
        pattern: "(?i)^(@[a-zA-Z0-9_\\.]+|insta(gram)?\\s*[:@-]|ig\\s*[:@-]|tiktok\\s*[:@-]|soundcloud\\s*[:@-]|sc\\s*[:@-]|fb\\s*[:@-]|facebook\\s*[:@-]|yt\\s*[:@-]|youtube\\s*[:@-]|twitter\\s*[:@-]|telegram\\s*[:@-]|t\\.me\\/).*",
        options: []
    )
    
    private static let webDomainRegex = try! NSRegularExpression(
        pattern: "(?i)(https?:\\/\\/|www\\.|\\b[a-z0-9_-]+\\.(com|fr|net|org|io|co|me|club|dj|top|info|xyz|app|de|uk|ru|eu|es|it)\\b)",
        options: []
    )
    
    private static let promoPoolKeywordsRegex = try! NSRegularExpression(
        pattern: "(?i)\\b(free\\s*(dl|download)|edit(s)?\\s*pack|bootleg(s)?\\s*pack|mashup(s)?\\s*pack|dj\\s*pool|record\\s*pool|promo\\s*only|promo\\s*copy|exclusive\\s*(promo|edit|bootleg)|bpm\\s*supreme|dj\\s*city|club\\s*killers|heavy\\s*hits|franchise\\s*pool|direct\\s*music\\s*service|zipdj|barbangerz|crooklyn\\s*clan|crack4dj|idjpool|hypeddit|toneden)\\b",
        options: []
    )
    
    private static let placeholderRegex = try! NSRegularExpression(
        pattern: "^(?i)(unknown(\\s+artist)?|artiste\\s+inconnu|artiste|artist|various(\\s+artists)?|divers(\\s+artistes)?|compilation|v\\.?a\\.?|v\\/a|track|piste|audio|untitled|sans\\s+titre|none|n\\/?a|null|nil|undefined|\\?+|-+|\\.+|_)$",
        options: []
    )
    
    private static let numericOrSpecRegex = try! NSRegularExpression(
        pattern: "^(?i)([0-9]+(\\s*kbps)?|320\\s*kbps|128\\s*kbps|wav|mp3|flac|aiff|aac|m4a|lossless)$",
        options: []
    )
    
    private static let techMarkerRegex = try! NSRegularExpression(
        pattern: "^(track|side\\s*[ab]|cd\\s*[0-9]+)$",
        options: .caseInsensitive
    )
    
    private static let genericVersionRegex = try! NSRegularExpression(
        pattern: "^(instrumental|acapella|accapella|extended mix|original mix|clean|dirty|radio edit|dub mix|club mix|club edit|remix|edit|bootleg|intro|outro)$",
        options: .caseInsensitive
    )
    
    private static let trailingPromoInArtistRegex = try! NSRegularExpression(
        pattern: "\\s*[\\[\\(](?i)(insta(gram)?|ig|soundcloud|tiktok|free\\s*dl|download|edit|remix|bootleg|pack|www\\.).*?[\\]\\)]",
        options: []
    )
    
    private static let multiSpaceRegex = try! NSRegularExpression(
        pattern: "\\s{2,}",
        options: []
    )
    
    private static let collabSplitRegex = try! NSRegularExpression(
        pattern: "(?i)\\s+(feat\\.?|ft\\.?|featuring|&|x|vs\\.?|pres\\.?|presents)\\s+.*$",
        options: []
    )

    // MARK: - Validation & Détection
    
    /// Détecte si une chaîne correspond à un placeholder inconnu, un tag promotionnel ou un handle réseau social
    public static func isJunkOrPromoArtist(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.count < 2 { return true }
        
        let range = NSRange(location: 0, length: (trimmed as NSString).length)
        
        // 1. Noms génériques / placeholders
        if placeholderRegex.firstMatch(in: trimmed, options: [], range: range) != nil {
            return true
        }
        // 2. Chiffres purs / bitrates
        if numericOrSpecRegex.firstMatch(in: trimmed, options: [], range: range) != nil {
            return true
        }
        // 3. Marqueurs techniques
        if techMarkerRegex.firstMatch(in: trimmed, options: [], range: range) != nil {
            return true
        }
        // 4. Handles réseaux sociaux
        if socialPrefixRegex.firstMatch(in: trimmed, options: [], range: range) != nil {
            return true
        }
        // 5. Noms de domaine web / URLs
        if webDomainRegex.firstMatch(in: trimmed, options: [], range: range) != nil {
            return true
        }
        // 6. Record pools / mots-clés de promo
        if promoPoolKeywordsRegex.firstMatch(in: trimmed, options: [], range: range) != nil {
            return true
        }
        
        return false
    }
    
    /// Détecte si une chaîne correspond à un genre musical standard générique
    public static func isKnownGenericGenre(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty { return false }
        if genericGenres.contains(trimmed) { return true }
        if trimmed.contains("/") {
            let parts = trimmed.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
            if !parts.isEmpty && parts.allSatisfy({ genericGenres.contains($0) }) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Nettoyage Spécifique
    
    /// Nettoie un nom d'artiste (retire les guillemets, crochets enveloppants, tags promo résiduels)
    public static func cleanArtistName(_ string: String) -> String {
        var clean = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "" }
        
        // Retirer les guillemets ou crochets enveloppants
        if (clean.hasPrefix("\"") && clean.hasSuffix("\"")) ||
           (clean.hasPrefix("'") && clean.hasSuffix("'")) ||
           (clean.hasPrefix("“") && clean.hasSuffix("”")) ||
           (clean.hasPrefix("[") && clean.hasSuffix("]")) ||
           (clean.hasPrefix("(") && clean.hasSuffix(")")) {
            clean = String(clean.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Retirer symboles initiaux et finaux indésirables
        while clean.hasPrefix("@") || clean.hasPrefix("-") || clean.hasPrefix("_") {
            clean = String(clean.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        while clean.hasSuffix("-") || clean.hasSuffix("_") {
            clean = String(clean.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if clean.hasSuffix(".") && !clean.hasSuffix("..") {
            clean = String(clean.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Nettoyer les balises promo en fin d'artiste (ex: "Drake (Insta: willbear)")
        clean = trailingPromoInArtistRegex.stringByReplacingMatches(
            in: clean,
            options: [],
            range: NSRange(location: 0, length: (clean as NSString).length),
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Compacter les espaces multiples
        clean = multiSpaceRegex.stringByReplacingMatches(
            in: clean,
            options: [],
            range: NSRange(location: 0, length: (clean as NSString).length),
            withTemplate: " "
        )
        
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Nettoie un nom de titre (retire l'extension audio, les numéros de piste, les guillemets)
    public static func cleanTitleName(_ string: String) -> String {
        var clean = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "" }
        
        // 1. Extension audio
        clean = audioExtRegex.stringByReplacingMatches(
            in: clean,
            options: [],
            range: NSRange(location: 0, length: (clean as NSString).length),
            withTemplate: ""
        )
        
        // 2. Numéros de piste en préfixe
        clean = trackNoPrefixRegex.stringByReplacingMatches(
            in: clean,
            options: [],
            range: NSRange(location: 0, length: (clean as NSString).length),
            withTemplate: ""
        )
        
        // 3. Guillemets enveloppants
        if (clean.hasPrefix("\"") && clean.hasSuffix("\"")) ||
           (clean.hasPrefix("'") && clean.hasSuffix("'")) ||
           (clean.hasPrefix("“") && clean.hasSuffix("”")) {
            clean = String(clean.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 4. Compacter les espaces
        clean = multiSpaceRegex.stringByReplacingMatches(
            in: clean,
            options: [],
            range: NSRange(location: 0, length: (clean as NSString).length),
            withTemplate: " "
        )
        
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Extrait l'artiste principal pour regrouper intelligemment les morceaux dans les statistiques
    /// (ex: "Drake, Hamza ft Dmaso" -> "Drake", "Drake feat. 21 Savage" -> "Drake")
    public static func extractPrimaryArtist(_ string: String) -> String {
        let clean = cleanArtistName(string)
        if clean.isEmpty { return "" }
        
        // 1. Couper après feat., ft., &, x, vs., etc.
        var primary = collabSplitRegex.stringByReplacingMatches(
            in: clean,
            options: [],
            range: NSRange(location: 0, length: (clean as NSString).length),
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 2. Couper après la première virgule si suivie d'un espace (ex: "Drake, Hamza")
        if let commaRange = primary.range(of: ", ") {
            let candidate = String(primary[..<commaRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if candidate.count >= 2 {
                primary = candidate
            }
        }
        
        return cleanArtistName(primary)
    }
    
    // MARK: - Analyse Intelligente Artiste / Titre
    
    /// Parse une chaîne brute contenant potentiellement "Artiste - Titre"
    public static func parseSmartArtistAndTitle(rawString: String) -> (artist: String?, title: String) {
        var raw = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return (nil, "")
        }
        
        // 1. Supprimer l'extension audio
        raw = audioExtRegex.stringByReplacingMatches(
            in: raw,
            options: [],
            range: NSRange(location: 0, length: (raw as NSString).length),
            withTemplate: ""
        )
        
        // 2. Nettoyer les numéros de piste en préfixe
        let cleaned = trackNoPrefixRegex.stringByReplacingMatches(
            in: raw,
            options: [],
            range: NSRange(location: 0, length: (raw as NSString).length),
            withTemplate: ""
        )
        
        let nsCleaned = cleaned as NSString
        let match = multiSeparatorRegex.firstMatch(
            in: cleaned,
            options: [],
            range: NSRange(location: 0, length: nsCleaned.length)
        )
        
        guard let sepMatch = match else {
            return (nil, cleanTitleName(raw))
        }
        
        let rawArtistCandidate = nsCleaned.substring(to: sepMatch.range.location)
        let rawTitleCandidate = nsCleaned.substring(from: sepMatch.range.location + sepMatch.range.length)
        
        let artistCandidate = cleanArtistName(rawArtistCandidate)
        let titleCandidate = cleanTitleName(rawTitleCandidate)
        
        // Règles de validation strictes anti faux-positifs :
        // a. Longueurs cohérentes
        guard artistCandidate.count >= 1 && artistCandidate.count <= 70 && titleCandidate.count >= 1 else {
            return (nil, cleanTitleName(raw))
        }
        
        // b. Artiste non purement numérique (sauf groupes réels contenant des lettres ex: "50 Cent")
        if artistCandidate.range(of: "^[0-9]+$", options: .regularExpression) != nil {
            return (nil, cleanTitleName(raw))
        }
        
        // c. Artiste non junk/promo
        if isJunkOrPromoArtist(artistCandidate) {
            return (nil, cleanTitleName(raw))
        }
        
        // d. L'artiste candidat ne doit pas être un préfixe technique d'album / face
        if techMarkerRegex.firstMatch(
            in: artistCandidate,
            options: [],
            range: NSRange(location: 0, length: (artistCandidate as NSString).length)
        ) != nil {
            return (nil, cleanTitleName(raw))
        }
        
        // e. Le titre candidat ne doit pas être uniquement un descripteur de version générique (ex: "Satisfaction - Club Mix")
        if genericVersionRegex.firstMatch(
            in: titleCandidate,
            options: [],
            range: NSRange(location: 0, length: (titleCandidate as NSString).length)
        ) != nil {
            return (nil, cleanTitleName(raw))
        }
        
        return (artistCandidate, titleCandidate)
    }
    
    // MARK: - Résolution Maîtresse des Métadonnées
    
    /// Résout intelligemment les métadonnées en croisant le champ artiste, le titre, le nom de fichier et le genre.
    public static func resolve(
        artist: String,
        title: String,
        fileName: String = "",
        genre: String = ""
    ) -> (artist: String?, title: String) {
        let cleanArt = cleanArtistName(artist)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFile = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let isArtistValid = !cleanArt.isEmpty && !isJunkOrPromoArtist(cleanArt) && !isKnownGenericGenre(cleanArt)
        
        // CAS 1 : L'artiste renseigné est valide (non vide, pas de tag promo, pas un genre générique)
        if isArtistValid {
            var resolvedTitle: String
            if !trimmedTitle.isEmpty {
                // Vérifier si le titre répète inutilement l'artiste (ex: artiste: "Drake", titre: "Drake - Nonstop")
                let parsedTitle = parseSmartArtistAndTitle(rawString: trimmedTitle)
                if let pArtist = parsedTitle.artist, !pArtist.isEmpty {
                    let normGiven = cleanArt.lowercased()
                    let normParsed = pArtist.lowercased()
                    
                    if normParsed == normGiven {
                        // L'artiste est répété à l'identique dans le titre : on extrait le vrai titre propre !
                        resolvedTitle = parsedTitle.title
                    } else if normParsed.hasPrefix(normGiven) && (normParsed.contains("feat") || normParsed.contains("ft") || normParsed.contains("&") || normParsed.contains(",")) {
                        // Le titre a une version plus complète avec les featurings (ex: "Drake feat. 21 Savage")
                        return (pArtist, parsedTitle.title)
                    } else {
                        resolvedTitle = cleanTitleName(trimmedTitle)
                    }
                } else {
                    resolvedTitle = cleanTitleName(trimmedTitle)
                }
            } else if !trimmedFile.isEmpty {
                let fileParsed = parseSmartArtistAndTitle(rawString: trimmedFile)
                resolvedTitle = !fileParsed.title.isEmpty ? fileParsed.title : cleanTitleName((trimmedFile as NSString).deletingPathExtension)
            } else {
                resolvedTitle = "Morceau inconnu"
            }
            return (cleanArt, resolvedTitle)
        }
        
        // CAS 2 : L'artiste est manquant, inconnu, promo ou nom de genre
        // -> Tentative A : Extraire "Artiste - Titre" depuis le Titre
        if !trimmedTitle.isEmpty {
            let parsedTitle = parseSmartArtistAndTitle(rawString: trimmedTitle)
            if let pArtist = parsedTitle.artist, !pArtist.isEmpty, !isJunkOrPromoArtist(pArtist) {
                return (pArtist, parsedTitle.title)
            }
        }
        
        // -> Tentative B : Extraire "Artiste - Titre" depuis le nom de fichier
        if !trimmedFile.isEmpty {
            let parsedFile = parseSmartArtistAndTitle(rawString: (trimmedFile as NSString).deletingPathExtension)
            if let pArtist = parsedFile.artist, !pArtist.isEmpty, !isJunkOrPromoArtist(pArtist) {
                let directTitle = !trimmedTitle.isEmpty ? cleanTitleName(trimmedTitle) : parsedFile.title
                return (pArtist, directTitle)
            }
        }
        
        // -> Tentative C : Détecter si l'Artiste a été placé dans le champ Genre par le DJ / record pool
        let cleanGen = cleanArtistName(genre)
        if !cleanGen.isEmpty &&
           !isJunkOrPromoArtist(cleanGen) &&
           !isKnownGenericGenre(cleanGen) &&
           cleanGen.count >= 2 && cleanGen.count <= 60 &&
           cleanGen.range(of: "^[0-9]+$", options: .regularExpression) == nil {
            let directTitle = !trimmedTitle.isEmpty ?
                cleanTitleName(trimmedTitle) :
                (!trimmedFile.isEmpty ? cleanTitleName((trimmedFile as NSString).deletingPathExtension) : "Morceau inconnu")
            return (cleanGen, directTitle)
        }
        
        // Fallback final
        let directTitle = !trimmedTitle.isEmpty ?
            cleanTitleName(trimmedTitle) :
            (!trimmedFile.isEmpty ? cleanTitleName((trimmedFile as NSString).deletingPathExtension) : "Morceau inconnu")
        return (nil, directTitle)
    }
}
