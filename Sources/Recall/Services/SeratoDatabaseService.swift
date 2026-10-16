import Foundation
import SQLite3

public class SeratoDatabaseService {
    private let dbPath: String
    
    public init(databasePath: String = UserSettings.shared.effectiveDatabasePath) {
        self.dbPath = databasePath
    }
    
    private func openDatabase() -> OpaquePointer? {
        var db: OpaquePointer?
        // Ouverture en READWRITE pour permettre à SQLite d'accéder au fichier WAL (-wal / -shm) en temps réel
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK {
            // Verrouillage strict en lecture seule via PRAGMA query_only pour garantir l'intégrité de Serato
            sqlite3_exec(db, "PRAGMA query_only = ON;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA busy_timeout = 2000;", nil, nil, nil)
            return db
        }
        
        // Repli en lecture seule URI si nécessaire
        let uri = "file:\(dbPath)?immutable=1"
        if sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK {
            return db
        }
        
        return nil
    }
    
// MARK: - Modèle d'état des platines actives

public struct ActiveDecksState {
    public let deck1: Track?
    public let deck2: Track?
    public let latestEntryId: Int
    public let hasActiveSession: Bool
    
    public init(deck1: Track?, deck2: Track?, latestEntryId: Int, hasActiveSession: Bool) {
        self.deck1 = deck1
        self.deck2 = deck2
        self.latestEntryId = latestEntryId
        self.hasActiveSession = hasActiveSession
    }
}

// MARK: - Détection des morceaux en cours de lecture

/// Détecte de façon stricte et robuste les morceaux actuellement chargés et en cours de lecture
/// sur chaque platine (Deck 1 / Deck 2) pour la session Serato en cours.
/// Règles strictes :
/// 1. Ne consulte QUE la session active (session_id le plus récent dans history_session).
/// 2. Exclut catégoriquement toute piste dont end_time > 0 (piste éjectée, terminée ou remplacée).
/// 3. Filtre par fenêtre de fraîcheur (anti-stagnation après fin de lecture).
/// 4. Si une platine n'a aucun morceau chargé dans la session active, elle renvoie nil (platine vide).
public func fetchActiveDecks() -> ActiveDecksState {
    guard let db = openDatabase() else {
        return ActiveDecksState(deck1: nil, deck2: nil, latestEntryId: -1, hasActiveSession: false)
    }
    defer { sqlite3_close(db) }
    
    // 1. Récupération de la dernière session Serato
    var sessionStmt: OpaquePointer?
    var latestSessionId: Int64 = -1
    var sessionEndTime: Int64 = -1
    
    if sqlite3_prepare_v2(db, "SELECT id, end_time FROM history_session ORDER BY id DESC LIMIT 1;", -1, &sessionStmt, nil) == SQLITE_OK {
        if sqlite3_step(sessionStmt) == SQLITE_ROW {
            latestSessionId = sqlite3_column_int64(sessionStmt, 0)
            sessionEndTime = sqlite3_column_int64(sessionStmt, 1)
        }
        sqlite3_finalize(sessionStmt)
    }
    
    guard latestSessionId > 0 else {
        return ActiveDecksState(deck1: nil, deck2: nil, latestEntryId: -1, hasActiveSession: false)
    }
    
    // Si la session Serato a été explicitement clôturée dans SQLite (end_time > 0)
    if sessionEndTime > 0 {
        return ActiveDecksState(deck1: nil, deck2: nil, latestEntryId: -1, hasActiveSession: false)
    }
    
    // 2. Récupération des entrées de la session active
    let sql = """
    SELECT 
        id,
        asset_id,
        ifnull(name, ''),
        ifnull(artist, ''),
        ifnull(bpm, 0.0),
        ifnull(key, ''),
        ifnull(file_name, ''),
        ifnull(portable_id, ''),
        ifnull(deck, ''),
        start_time,
        end_time,
        ifnull(length_sec, 0)
    FROM history_entry
    WHERE session_id = \(latestSessionId)
    ORDER BY id DESC;
    """
    
    var stmt: OpaquePointer?
    var d1Track: Track? = nil
    var d2Track: Track? = nil
    var maxEntryId: Int = -1
    let nowUnix = Date().timeIntervalSince1970
    
    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
        while sqlite3_step(stmt) == SQLITE_ROW {
            let entryId = Int(sqlite3_column_int64(stmt, 0))
            if maxEntryId < 0 {
                maxEntryId = entryId
            }
            
            var deck = sqlite3_column_text(stmt, 8).map { String(cString: $0) } ?? ""
            deck = deck.replacingOccurrences(of: "'", with: "")
            
            let endTimeUnix = sqlite3_column_int64(stmt, 10)
            let startTimeUnix = sqlite3_column_int64(stmt, 9)
            let lengthSec = sqlite3_column_int64(stmt, 11)
            
            // RÈGLE 1 : end_time <= 0 (Serato conserve end_time à -1 tant que le morceau est chargé)
            guard endTimeUnix <= 0 else { continue }
            
            // RÈGLE 2 : Fraîcheur temporelle (au maximum 15 min ou 2.5x durée du morceau)
            let elapsed = nowUnix - Double(startTimeUnix)
            let maxValidDuration = lengthSec > 0 ? max(Double(lengthSec) * 2.5, 900.0) : 900.0
            guard elapsed >= 0 && elapsed <= maxValidDuration else { continue }
            
            let assetId = Int(sqlite3_column_int64(stmt, 1))
            let title = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
            let artist = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
            let bpm = sqlite3_column_double(stmt, 4)
            let key = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
            let fileName = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? ""
            let portableId = sqlite3_column_text(stmt, 7).map { String(cString: $0) } ?? ""
            let playedAt = Date(timeIntervalSince1970: TimeInterval(startTimeUnix))
            
            let resolvedPath = resolveTrackFilePath(portableId: portableId, fileName: fileName)
            
            let track = Track(
                id: "entry-\(entryId)",
                assetId: assetId > 0 ? assetId : nil,
                historyEntryId: entryId,
                title: title,
                artist: artist,
                bpm: bpm,
                rawKey: key,
                filePath: resolvedPath,
                fileName: fileName,
                portableId: portableId,
                deck: deck.isEmpty ? nil : deck,
                playedAt: playedAt
            )
            
            if deck == "1" && d1Track == nil {
                d1Track = track
            } else if deck == "2" && d2Track == nil {
                d2Track = track
            }
            
            if d1Track != nil && d2Track != nil {
                break
            }
        }
        sqlite3_finalize(stmt)
    }
    
    return ActiveDecksState(
        deck1: d1Track,
        deck2: d2Track,
        latestEntryId: maxEntryId,
        hasActiveSession: true
    )
}
    
    /// Récupère les derniers morceaux enregistrés dans l'historique global
    public func fetchLatestPlayedTracks(limit: Int = 6) -> [Track] {
        guard let db = openDatabase() else { return [] }
        defer { sqlite3_close(db) }
        
        let sql = """
        SELECT 
            id,
            asset_id,
            ifnull(name, ''),
            ifnull(artist, ''),
            ifnull(bpm, 0.0),
            ifnull(key, ''),
            ifnull(file_name, ''),
            ifnull(portable_id, ''),
            ifnull(deck, ''),
            start_time
        FROM history_entry
        WHERE played = 1
        ORDER BY id DESC
        LIMIT \(limit);
        """
        
        var stmt: OpaquePointer?
        var tracks: [Track] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let entryId = Int(sqlite3_column_int64(stmt, 0))
                let assetId = Int(sqlite3_column_int64(stmt, 1))
                let title = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                let artist = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                let bpm = sqlite3_column_double(stmt, 4)
                let key = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
                let fileName = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? ""
                let portableId = sqlite3_column_text(stmt, 7).map { String(cString: $0) } ?? ""
                var deck = sqlite3_column_text(stmt, 8).map { String(cString: $0) } ?? ""
                deck = deck.replacingOccurrences(of: "'", with: "")
                let startTimeUnix = sqlite3_column_int64(stmt, 9)
                let playedAt = Date(timeIntervalSince1970: TimeInterval(startTimeUnix))
                
                let resolvedPath = resolveTrackFilePath(portableId: portableId, fileName: fileName)
                
                let track = Track(
                    id: "entry-\(entryId)",
                    assetId: assetId > 0 ? assetId : nil,
                    historyEntryId: entryId,
                    title: title,
                    artist: artist,
                    bpm: bpm,
                    rawKey: key,
                    filePath: resolvedPath,
                    fileName: fileName,
                    portableId: portableId,
                    deck: deck.isEmpty ? nil : deck,
                    playedAt: playedAt
                )
                tracks.append(track)
            }
            sqlite3_finalize(stmt)
        }
        
        return tracks
    }
    
    // MARK: - Algorithme de Suggestions d'Enchaînements STRICTEMENT basé sur l'Historique
    
    /// Calcule le Top des enchaînements réels joués après le morceau de référence
    /// dans les sessions Serato sur la période configurée (ex: 360 jours).
    /// EXCLUSION STRICTE : Ne s'appuie JAMAIS sur le nombre total de lectures de la bibliothèque (metadata).
    public func fetchTransitions(
        for referenceTrack: Track,
        daysLookback: Int = 360,
        maxResults: Int = 30
    ) -> [Track] {
        guard let db = openDatabase() else { return [] }
        defer { sqlite3_close(db) }
        
        var suggestions: [Track] = []
        var seenTitles = Set<String>()
        let refTitleKey = normalizeTitle(referenceTrack.displayTitle)
        seenTitles.insert(refTitleKey)
        let refRawKey = normalizeTitle(referenceTrack.title)
        if !refRawKey.isEmpty {
            seenTitles.insert(refRawKey)
        }
        
        let secondsLookback = Int64(daysLookback) * 86400
        let minStartTimeUnix = Int64(Date().timeIntervalSince1970) - secondsLookback
        
        // --- DÉTECTION DES VARIANTES (Si l'option de cumul est cochée dans les Paramètres) ---
        let cumulateVariants = UserSettings.shared.cumulateVariantSuggestions
        let variantInfo: (assetIds: [Int], fileNames: [String], names: [String], baseTitle: String)?
        if cumulateVariants {
            variantInfo = findCompatibleVariantIdentifiers(
                db: db,
                referenceTrack: referenceTrack,
                minStartTime: minStartTimeUnix
            )
            if let v = variantInfo {
                for n in v.names {
                    seenTitles.insert(normalizeTitle(n))
                }
            }
        } else {
            variantInfo = nil
        }
        
        // --- NIVEAU 1 : Transitions directes (avec cumul des variantes si activé) ---
        let directMatches = queryDirectTransitions(
            db: db,
            referenceTrack: referenceTrack,
            variantInfo: variantInfo,
            minStartTime: minStartTimeUnix,
            limit: maxResults
        )
        
        for match in directMatches {
            let key = normalizeTitle(match.displayTitle)
            if !seenTitles.contains(key) {
                seenTitles.insert(key)
                suggestions.append(match)
            }
        }
        
        // --- NIVEAU 2 : Transitions via variante du morceau actuel (ex: autre remix/edit du même titre) ---
        if suggestions.count < maxResults && !cumulateVariants {
            let baseTitle = Track.extractBaseTitle(referenceTrack.displayTitle)
            if baseTitle.count >= 3 && baseTitle.lowercased() != referenceTrack.displayTitle.lowercased() {
                let variantMatches = queryBaseTitleTransitions(
                    db: db,
                    baseTitle: baseTitle,
                    excludeAssetId: referenceTrack.assetId,
                    minStartTime: minStartTimeUnix,
                    limit: maxResults - suggestions.count
                )
                
                for match in variantMatches {
                    let key = normalizeTitle(match.displayTitle)
                    if !seenTitles.contains(key) {
                        seenTitles.insert(key)
                        suggestions.append(match)
                    }
                }
            }
        }
        
        // --- NIVEAU 3 : Routines enchaînées (Track A -> Track B -> Track C à N+2 dans la même session) ---
        if suggestions.count < maxResults {
            let sequenceMatches = querySecondarySessionTransitions(
                db: db,
                referenceTrack: referenceTrack,
                minStartTime: minStartTimeUnix,
                limit: maxResults - suggestions.count,
                excludeTitles: seenTitles
            )
            
            for seqMatch in sequenceMatches {
                let key = normalizeTitle(seqMatch.displayTitle)
                if !seenTitles.contains(key) {
                    seenTitles.insert(key)
                    suggestions.append(seqMatch)
                }
            }
        }
        
        // Calcul des relations harmoniques et écarts BPM par rapport au morceau actuel
        return suggestions.map { track in
            var updated = track
            if let refCamelot = referenceTrack.camelotKey, let trkCamelot = track.camelotKey {
                updated.harmonicRelation = refCamelot.relationship(with: trkCamelot)
            }
            if referenceTrack.bpm > 0 && track.bpm > 0 {
                updated.bpmDiff = track.bpm - referenceTrack.bpm
            }
            return updated
        }
    }
    
    // MARK: - Détection des Variantes Compatibles (Même Titre de Base, Même Clé & BPM Similaire)
    
    private func hasCommonWords(_ a: String, _ b: String) -> Bool {
        let stopWords: Set<String> = ["feat", "ft", "x", "&", "and", "the", "dj", "by", "vs"]
        let wordsA = Set(a.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stopWords.contains($0) })
        let wordsB = Set(b.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stopWords.contains($0) })
        return !wordsA.isDisjoint(with: wordsB)
    }

    /// Trouve toutes les variantes compatibles (edits, remixes, club versions) du morceau de référence ayant:
    /// - Le même titre de base
    /// - La même gamme harmonique (même clé Camelot ou tonalité)
    /// - Sensiblement le même BPM (marge max tolérée de 4% ou ±2 BPM)
    private func findCompatibleVariantIdentifiers(
        db: OpaquePointer,
        referenceTrack: Track,
        minStartTime: Int64
    ) -> (assetIds: [Int], fileNames: [String], names: [String], baseTitle: String) {
        let baseTitle = Track.extractBaseTitle(referenceTrack.displayTitle)
        guard baseTitle.count >= 3 else {
            return (
                referenceTrack.assetId.map { [$0] } ?? [],
                referenceTrack.fileName.isEmpty ? [] : [referenceTrack.fileName],
                [referenceTrack.displayTitle, referenceTrack.title].filter { !$0.isEmpty },
                baseTitle
            )
        }
        
        var variantAssetIds = Set<Int>()
        var variantFileNames = Set<String>()
        var variantNames = Set<String>()
        
        if let aid = referenceTrack.assetId, aid > 0 { variantAssetIds.insert(aid) }
        if !referenceTrack.fileName.isEmpty { variantFileNames.insert(referenceTrack.fileName) }
        if !referenceTrack.displayTitle.isEmpty { variantNames.insert(referenceTrack.displayTitle) }
        if !referenceTrack.title.isEmpty { variantNames.insert(referenceTrack.title) }
        
        let safeBase = escapeSql(baseTitle)
        let sql = """
        SELECT DISTINCT asset_id, file_name, name, artist, bpm, key
        FROM history_entry
        WHERE (name LIKE '%\(safeBase)%' OR file_name LIKE '%\(safeBase)%')
          AND start_time >= \(minStartTime);
        """
        
        var stmt: OpaquePointer?
        let refCamelot = referenceTrack.camelotKey
        let refRawKey = referenceTrack.rawKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let refBpm = referenceTrack.bpm
        let refArtist = referenceTrack.smartParsed.artist?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedRefBase = normalizeTitle(baseTitle)
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let assetId = Int(sqlite3_column_int64(stmt, 0))
                let fileName = (sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let name = (sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let artist = (sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let bpm = sqlite3_column_double(stmt, 4)
                let keyStr = (sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                
                let candidateTitle = !name.isEmpty ? name : fileName
                let candidateBase = Track.extractBaseTitle(candidateTitle)
                
                // 1. Titre de base compatible
                let candNorm = normalizeTitle(candidateBase)
                guard candNorm == normalizedRefBase ||
                      candNorm.contains(normalizedRefBase) ||
                      normalizedRefBase.contains(candNorm) else {
                    continue
                }
                
                // 2. Artiste compatible si renseigné des deux côtés
                if !refArtist.isEmpty && !artist.isEmpty {
                    let candArt = artist.lowercased()
                    let isArtistCompatible = candArt.contains(refArtist) ||
                                            refArtist.contains(candArt) ||
                                            hasCommonWords(refArtist, candArt)
                    guard isArtistCompatible else { continue }
                }
                
                // 3. Même gamme harmonique (clé identique)
                if let refC = refCamelot {
                    guard let candC = CamelotKey.parse(keyStr), candC == refC else {
                        continue
                    }
                } else if !refRawKey.isEmpty && !keyStr.isEmpty {
                    guard keyStr.lowercased() == refRawKey else {
                        continue
                    }
                }
                
                // 4. Sensiblement le même BPM (marge tolérée de 4% ou ±2 BPM)
                if refBpm > 0 && bpm > 0 {
                    let diff = abs(bpm - refBpm)
                    let pct = diff / refBpm * 100.0
                    guard pct <= 4.0 || diff <= 2.0 else {
                        continue
                    }
                }
                
                if assetId > 0 { variantAssetIds.insert(assetId) }
                if !fileName.isEmpty { variantFileNames.insert(fileName) }
                if !name.isEmpty { variantNames.insert(name) }
            }
            sqlite3_finalize(stmt)
        }
        
        return (Array(variantAssetIds), Array(variantFileNames), Array(variantNames), baseTitle)
    }
    
    // MARK: - Requêtes SQL de Transitions Historiques
    
    /// Niveau 1 : Morceau joué immédiatement après (N+1) dans la même session (avec cumul des variantes si activé)
    private func queryDirectTransitions(
        db: OpaquePointer,
        referenceTrack: Track,
        variantInfo: (assetIds: [Int], fileNames: [String], names: [String], baseTitle: String)?,
        minStartTime: Int64,
        limit: Int
    ) -> [Track] {
        let whereTarget: String
        let whereExcludeSelf: String
        
        if let variants = variantInfo, (!variants.assetIds.isEmpty || !variants.fileNames.isEmpty || !variants.names.isEmpty) {
            let assetPart = variants.assetIds.isEmpty ? "0" : "asset_id IN (\(variants.assetIds.map { "\($0)" }.joined(separator: ",")))"
            let filePart = variants.fileNames.isEmpty ? "0" : "file_name IN (\(variants.fileNames.map { "'\(escapeSql($0))'" }.joined(separator: ",")))"
            let namePart = variants.names.isEmpty ? "0" : "name IN (\(variants.names.map { "'\(escapeSql($0))'" }.joined(separator: ",")))"
            whereTarget = "(\(assetPart) OR \(filePart) OR \(namePart))"
            
            let notAssetPart = variants.assetIds.isEmpty ? "" : "AND h2.asset_id NOT IN (\(variants.assetIds.map { "\($0)" }.joined(separator: ",")))"
            let notFilePart = variants.fileNames.isEmpty ? "" : "AND h2.file_name NOT IN (\(variants.fileNames.map { "'\(escapeSql($0))'" }.joined(separator: ",")))"
            let notNamePart = variants.names.isEmpty ? "" : "AND h2.name NOT IN (\(variants.names.map { "'\(escapeSql($0))'" }.joined(separator: ",")))"
            let notBasePart = variants.baseTitle.count >= 3 ? "AND h2.name NOT LIKE '%\(escapeSql(variants.baseTitle))%' AND h2.file_name NOT LIKE '%\(escapeSql(variants.baseTitle))%'" : ""
            whereExcludeSelf = "\(notAssetPart) \(notFilePart) \(notNamePart) \(notBasePart)"
        } else {
            let safeFileName = escapeSql(referenceTrack.fileName)
            let assetId = referenceTrack.assetId ?? -1
            let safeTitle = escapeSql(referenceTrack.displayTitle)
            let safeRawTitle = escapeSql(referenceTrack.title)
            whereTarget = """
            (
                (asset_id > 0 AND asset_id = \(assetId))
                OR (file_name != '' AND file_name = '\(safeFileName)')
                OR (name != '' AND (name = '\(safeTitle)' OR name = '\(safeRawTitle)'))
            )
            """
            whereExcludeSelf = "AND (h2.asset_id != tp.asset_id OR (h2.file_name != tp.file_name AND h2.file_name != ''))"
        }
        
        let sql = """
        WITH target_plays AS (
            SELECT id, session_id, asset_id, file_name, name, start_time
            FROM history_entry
            WHERE \(whereTarget)
              AND start_time >= \(minStartTime)
        ),
        next_plays AS (
            SELECT 
                h2.id as next_id,
                h2.asset_id as next_asset_id,
                coalesce(nullif(h2.name, ''), h2.file_name) as clean_title,
                h2.artist as next_artist,
                h2.bpm as next_bpm,
                h2.key as next_key,
                h2.file_name as next_file_name,
                h2.portable_id as next_portable_id,
                h2.start_time as next_start_time
            FROM target_plays tp
            JOIN history_entry h2 ON h2.session_id = tp.session_id
                AND h2.start_time > tp.start_time
                AND h2.start_time <= tp.start_time + 1200
                AND h2.id != tp.id
                \(whereExcludeSelf)
                AND h2.played = 1
            WHERE h2.id = (
                SELECT sub.id FROM history_entry sub
                WHERE sub.session_id = tp.session_id
                  AND sub.start_time > tp.start_time
                  AND sub.played = 1
                ORDER BY sub.start_time ASC
                LIMIT 1
            )
        )
        SELECT 
            clean_title,
            next_artist,
            avg(next_bpm) as avg_bpm,
            next_key,
            next_file_name,
            next_portable_id,
            next_asset_id,
            count(*) as transition_count,
            max(next_start_time) as last_played_time
        FROM next_plays
        WHERE clean_title != ''
        GROUP BY clean_title, next_artist
        ORDER BY transition_count DESC, last_played_time DESC
        LIMIT \(limit);
        """
        
        return executeTransitionQuery(db: db, sql: sql, matchType: .directTransition)
    }
    
    /// Niveau 2 : Morceau joué après une variante du titre de base (ex: Radio Edit vs Club Mix)
    private func queryBaseTitleTransitions(
        db: OpaquePointer,
        baseTitle: String,
        excludeAssetId: Int?,
        minStartTime: Int64,
        limit: Int
    ) -> [Track] {
        let safeBase = escapeSql(baseTitle)
        let excludeId = excludeAssetId ?? -1
        
        let sql = """
        WITH target_plays AS (
            SELECT id, session_id, asset_id, file_name, start_time
            FROM history_entry
            WHERE (name LIKE '%\(safeBase)%' OR file_name LIKE '%\(safeBase)%')
              AND (asset_id != \(excludeId) OR \(excludeId) <= 0)
              AND start_time >= \(minStartTime)
        ),
        next_plays AS (
            SELECT 
                h2.id as next_id,
                h2.asset_id as next_asset_id,
                coalesce(nullif(h2.name, ''), h2.file_name) as clean_title,
                h2.artist as next_artist,
                h2.bpm as next_bpm,
                h2.key as next_key,
                h2.file_name as next_file_name,
                h2.portable_id as next_portable_id,
                h2.start_time as next_start_time
            FROM target_plays tp
            JOIN history_entry h2 ON h2.session_id = tp.session_id
                AND h2.start_time > tp.start_time
                AND h2.start_time <= tp.start_time + 1200
                AND h2.id != tp.id
                AND h2.name NOT LIKE '%\(safeBase)%'
                AND h2.file_name NOT LIKE '%\(safeBase)%'
                AND h2.played = 1
            WHERE h2.id = (
                SELECT sub.id FROM history_entry sub
                WHERE sub.session_id = tp.session_id
                  AND sub.start_time > tp.start_time
                  AND sub.played = 1
                ORDER BY sub.start_time ASC
                LIMIT 1
            )
        )
        SELECT 
            clean_title,
            next_artist,
            avg(next_bpm) as avg_bpm,
            next_key,
            next_file_name,
            next_portable_id,
            next_asset_id,
            count(*) as transition_count,
            max(next_start_time) as last_played_time
        FROM next_plays
        WHERE clean_title != ''
        GROUP BY clean_title, next_artist
        ORDER BY transition_count DESC, last_played_time DESC
        LIMIT \(limit);
        """
        
        return executeTransitionQuery(db: db, sql: sql, matchType: .sameSongVariant)
    }
    
    /// Niveau 3 : Deuxième morceau enchaîné dans la même session (N+2 - Routine de set)
    private func querySecondarySessionTransitions(
        db: OpaquePointer,
        referenceTrack: Track,
        minStartTime: Int64,
        limit: Int,
        excludeTitles: Set<String>
    ) -> [Track] {
        let safeFileName = escapeSql(referenceTrack.fileName)
        let assetId = referenceTrack.assetId ?? -1
        let safeTitle = escapeSql(referenceTrack.displayTitle)
        let safeRawTitle = escapeSql(referenceTrack.title)
        
        let sql = """
        WITH target_plays AS (
            SELECT id, session_id, asset_id, file_name, start_time
            FROM history_entry
            WHERE (
                (asset_id > 0 AND asset_id = \(assetId))
                OR (file_name != '' AND file_name = '\(safeFileName)')
                OR (name != '' AND (name = '\(safeTitle)' OR name = '\(safeRawTitle)'))
            )
            AND start_time >= \(minStartTime)
        ),
        second_next_plays AS (
            SELECT 
                h3.id as next_id,
                h3.asset_id as next_asset_id,
                coalesce(nullif(h3.name, ''), h3.file_name) as clean_title,
                h3.artist as next_artist,
                h3.bpm as next_bpm,
                h3.key as next_key,
                h3.file_name as next_file_name,
                h3.portable_id as next_portable_id,
                h3.start_time as next_start_time
            FROM target_plays tp
            JOIN history_entry h3 ON h3.session_id = tp.session_id
                AND h3.start_time > tp.start_time
                AND h3.start_time <= tp.start_time + 1500
                AND h3.played = 1
            WHERE (
                SELECT count(*) FROM history_entry middle
                WHERE middle.session_id = tp.session_id
                  AND middle.start_time > tp.start_time
                  AND middle.start_time < h3.start_time
                  AND middle.played = 1
            ) = 1
        )
        SELECT 
            clean_title,
            next_artist,
            avg(next_bpm) as avg_bpm,
            next_key,
            next_file_name,
            next_portable_id,
            next_asset_id,
            count(*) as transition_count,
            max(next_start_time) as last_played_time
        FROM second_next_plays
        WHERE clean_title != ''
        GROUP BY clean_title, next_artist
        ORDER BY transition_count DESC, last_played_time DESC
        LIMIT \(limit * 2);
        """
        
        let candidates = executeTransitionQuery(db: db, sql: sql, matchType: .routineSequence)
        var filtered: [Track] = []
        for track in candidates {
            let key = normalizeTitle(track.displayTitle)
            if !excludeTitles.contains(key) {
                filtered.append(track)
                if filtered.count >= limit { break }
            }
        }
        return filtered
    }
    
    private func executeTransitionQuery(
        db: OpaquePointer,
        sql: String,
        matchType: MatchType
    ) -> [Track] {
        var results: [Track] = []
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let title = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
                let artist = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                let bpm = sqlite3_column_double(stmt, 2)
                let key = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                let fileName = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                let portableId = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
                let assetId = Int(sqlite3_column_int64(stmt, 6))
                let count = Int(sqlite3_column_int64(stmt, 7))
                
                let resolvedPath = resolveTrackFilePath(portableId: portableId, fileName: fileName)
                
                let track = Track(
                    assetId: assetId > 0 ? assetId : nil,
                    title: title,
                    artist: artist,
                    bpm: bpm,
                    rawKey: key,
                    filePath: resolvedPath,
                    fileName: fileName,
                    portableId: portableId,
                    transitionCount: count,
                    matchType: matchType
                )
                results.append(track)
            }
            sqlite3_finalize(stmt)
        }
        
        return results
    }
    
    // MARK: - Recherche de Morceaux dans la Bibliothèque Serato
    
    public func searchTracks(query: String, limit: Int = 30) -> [Track] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard let db = openDatabase() else { return [] }
        defer { sqlite3_close(db) }
        
        let tokens = trimmed
            .split(separator: " ")
            .map { escapeSql(String($0)) }
            .filter { !$0.isEmpty }
        
        guard !tokens.isEmpty else { return [] }
        
        let whereClauses = tokens.map { token in
            "(name LIKE '%\(token)%' OR artist LIKE '%\(token)%' OR file_name LIKE '%\(token)%')"
        }.joined(separator: " AND ")
        
        let sql = """
        SELECT 
            id,
            ifnull(name, ''),
            ifnull(artist, ''),
            ifnull(bpm, 0.0),
            ifnull(key, ''),
            ifnull(file_name, ''),
            ifnull(portable_id, '')
        FROM asset
        WHERE \(whereClauses)
        ORDER BY id DESC
        LIMIT \(limit);
        """
        
        var results: [Track] = []
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let assetId = Int(sqlite3_column_int64(stmt, 0))
                let title = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                let artist = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                let bpm = sqlite3_column_double(stmt, 3)
                let key = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                let fileName = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
                let portableId = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? ""
                
                let resolvedPath = resolveTrackFilePath(portableId: portableId, fileName: fileName)
                
                let track = Track(
                    assetId: assetId,
                    title: title.isEmpty ? (fileName as NSString).deletingPathExtension : title,
                    artist: artist,
                    bpm: bpm,
                    rawKey: key,
                    filePath: resolvedPath,
                    fileName: fileName,
                    portableId: portableId
                )
                results.append(track)
            }
            sqlite3_finalize(stmt)
        }
        
        return results
    }
    
    // MARK: - Résolution des Fichiers Audio sur le Disque
    
    public func resolveTrackFilePath(portableId: String, fileName: String) -> String? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        
        // 1. portableId direct avec slash initial
        if portableId.hasPrefix("/") && fm.fileExists(atPath: portableId) {
            return portableId
        }
        
        // 2. portableId débutant par "Users/..."
        let slashPortable = "/" + portableId
        if fm.fileExists(atPath: slashPortable) {
            return slashPortable
        }
        
        // 3. Dossier de musique principal du DJ (REVR BIBLIOTHEQUE)
        let revrPath = "\(home)/Music/REVR BIBLIOTHEQUE/\(fileName)"
        if !fileName.isEmpty && fm.fileExists(atPath: revrPath) {
            return revrPath
        }
        
        // 4. Dossier ~/Music
        let musicPath = "\(home)/Music/\(fileName)"
        if !fileName.isEmpty && fm.fileExists(atPath: musicPath) {
            return musicPath
        }
        
        // 5. Chemin relatif dans le répertoire home
        let candidateHome = "\(home)/\(portableId)"
        if fm.fileExists(atPath: candidateHome) {
            return candidateHome
        }
        
        // 6. Recherche sur les disques externes (/Volumes/*)
        if let volumes = try? fm.contentsOfDirectory(atPath: "/Volumes") {
            for vol in volumes {
                let candidateVol = "/Volumes/\(vol)/\(portableId)"
                if fm.fileExists(atPath: candidateVol) {
                    return candidateVol
                }
                if !fileName.isEmpty {
                    let candidateVolFile = "/Volumes/\(vol)/_Serato_/\(fileName)"
                    if fm.fileExists(atPath: candidateVolFile) {
                        return candidateVolFile
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Recherche d'un Morceau par Fichier (Drag & Drop)
    
    public func findTrackByFile(filePath: String, fileName: String) -> Track? {
        guard let db = openDatabase() else { return nil }
        defer { sqlite3_close(db) }
        
        let safeFileName = escapeSql(fileName)
        let cleanPath = filePath.hasPrefix("/") ? String(filePath.dropFirst()) : filePath
        let safePortable = escapeSql(cleanPath)
        let safeFilePath = escapeSql(filePath)
        
        let sql = """
        SELECT 
            id,
            ifnull(name, ''),
            ifnull(artist, ''),
            ifnull(bpm, 0.0),
            ifnull(key, ''),
            ifnull(file_name, ''),
            ifnull(portable_id, '')
        FROM asset
        WHERE file_name = '\(safeFileName)'
           OR portable_id = '\(safePortable)'
           OR portable_id = '\(safeFilePath)'
           OR '\(safeFilePath)' LIKE '%' || portable_id
        ORDER BY (CASE WHEN file_name = '\(safeFileName)' THEN 1 ELSE 2 END)
        LIMIT 1;
        """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                let assetId = Int(sqlite3_column_int64(stmt, 0))
                let title = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                let artist = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                let bpm = sqlite3_column_double(stmt, 3)
                let key = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                let fn = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
                let pid = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? ""
                sqlite3_finalize(stmt)
                
                let resolvedPath = resolveTrackFilePath(portableId: pid, fileName: fn) ?? (FileManager.default.fileExists(atPath: filePath) ? filePath : nil)
                
                return Track(
                    assetId: assetId,
                    title: title.isEmpty ? (fileName as NSString).deletingPathExtension : title,
                    artist: artist,
                    bpm: bpm,
                    rawKey: key,
                    filePath: resolvedPath,
                    fileName: fn.isEmpty ? fileName : fn,
                    portableId: pid
                )
            }
            sqlite3_finalize(stmt)
        }
        
        return nil
    }
    
    /// Trouve un morceau dans la base Serato par son titre et son artiste (pour glisser-déposer sans chemin direct)
    public func findTrackByTitleArtist(title: String, artist: String = "") -> Track? {
        guard let db = openDatabase() else { return nil }
        defer { sqlite3_close(db) }
        
        let safeTitle = escapeSql(title)
        let safeArtist = escapeSql(artist)
        guard !safeTitle.isEmpty else { return nil }
        
        let sql: String
        if !safeArtist.isEmpty {
            sql = """
            SELECT 
                id,
                ifnull(name, ''),
                ifnull(artist, ''),
                ifnull(bpm, 0.0),
                ifnull(key, ''),
                ifnull(file_name, ''),
                ifnull(portable_id, '')
            FROM asset
            WHERE (name = '\(safeTitle)' OR file_name LIKE '%\(safeTitle)%')
              AND (artist = '\(safeArtist)' OR artist LIKE '%\(safeArtist)%')
            ORDER BY (CASE WHEN name = '\(safeTitle)' THEN 1 ELSE 2 END)
            LIMIT 1;
            """
        } else {
            sql = """
            SELECT 
                id,
                ifnull(name, ''),
                ifnull(artist, ''),
                ifnull(bpm, 0.0),
                ifnull(key, ''),
                ifnull(file_name, ''),
                ifnull(portable_id, '')
            FROM asset
            WHERE (name = '\(safeTitle)' OR file_name LIKE '%\(safeTitle)%')
            ORDER BY (CASE WHEN name = '\(safeTitle)' THEN 1 ELSE 2 END)
            LIMIT 1;
            """
        }
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                let assetId = Int(sqlite3_column_int64(stmt, 0))
                let t = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                let a = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                let bpm = sqlite3_column_double(stmt, 3)
                let key = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                let fn = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
                let pid = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? ""
                sqlite3_finalize(stmt)
                
                let resolvedPath = resolveTrackFilePath(portableId: pid, fileName: fn)
                
                return Track(
                    assetId: assetId,
                    title: t.isEmpty ? title : t,
                    artist: a.isEmpty ? artist : a,
                    bpm: bpm,
                    rawKey: key,
                    filePath: resolvedPath,
                    fileName: fn,
                    portableId: pid
                )
            }
            sqlite3_finalize(stmt)
        }
        return nil
    }
    
    // MARK: - Suivi de la Session en Cours (Morceaux Déjà Joués)
    
    public struct RawSessionEntry {
        public let id: Int
        public let title: String
        public let artist: String
        public let bpm: Double
        public let rawKey: String
        public let genre: String
        public let fileName: String
        public let startTime: Date
        public let endTime: Date?
        public let durationSeconds: Double
        public let isCurrentlyPlaying: Bool
        public let playedFlag: Int
    }
    
    /// Récupère l'heure de début de la session Serato la plus récente
    public func fetchLatestSessionStartTime() -> Date? {
        guard let db = openDatabase() else { return nil }
        defer { sqlite3_close(db) }
        
        let sql = "SELECT start_time FROM history_session ORDER BY id DESC LIMIT 1;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                let startUnix = sqlite3_column_int64(stmt, 0)
                if startUnix > 0 {
                    return Date(timeIntervalSince1970: TimeInterval(startUnix))
                }
            }
        }
        return nil
    }
    
    /// Récupère toutes les entrées enregistrées depuis une date avec calcul de durée
    public func fetchSessionEntries(since: Date) -> [RawSessionEntry] {
        guard let db = openDatabase() else { return [] }
        defer { sqlite3_close(db) }
        
        let sinceUnix = Int64(since.timeIntervalSince1970)
        let nowUnix = Date().timeIntervalSince1970
        
        let sql = """
        SELECT 
            id,
            ifnull(name, ''),
            ifnull(artist, ''),
            ifnull(bpm, 0.0),
            ifnull(key, ''),
            ifnull(file_name, ''),
            start_time,
            end_time,
            played,
            ifnull(genre, '')
        FROM history_entry
        WHERE start_time >= \(sinceUnix)
        ORDER BY start_time ASC;
        """
        
        var stmt: OpaquePointer?
        var entries: [RawSessionEntry] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let entryId = Int(sqlite3_column_int64(stmt, 0))
                let name = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                let artist = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                let bpm = sqlite3_column_double(stmt, 3)
                let rawKey = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                let fileName = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
                let startUnix = sqlite3_column_int64(stmt, 6)
                let endUnix = sqlite3_column_int64(stmt, 7)
                let playedFlag = Int(sqlite3_column_int(stmt, 8))
                let genre = sqlite3_column_text(stmt, 9).map { String(cString: $0) } ?? ""
                
                let startDate = Date(timeIntervalSince1970: TimeInterval(startUnix))
                var endDate: Date? = nil
                var duration: Double = 0.0
                var isCurrent: Bool = false
                
                if endUnix > startUnix {
                    endDate = Date(timeIntervalSince1970: TimeInterval(endUnix))
                    duration = Double(endUnix - startUnix)
                } else {
                    isCurrent = true
                    duration = max(0.0, nowUnix - Double(startUnix))
                }
                
                let cleanTitle = !name.isEmpty ? name : (fileName as NSString).deletingPathExtension
                
                entries.append(RawSessionEntry(
                    id: entryId,
                    title: cleanTitle,
                    artist: artist,
                    bpm: bpm,
                    rawKey: rawKey,
                    genre: genre,
                    fileName: fileName,
                    startTime: startDate,
                    endTime: endDate,
                    durationSeconds: duration,
                    isCurrentlyPlaying: isCurrent,
                    playedFlag: playedFlag
                ))
            }
        }
        return entries
    }
    
    // MARK: - Utilitaires
    
    private func escapeSql(_ str: String) -> String {
        return str.replacingOccurrences(of: "'", with: "''")
    }
    
    private func normalizeTitle(_ title: String) -> String {
        return title.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }
    
    private func extractBaseTitle(_ fullTitle: String) -> String {
        var cleaned = fullTitle
        if let parenRange = cleaned.range(of: "\\s*\\([^)]*\\)", options: .regularExpression) {
            cleaned.removeSubrange(parenRange)
        }
        if let bracketRange = cleaned.range(of: "\\s*\\[[^]]*\\]", options: .regularExpression) {
            cleaned.removeSubrange(bracketRange)
        }
        if let ftRange = cleaned.range(of: "\\s*(ft\\.|feat\\.|vs\\.).*", options: [.regularExpression, .caseInsensitive]) {
            cleaned.removeSubrange(ftRange)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
