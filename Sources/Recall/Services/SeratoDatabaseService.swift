import Foundation
import SQLite3

public struct DatabaseFingerprint: Equatable {
    public let dbMtime: Int64
    public let dbSize: Int64
    public let walMtime: Int64
    public let walSize: Int64
    public let shmMtime: Int64
    public let shmSize: Int64
    
    public init(dbMtime: Int64, dbSize: Int64, walMtime: Int64, walSize: Int64, shmMtime: Int64, shmSize: Int64) {
        self.dbMtime = dbMtime
        self.dbSize = dbSize
        self.walMtime = walMtime
        self.walSize = walSize
        self.shmMtime = shmMtime
        self.shmSize = shmSize
    }
}

public class SeratoDatabaseService {
    public static let shared = SeratoDatabaseService()
    
    private let dbPath: String
    private static let queue = DispatchQueue(label: "fr.revr.recall.seratodb", qos: .userInitiated)
    
    // Cache haute performance basé sur la surveillance stat() WAL (0 CPU hors écritures)
    private var cachedActiveDecksState: ActiveDecksState? = nil
    private var lastActiveDecksFingerprint: DatabaseFingerprint? = nil
    private var lastActiveDecksCheckTime: Date = .distantPast
    
    // Cache haute performance des sessions passées (0 CPU et accès instantané)
    private static var cachedPastSessions: [PastSessionItem]? = nil
    private static var lastPastSessionsFingerprint: DatabaseFingerprint? = nil
    
    /// Durée d'une session = écart entre le premier morceau joué et la fin du dernier
    /// (fonctionne aussi pour la session en cours, dont end_time n'est pas encore écrit).
    private static let playedSpanSql = "max(max(start_time, ifnull(end_time, 0))) - min(start_time)"
    
    /// Restreint une requête sur history_entry aux sessions d'au moins 10 minutes de lecture.
    private static let validSessionsFilter = """
    session_id IN (
        SELECT session_id FROM history_entry
        WHERE played = 1
        GROUP BY session_id
        HAVING \(playedSpanSql) >= \(UserSettings.minimumSessionDurationSeconds)
    )
    """
    
    /// Renvoie immédiatement la liste des sessions passées en mémoire cache si disponible
    public var cachedPastSessionsImmediate: [PastSessionItem]? {
        return Self.queue.sync { Self.cachedPastSessions }
    }
    
    public init(databasePath: String = UserSettings.shared.effectiveDatabasePath) {
        self.dbPath = databasePath
    }
    
    /// Calcule une empreinte ultra-légère (stat POSIX en microsecondes, 0 verrou SQLite)
    /// sur master.sqlite, master.sqlite-wal et master.sqlite-shm.
    public func currentDatabaseFingerprint() -> DatabaseFingerprint {
        var dbMtime: Int64 = 0
        var dbSize: Int64 = 0
        var walMtime: Int64 = 0
        var walSize: Int64 = 0
        var shmMtime: Int64 = 0
        var shmSize: Int64 = 0
        
        var dbStat = stat()
        if stat(dbPath, &dbStat) == 0 {
            dbMtime = Int64(dbStat.st_mtimespec.tv_sec) * 1_000_000_000 + Int64(dbStat.st_mtimespec.tv_nsec)
            dbSize = Int64(dbStat.st_size)
        }
        
        let walPath = "\(dbPath)-wal"
        var walStat = stat()
        if stat(walPath, &walStat) == 0 {
            walMtime = Int64(walStat.st_mtimespec.tv_sec) * 1_000_000_000 + Int64(walStat.st_mtimespec.tv_nsec)
            walSize = Int64(walStat.st_size)
        }
        
        let shmPath = "\(dbPath)-shm"
        var shmStat = stat()
        if stat(shmPath, &shmStat) == 0 {
            shmMtime = Int64(shmStat.st_mtimespec.tv_sec) * 1_000_000_000 + Int64(shmStat.st_mtimespec.tv_nsec)
            shmSize = Int64(shmStat.st_size)
        }
        
        return DatabaseFingerprint(
            dbMtime: dbMtime,
            dbSize: dbSize,
            walMtime: walMtime,
            walSize: walSize,
            shmMtime: shmMtime,
            shmSize: shmSize
        )
    }
    
    /// Ouvre la base SQLite de Serato en LECTURE SEULE STRICTE et ABSOLUE (mode=ro).
    /// Garanties vitales pour le mix live avec matériel (CDJ-2000NXS2, CDJ-3000, DJM-A9) :
    /// 1. Zéro descripteur en écriture sur master.sqlite, master.sqlite-wal ou master.sqlite-shm.
    /// 2. Aucun conflit de verrouillage avec Serato DJ Pro et son LockRequestManager.
    /// 3. Aucune tentative de checkpoint automatique WAL (wal_autocheckpoint) lors de la fermeture.
    /// 4. Timeout ultra-court (100 ms) pour céder immédiatement la priorité à Serato en cas d'écriture concurrente.
    private func openDatabase() -> OpaquePointer? {
        var db: OpaquePointer?
        
        // 1. Priorité absolue : URI SQLite avec mode=ro (Read-Only garanti au niveau VFS)
        let uri = "file:\(dbPath)?mode=ro"
        if sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK {
            sqlite3_exec(db, "PRAGMA query_only = ON;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA busy_timeout = 100;", nil, nil, nil)
            return db
        }
        
        // 2. Repli en lecture seule standard sans URI
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK {
            sqlite3_exec(db, "PRAGMA query_only = ON;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA busy_timeout = 100;", nil, nil, nil)
            return db
        }
        
        AppLogger.warning("Impossible d'ouvrir la base Serato SQLite en lecture seule : \(dbPath)", category: .seratoDB)
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
    
    public func isStillFresh(at date: Date = Date()) -> Bool {
        let nowUnix = date.timeIntervalSince1970
        if let d1 = deck1 {
            let start = d1.playedAt?.timeIntervalSince1970 ?? nowUnix
            let elapsed = nowUnix - start
            if elapsed < 0 || elapsed > 900.0 { return false }
        }
        if let d2 = deck2 {
            let start = d2.playedAt?.timeIntervalSince1970 ?? nowUnix
            let elapsed = nowUnix - start
            if elapsed < 0 || elapsed > 900.0 { return false }
        }
        return true
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
/// 5. Intègre la surveillance WAL (stat) pour réutiliser l'état sans appel SQL si rien n'a changé.
public func fetchActiveDecks(force: Bool = false) -> ActiveDecksState {
    return Self.queue.sync {
        let currentFp = currentDatabaseFingerprint()
        let now = Date()
        
        // OPTIMISATION SURVEILLANCE WAL :
        // Si le journal WAL et la base n'ont subi aucune écriture et qu'on a vérifié il y a moins de 10s,
        // on évite d'ouvrir SQLite inutilement tout en contrôlant la fraîcheur temporelle en mémoire.
        if !force,
           let lastFp = self.lastActiveDecksFingerprint,
           lastFp == currentFp,
           let cached = self.cachedActiveDecksState,
           now.timeIntervalSince(self.lastActiveDecksCheckTime) < 10.0 {
            if cached.isStillFresh(at: now) {
                return cached
            }
        }
        
        guard let db = openDatabase() else {
            return ActiveDecksState(deck1: nil, deck2: nil, latestEntryId: -1, hasActiveSession: false)
        }
        defer { sqlite3_close_v2(db) }
    
    // 1. Récupération de la dernière session Serato
    var sessionStmt: OpaquePointer?
    var latestSessionId: Int64 = -1
    var sessionEndTime: Int64 = -1
    
    if sqlite3_prepare_v2(db, "SELECT id, end_time FROM history_session ORDER BY id DESC LIMIT 1;", -1, &sessionStmt, nil) == SQLITE_OK {
        defer { sqlite3_finalize(sessionStmt) }
        if sqlite3_step(sessionStmt) == SQLITE_ROW {
            latestSessionId = sqlite3_column_int64(sessionStmt, 0)
            sessionEndTime = sqlite3_column_int64(sessionStmt, 1)
        }
    }
    
    guard latestSessionId > 0 else {
        let emptyState = ActiveDecksState(deck1: nil, deck2: nil, latestEntryId: -1, hasActiveSession: false)
        self.cachedActiveDecksState = emptyState
        self.lastActiveDecksFingerprint = currentFp
        self.lastActiveDecksCheckTime = now
        return emptyState
    }
    
    // Si la session Serato a été explicitement clôturée dans SQLite (end_time > 0)
    if sessionEndTime > 0 {
        let emptyState = ActiveDecksState(deck1: nil, deck2: nil, latestEntryId: -1, hasActiveSession: false)
        self.cachedActiveDecksState = emptyState
        self.lastActiveDecksFingerprint = currentFp
        self.lastActiveDecksCheckTime = now
        return emptyState
    }
    
    // 2. Récupération des entrées de la session active avec enrichissement connection + asset
    let sql = """
    SELECT 
        h.id,
        h.asset_id,
        ifnull(nullif(h.name, ''), ifnull(a.name, '')),
        ifnull(nullif(h.artist, ''), ifnull(a.artist, '')),
        ifnull(nullif(h.bpm, 0.0), ifnull(a.bpm, 0.0)),
        ifnull(nullif(h.key, ''), ifnull(a.key, '')),
        ifnull(nullif(h.file_name, ''), ifnull(a.file_name, '')),
        ifnull(h.portable_id, ''),
        ifnull(h.deck, ''),
        h.start_time,
        h.end_time,
        ifnull(nullif(h.length_sec, 0), ifnull(a.length_sec, 0)),
        ifnull(nullif(h.genre, ''), ifnull(a.genre, '')),
        CASE
            WHEN h.portable_id LIKE 'streaming://%' THEN h.portable_id
            WHEN c.database_uri LIKE '%/_Serato_/%'
                THEN substr(c.database_uri, 1, instr(c.database_uri, '/_Serato_/') - 1)
                     || '/' || h.portable_id
            WHEN h.portable_id LIKE '/%' THEN h.portable_id
            ELSE '/' || h.portable_id
        END AS sql_resolved_path
    FROM history_entry h
    LEFT JOIN connection c ON c.location_id = h.location_id
    LEFT JOIN asset a ON a.id = h.asset_id
    WHERE h.session_id = \(latestSessionId)
    ORDER BY h.id DESC;
    """
    
    var stmt: OpaquePointer?
    var d1Track: Track? = nil
    var d2Track: Track? = nil
    var maxEntryId: Int = -1
    let nowUnix = Date().timeIntervalSince1970
    
    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
        defer { sqlite3_finalize(stmt) }
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
            let genre = sqlite3_column_text(stmt, 12).map { String(cString: $0) } ?? ""
            
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
            let sqlPath = sqlite3_column_text(stmt, 13).map { String(cString: $0) } ?? ""
            
            let resolvedPath: String?
            if sqlPath.hasPrefix("streaming://") {
                resolvedPath = sqlPath
            } else if !sqlPath.isEmpty && FileManager.default.fileExists(atPath: sqlPath) {
                resolvedPath = sqlPath
            } else {
                resolvedPath = resolveTrackFilePath(portableId: portableId, fileName: fileName)
            }
            
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
                genre: genre,
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
    }
    
    let state = ActiveDecksState(
        deck1: d1Track,
        deck2: d2Track,
        latestEntryId: maxEntryId,
        hasActiveSession: true
    )
    self.cachedActiveDecksState = state
    self.lastActiveDecksFingerprint = currentFp
    self.lastActiveDecksCheckTime = now
    return state
    }
}
    
    /// Récupère les derniers morceaux enregistrés dans l'historique global
    public func fetchLatestPlayedTracks(limit: Int = 6) -> [Track] {
        return Self.queue.sync {
            guard let db = openDatabase() else { return [] }
            defer { sqlite3_close_v2(db) }
            
            let sql = """
            SELECT 
                h.id,
                h.asset_id,
                ifnull(nullif(h.name, ''), ifnull(a.name, '')),
                ifnull(nullif(h.artist, ''), ifnull(a.artist, '')),
                ifnull(nullif(h.bpm, 0.0), ifnull(a.bpm, 0.0)),
                ifnull(nullif(h.key, ''), ifnull(a.key, '')),
                ifnull(nullif(h.file_name, ''), ifnull(a.file_name, '')),
                ifnull(h.portable_id, ''),
                ifnull(h.deck, ''),
                h.start_time,
                ifnull(nullif(h.genre, ''), ifnull(a.genre, '')),
                CASE
                    WHEN h.portable_id LIKE 'streaming://%' THEN h.portable_id
                    WHEN c.database_uri LIKE '%/_Serato_/%'
                        THEN substr(c.database_uri, 1, instr(c.database_uri, '/_Serato_/') - 1)
                             || '/' || h.portable_id
                    WHEN h.portable_id LIKE '/%' THEN h.portable_id
                    ELSE '/' || h.portable_id
                END AS sql_resolved_path
            FROM history_entry h
            LEFT JOIN connection c ON c.location_id = h.location_id
            LEFT JOIN asset a ON a.id = h.asset_id
            WHERE h.played = 1
            ORDER BY h.id DESC
            LIMIT \(limit);
            """
            
            var stmt: OpaquePointer?
            var tracks: [Track] = []
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                defer { sqlite3_finalize(stmt) }
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
                    let genre = sqlite3_column_text(stmt, 10).map { String(cString: $0) } ?? ""
                    let playedAt = Date(timeIntervalSince1970: TimeInterval(startTimeUnix))
                    let sqlPath = sqlite3_column_text(stmt, 11).map { String(cString: $0) } ?? ""
                    
                    let resolvedPath: String?
                    if sqlPath.hasPrefix("streaming://") {
                        resolvedPath = sqlPath
                    } else if !sqlPath.isEmpty && FileManager.default.fileExists(atPath: sqlPath) {
                        resolvedPath = sqlPath
                    } else {
                        resolvedPath = resolveTrackFilePath(portableId: portableId, fileName: fileName)
                    }
                    
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
                        genre: genre,
                        playedAt: playedAt
                    )
                    tracks.append(track)
                }
            }
            
            return tracks
        }
    }
    
    // MARK: - Algorithme de Suggestions d'Enchaînements STRICTEMENT basé sur l'Historique
    
    /// Calcule le Top des enchaînements réels joués après ou avant le morceau de référence
    /// dans les sessions Serato sur la période configurée (ex: 360 jours).
    /// EXCLUSION STRICTE : Ne s'appuie JAMAIS sur le nombre total de lectures de la bibliothèque (metadata).
    public func fetchTransitions(
        for referenceTrack: Track,
        direction: TransitionDirection = .next,
        daysLookback: Int = 360,
        maxResults: Int = 30
    ) -> [Track] {
        // --- MODE TOUT (AVANT + APRÈS COMBINÉS) ---
        if direction == .all {
            let nextResults = fetchTransitions(
                for: referenceTrack,
                direction: .next,
                daysLookback: daysLookback,
                maxResults: maxResults * 2
            )
            let prevResults = fetchTransitions(
                for: referenceTrack,
                direction: .previous,
                daysLookback: daysLookback,
                maxResults: maxResults * 2
            )
            
            var mergedMap: [String: Track] = [:]
            
            for trk in nextResults {
                let key = normalizeTitle(trk.displayTitle)
                mergedMap[key] = trk
            }
            
            for trk in prevResults {
                let key = normalizeTitle(trk.displayTitle)
                if var existing = mergedMap[key] {
                    existing.transitionCount += trk.transitionCount
                    existing.direction = .all
                    if let p1 = existing.playedAt, let p2 = trk.playedAt {
                        existing.playedAt = max(p1, p2)
                    } else {
                        existing.playedAt = existing.playedAt ?? trk.playedAt
                    }
                    mergedMap[key] = existing
                } else {
                    mergedMap[key] = trk
                }
            }
            
            var combined = Array(mergedMap.values)
            combined.sort(by: { (t1: Track, t2: Track) -> Bool in
                if t1.transitionCount != t2.transitionCount {
                    return t1.transitionCount > t2.transitionCount
                }
                let time1 = t1.playedAt?.timeIntervalSince1970 ?? 0
                let time2 = t2.playedAt?.timeIntervalSince1970 ?? 0
                if time1 != time2 {
                    return time1 > time2
                }
                return t1.displayTitle < t2.displayTitle
            })
            
            let sliced = Array(combined.prefix(maxResults))
            return sliced.map { track in
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
        
        return Self.queue.sync {
            guard let db = openDatabase() else { return [] }
            defer { sqlite3_close_v2(db) }
            
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
                limit: maxResults,
                direction: direction
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
                        limit: maxResults - suggestions.count,
                        direction: direction
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
            
            // --- NIVEAU 3 : Routines enchaînées (N+2 ou N-2 dans la même session) ---
            if suggestions.count < maxResults {
                let sequenceMatches = querySecondarySessionTransitions(
                    db: db,
                    referenceTrack: referenceTrack,
                    minStartTime: minStartTimeUnix,
                    limit: maxResults - suggestions.count,
                    excludeTitles: seenTitles,
                    direction: direction
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
          AND start_time >= \(minStartTime)
          AND \(Self.validSessionsFilter);
        """
        
        var stmt: OpaquePointer?
        let refCamelot = referenceTrack.camelotKey
        let refRawKey = referenceTrack.rawKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let refBpm = referenceTrack.bpm
        let refArtist = referenceTrack.smartParsed.artist?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedRefBase = normalizeTitle(baseTitle)
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
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
        }
        
        return (Array(variantAssetIds), Array(variantFileNames), Array(variantNames), baseTitle)
    }
    
    // MARK: - Requêtes SQL de Transitions Historiques
    
    /// Niveau 1 : Morceau joué immédiatement après (N+1) ou avant (N-1) dans la même session (avec cumul des variantes si activé)
    private func queryDirectTransitions(
        db: OpaquePointer,
        referenceTrack: Track,
        variantInfo: (assetIds: [Int], fileNames: [String], names: [String], baseTitle: String)?,
        minStartTime: Int64,
        limit: Int,
        direction: TransitionDirection = .next
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
        
        let sql: String
        if direction == .previous {
            sql = """
            WITH target_plays AS (
                SELECT id, session_id, asset_id, file_name, name, start_time
                FROM history_entry
                WHERE \(whereTarget)
                  AND start_time >= \(minStartTime)
                  AND \(Self.validSessionsFilter)
            ),
            prev_plays AS (
                SELECT 
                    h2.id as prev_id,
                    h2.asset_id as prev_asset_id,
                    coalesce(nullif(h2.name, ''), h2.file_name) as clean_title,
                    h2.artist as prev_artist,
                    h2.bpm as prev_bpm,
                    h2.key as prev_key,
                    h2.file_name as prev_file_name,
                    h2.portable_id as prev_portable_id,
                    h2.start_time as prev_start_time
                FROM target_plays tp
                JOIN history_entry h2 ON h2.session_id = tp.session_id
                    AND h2.start_time < tp.start_time
                    AND h2.start_time >= tp.start_time - 1200
                    AND h2.id != tp.id
                    \(whereExcludeSelf)
                    AND h2.played = 1
                WHERE h2.id = (
                    SELECT sub.id FROM history_entry sub
                    WHERE sub.session_id = tp.session_id
                      AND sub.start_time < tp.start_time
                      AND sub.played = 1
                    ORDER BY sub.start_time DESC
                    LIMIT 1
                )
            )
            SELECT 
                clean_title,
                prev_artist,
                avg(prev_bpm) as avg_bpm,
                prev_key,
                prev_file_name,
                prev_portable_id,
                prev_asset_id,
                count(*) as transition_count,
                max(prev_start_time) as last_played_time
            FROM prev_plays
            WHERE clean_title != ''
            GROUP BY clean_title, prev_artist
            ORDER BY transition_count DESC, last_played_time DESC
            LIMIT \(limit);
            """
        } else {
            sql = """
            WITH target_plays AS (
                SELECT id, session_id, asset_id, file_name, name, start_time
                FROM history_entry
                WHERE \(whereTarget)
                  AND start_time >= \(minStartTime)
                  AND \(Self.validSessionsFilter)
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
        }
        
        return executeTransitionQuery(db: db, sql: sql, matchType: .directTransition, direction: direction)
    }
    
    /// Niveau 2 : Morceau joué après ou avant une variante du titre de base (ex: Radio Edit vs Club Mix)
    private func queryBaseTitleTransitions(
        db: OpaquePointer,
        baseTitle: String,
        excludeAssetId: Int?,
        minStartTime: Int64,
        limit: Int,
        direction: TransitionDirection = .next
    ) -> [Track] {
        let safeBase = escapeSql(baseTitle)
        let excludeId = excludeAssetId ?? -1
        
        let sql: String
        if direction == .previous {
            sql = """
            WITH target_plays AS (
                SELECT id, session_id, asset_id, file_name, start_time
                FROM history_entry
                WHERE (name LIKE '%\(safeBase)%' OR file_name LIKE '%\(safeBase)%')
                  AND (asset_id != \(excludeId) OR \(excludeId) <= 0)
                  AND start_time >= \(minStartTime)
                  AND \(Self.validSessionsFilter)
            ),
            prev_plays AS (
                SELECT 
                    h2.id as prev_id,
                    h2.asset_id as prev_asset_id,
                    coalesce(nullif(h2.name, ''), h2.file_name) as clean_title,
                    h2.artist as prev_artist,
                    h2.bpm as prev_bpm,
                    h2.key as prev_key,
                    h2.file_name as prev_file_name,
                    h2.portable_id as prev_portable_id,
                    h2.start_time as prev_start_time
                FROM target_plays tp
                JOIN history_entry h2 ON h2.session_id = tp.session_id
                    AND h2.start_time < tp.start_time
                    AND h2.start_time >= tp.start_time - 1200
                    AND h2.id != tp.id
                    AND h2.name NOT LIKE '%\(safeBase)%'
                    AND h2.file_name NOT LIKE '%\(safeBase)%'
                    AND h2.played = 1
                WHERE h2.id = (
                    SELECT sub.id FROM history_entry sub
                    WHERE sub.session_id = tp.session_id
                      AND sub.start_time < tp.start_time
                      AND sub.played = 1
                    ORDER BY sub.start_time DESC
                    LIMIT 1
                )
            )
            SELECT 
                clean_title,
                prev_artist,
                avg(prev_bpm) as avg_bpm,
                prev_key,
                prev_file_name,
                prev_portable_id,
                prev_asset_id,
                count(*) as transition_count,
                max(prev_start_time) as last_played_time
            FROM prev_plays
            WHERE clean_title != ''
            GROUP BY clean_title, prev_artist
            ORDER BY transition_count DESC, last_played_time DESC
            LIMIT \(limit);
            """
        } else {
            sql = """
            WITH target_plays AS (
                SELECT id, session_id, asset_id, file_name, start_time
                FROM history_entry
                WHERE (name LIKE '%\(safeBase)%' OR file_name LIKE '%\(safeBase)%')
                  AND (asset_id != \(excludeId) OR \(excludeId) <= 0)
                  AND start_time >= \(minStartTime)
                  AND \(Self.validSessionsFilter)
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
        }
        
        return executeTransitionQuery(db: db, sql: sql, matchType: .sameSongVariant, direction: direction)
    }
    
    /// Niveau 3 : Deuxième morceau enchaîné dans la même session (N+2 ou N-2 - Routine de set)
    private func querySecondarySessionTransitions(
        db: OpaquePointer,
        referenceTrack: Track,
        minStartTime: Int64,
        limit: Int,
        excludeTitles: Set<String>,
        direction: TransitionDirection = .next
    ) -> [Track] {
        let safeFileName = escapeSql(referenceTrack.fileName)
        let assetId = referenceTrack.assetId ?? -1
        let safeTitle = escapeSql(referenceTrack.displayTitle)
        let safeRawTitle = escapeSql(referenceTrack.title)
        
        let sql: String
        if direction == .previous {
            sql = """
            WITH target_plays AS (
                SELECT id, session_id, asset_id, file_name, start_time
                FROM history_entry
                WHERE (
                    (asset_id > 0 AND asset_id = \(assetId))
                    OR (file_name != '' AND file_name = '\(safeFileName)')
                    OR (name != '' AND (name = '\(safeTitle)' OR name = '\(safeRawTitle)'))
                )
                AND start_time >= \(minStartTime)
                AND \(Self.validSessionsFilter)
            ),
            second_prev_plays AS (
                SELECT 
                    h3.id as prev_id,
                    h3.asset_id as prev_asset_id,
                    coalesce(nullif(h3.name, ''), h3.file_name) as clean_title,
                    h3.artist as prev_artist,
                    h3.bpm as prev_bpm,
                    h3.key as prev_key,
                    h3.file_name as prev_file_name,
                    h3.portable_id as prev_portable_id,
                    h3.start_time as prev_start_time
                FROM target_plays tp
                JOIN history_entry h3 ON h3.session_id = tp.session_id
                    AND h3.start_time < tp.start_time
                    AND h3.start_time >= tp.start_time - 1500
                    AND h3.played = 1
                WHERE (
                    SELECT count(*) FROM history_entry middle
                    WHERE middle.session_id = tp.session_id
                      AND middle.start_time < tp.start_time
                      AND middle.start_time > h3.start_time
                      AND middle.played = 1
                ) = 1
            )
            SELECT 
                clean_title,
                prev_artist,
                avg(prev_bpm) as avg_bpm,
                prev_key,
                prev_file_name,
                prev_portable_id,
                prev_asset_id,
                count(*) as transition_count,
                max(prev_start_time) as last_played_time
            FROM second_prev_plays
            WHERE clean_title != ''
            GROUP BY clean_title, prev_artist
            ORDER BY transition_count DESC, last_played_time DESC
            LIMIT \(limit * 2);
            """
        } else {
            sql = """
            WITH target_plays AS (
                SELECT id, session_id, asset_id, file_name, start_time
                FROM history_entry
                WHERE (
                    (asset_id > 0 AND asset_id = \(assetId))
                    OR (file_name != '' AND file_name = '\(safeFileName)')
                    OR (name != '' AND (name = '\(safeTitle)' OR name = '\(safeRawTitle)'))
                )
                AND start_time >= \(minStartTime)
                AND \(Self.validSessionsFilter)
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
        }
        
        let candidates = executeTransitionQuery(db: db, sql: sql, matchType: .routineSequence, direction: direction)
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
        matchType: MatchType,
        direction: TransitionDirection = .next
    ) -> [Track] {
        var results: [Track] = []
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let title = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
                let artist = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                let bpm = sqlite3_column_double(stmt, 2)
                let key = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                let fileName = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                let portableId = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
                let assetId = Int(sqlite3_column_int64(stmt, 6))
                let count = Int(sqlite3_column_int64(stmt, 7))
                let lastPlayedUnix = sqlite3_column_int64(stmt, 8)
                let playedAt = lastPlayedUnix > 0 ? Date(timeIntervalSince1970: TimeInterval(lastPlayedUnix)) : nil
                
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
                    playedAt: playedAt,
                    transitionCount: count,
                    matchType: matchType,
                    direction: direction
                )
                results.append(track)
            }
        }
        
        return results
    }
    
    // MARK: - Recherche de Morceaux dans la Bibliothèque Serato
    
    public func searchTracks(query: String, limit: Int = 30) -> [Track] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return Self.queue.sync {
            guard let db = openDatabase() else { return [] }
            defer { sqlite3_close_v2(db) }
            
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
                defer { sqlite3_finalize(stmt) }
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
            }
            
            return results
        }
    }
    
    // MARK: - Résolution des Fichiers Audio sur le Disque & Cache Volumes
    
    private static var cachedVolumes: (timestamp: Date, volumes: [String])? = nil
    private static let volumeCacheLock = NSLock()
    
    private static func getValidExternalVolumes() -> [String] {
        volumeCacheLock.lock()
        defer { volumeCacheLock.unlock() }
        
        let now = Date()
        if let cached = cachedVolumes, now.timeIntervalSince(cached.timestamp) < 5.0 {
            return cached.volumes
        }
        
        let fm = FileManager.default
        guard let list = try? fm.contentsOfDirectory(atPath: "/Volumes") else { return [] }
        let valid = list.filter { vol in
            !vol.hasPrefix(".") &&
            vol != "Macintosh HD" &&
            vol != "Recovery" &&
            !vol.lowercased().contains("timemachine")
        }
        cachedVolumes = (now, valid)
        return valid
    }
    
    public func resolveTrackFilePath(portableId: String, fileName: String) -> String? {
        let cleanPortable = portableId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPortable.isEmpty || !cleanFileName.isEmpty else { return nil }
        
        // 0. Piste streaming (Tidal, Beatsource, SoundCloud, etc.) : pas d'accès fichier disque
        if cleanPortable.hasPrefix("streaming://") {
            return cleanPortable
        }
        
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        
        // 1. portableId direct avec slash initial
        if cleanPortable.hasPrefix("/") && fm.fileExists(atPath: cleanPortable) {
            return cleanPortable
        }
        
        // 2. portableId débutant par "Users/..."
        if !cleanPortable.isEmpty {
            let slashPortable = "/" + cleanPortable
            if fm.fileExists(atPath: slashPortable) {
                return slashPortable
            }
        }
        
        // 3. Dossier de musique principal du DJ (REVR BIBLIOTHEQUE)
        if !cleanFileName.isEmpty {
            let revrPath = "\(home)/Music/REVR BIBLIOTHEQUE/\(cleanFileName)"
            if fm.fileExists(atPath: revrPath) {
                return revrPath
            }
        }
        
        // 4. Dossier ~/Music
        if !cleanFileName.isEmpty {
            let musicPath = "\(home)/Music/\(cleanFileName)"
            if fm.fileExists(atPath: musicPath) {
                return musicPath
            }
        }
        
        // 5. Chemin relatif dans le répertoire home
        if !cleanPortable.isEmpty {
            let candidateHome = "\(home)/\(cleanPortable)"
            if fm.fileExists(atPath: candidateHome) {
                return candidateHome
            }
        }
        
        // 6. Recherche sur les disques externes montés réels (/Volumes/*) avec cache anti-blocage
        let volumes = Self.getValidExternalVolumes()
        for vol in volumes {
            if !cleanPortable.isEmpty {
                let candidateVol = "/Volumes/\(vol)/\(cleanPortable)"
                if fm.fileExists(atPath: candidateVol) {
                    return candidateVol
                }
            }
            if !cleanFileName.isEmpty {
                let candidateVolFile = "/Volumes/\(vol)/_Serato_/\(cleanFileName)"
                if fm.fileExists(atPath: candidateVolFile) {
                    return candidateVolFile
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Recherche d'un Morceau par Fichier (Drag & Drop)
    
    public func findTrackByFile(filePath: String, fileName: String) -> Track? {
        return Self.queue.sync {
            guard let db = openDatabase() else { return nil }
            defer { sqlite3_close_v2(db) }
            
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
                defer { sqlite3_finalize(stmt) }
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let assetId = Int(sqlite3_column_int64(stmt, 0))
                    let title = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                    let artist = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                    let bpm = sqlite3_column_double(stmt, 3)
                    let key = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                    let fn = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
                    let pid = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? ""
                    
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
            }
            
            return nil
        }
    }
    
    /// Trouve un morceau dans la base Serato par son titre et son artiste (pour glisser-déposer sans chemin direct)
    public func findTrackByTitleArtist(title: String, artist: String = "") -> Track? {
        return Self.queue.sync {
            guard let db = openDatabase() else { return nil }
            defer { sqlite3_close_v2(db) }
            
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
                defer { sqlite3_finalize(stmt) }
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let assetId = Int(sqlite3_column_int64(stmt, 0))
                    let t = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                    let a = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                    let bpm = sqlite3_column_double(stmt, 3)
                    let key = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                    let fn = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
                    let pid = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? ""
                    
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
            }
            return nil
        }
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
        return Self.queue.sync {
            guard let db = openDatabase() else { return nil }
            defer { sqlite3_close_v2(db) }
            
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
    }
    
    /// Récupère toutes les entrées enregistrées depuis une date avec calcul de durée
    public func fetchSessionEntries(since: Date) -> [RawSessionEntry] {
        return Self.queue.sync {
            guard let db = openDatabase() else { return [] }
            defer { sqlite3_close_v2(db) }
            
            let sinceUnix = Int64(since.timeIntervalSince1970)
            let nowUnix = Date().timeIntervalSince1970
            
            let sql = """
            SELECT 
                h.id,
                ifnull(nullif(h.name, ''), ifnull(a.name, '')),
                ifnull(nullif(h.artist, ''), ifnull(a.artist, '')),
                ifnull(nullif(h.bpm, 0.0), ifnull(a.bpm, 0.0)),
                ifnull(nullif(h.key, ''), ifnull(a.key, '')),
                ifnull(nullif(h.file_name, ''), ifnull(a.file_name, '')),
                h.start_time,
                h.end_time,
                h.played,
                ifnull(nullif(h.genre, ''), ifnull(a.genre, '')),
                ifnull(nullif(h.length_sec, 0), ifnull(a.length_sec, 0))
            FROM history_entry h
            LEFT JOIN asset a ON a.id = h.asset_id
            WHERE h.start_time >= \(sinceUnix)
            ORDER BY h.start_time ASC;
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
                    let assetLengthSec = sqlite3_column_int64(stmt, 10)
                    
                    let startDate = Date(timeIntervalSince1970: TimeInterval(startUnix))
                    var endDate: Date? = nil
                    var duration: Double = 0.0
                    var isCurrent: Bool = false
                    
                    if endUnix > startUnix {
                        endDate = Date(timeIntervalSince1970: TimeInterval(endUnix))
                        duration = Double(endUnix - startUnix)
                    } else {
                        let elapsed = nowUnix - Double(startUnix)
                        let maxFreshDuration = assetLengthSec > 0 ? max(Double(assetLengthSec) * 2.5, 900.0) : 900.0
                        if elapsed >= 0 && elapsed <= maxFreshDuration {
                            isCurrent = true
                            duration = max(0.0, elapsed)
                        } else {
                            isCurrent = false
                            duration = assetLengthSec > 0 ? Double(assetLengthSec) : 180.0
                        }
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
    }
    
    // MARK: - Sessions Passées (Historique des Soirées Serato)
    
    public struct PastSessionItem: Identifiable, Hashable {
        public let id: Int
        public let startTime: Date
        public let endTime: Date?
        public let trackCount: Int
        public let notes: String?
        
        public init(id: Int, startTime: Date, endTime: Date?, trackCount: Int, notes: String? = nil) {
            self.id = id
            self.startTime = startTime
            self.endTime = endTime
            self.trackCount = trackCount
            self.notes = notes
        }
        
        /// Nom de l'établissement ou commentaire personnalisé de la soirée (ex: "PANAMA", "LE FIZZ", "Fizz")
        public var venue: String? {
            guard let n = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty else {
                return nil
            }
            return n
        }
        
        public var formattedTitle: String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "EEEE d MMMM yyyy"
            let dateStr = formatter.string(from: startTime).capitalized
            
            let timeFormatter = DateFormatter()
            timeFormatter.locale = Locale(identifier: "fr_FR")
            timeFormatter.dateFormat = "HH'h'mm"
            let startStr = timeFormatter.string(from: startTime)
            
            let endStr: String
            if let end = endTime {
                endStr = timeFormatter.string(from: end)
            } else {
                endStr = "En cours"
            }
            
            if let v = venue {
                return "📍 \(v) — \(dateStr) (\(startStr) - \(endStr) • \(trackCount) morceaux)"
            } else {
                return "📅 \(dateStr) (\(startStr) - \(endStr) • \(trackCount) morceaux)"
            }
        }
        
        public var shortTitle: String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "d MMM yyyy"
            let dateStr = formatter.string(from: startTime)
            
            if let v = venue {
                return "📍 \(v) • \(dateStr)"
            } else {
                return "\(dateStr) • \(trackCount) morceaux"
            }
        }
        
        public var fullFrenchDate: String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "EEEE d MMMM yyyy"
            let dateStr = formatter.string(from: startTime).capitalized
            
            if let v = venue {
                return "\(v) — \(dateStr)"
            } else {
                return dateStr
            }
        }
    }
    
    /// Récupère la liste des sessions passées réelles dans Serato (filtre les tests < 3 morceaux ou < 10 minutes)
    public func fetchPastSessions(limit: Int = 30, useCache: Bool = true) -> [PastSessionItem] {
        return Self.queue.sync {
            let currentFp = currentDatabaseFingerprint()
            if useCache, let cached = Self.cachedPastSessions, let lastFp = Self.lastPastSessionsFingerprint, lastFp == currentFp {
                return cached
            }
            
            guard let db = openDatabase() else { return Self.cachedPastSessions ?? [] }
            defer { sqlite3_close_v2(db) }
            
            let sql = """
            SELECT 
                s.id,
                s.start_time,
                s.end_time,
                count(DISTINCT lower(trim(ifnull(nullif(h.name, ''), ifnull(nullif(a.name, ''), ifnull(nullif(h.file_name, ''), '')))))) as track_count,
                ifnull(nullif(s.notes, ''), ifnull(s.comment, '')) as session_notes
            FROM history_session s
            JOIN history_entry h ON h.session_id = s.id AND h.played = 1
            LEFT JOIN asset a ON a.id = h.asset_id
            GROUP BY s.id
            HAVING track_count >= 3
               AND max(max(h.start_time, ifnull(h.end_time, 0))) - min(h.start_time) >= \(UserSettings.minimumSessionDurationSeconds)
            ORDER BY s.start_time DESC
            LIMIT \(limit);
            """
            
            var stmt: OpaquePointer?
            var list: [PastSessionItem] = []
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                defer { sqlite3_finalize(stmt) }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = Int(sqlite3_column_int64(stmt, 0))
                    let startUnix = sqlite3_column_int64(stmt, 1)
                    let endUnix = sqlite3_column_int64(stmt, 2)
                    let count = Int(sqlite3_column_int64(stmt, 3))
                    let notes = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                    
                    let startDate = Date(timeIntervalSince1970: TimeInterval(startUnix))
                    let endDate = endUnix > 0 ? Date(timeIntervalSince1970: TimeInterval(endUnix)) : nil
                    
                    list.append(PastSessionItem(
                        id: id,
                        startTime: startDate,
                        endTime: endDate,
                        trackCount: count,
                        notes: notes
                    ))
                }
            }
            if !list.isEmpty {
                Self.cachedPastSessions = list
                Self.lastPastSessionsFingerprint = currentFp
            }
            return list
        }
    }
    
    /// Récupère tous les morceaux confirmés comme joués pour une session Serato passée donnée
    public func fetchTracksForSession(sessionId: Int) -> [SessionPlayedTrack] {
        return Self.queue.sync {
            guard let db = openDatabase() else { return [] }
            defer { sqlite3_close_v2(db) }
            
            let sql = """
            SELECT 
                h.id,
                ifnull(nullif(h.name, ''), ifnull(a.name, '')),
                ifnull(nullif(h.artist, ''), ifnull(a.artist, '')),
                ifnull(nullif(h.bpm, 0.0), ifnull(a.bpm, 0.0)),
                ifnull(nullif(h.key, ''), ifnull(a.key, '')),
                ifnull(nullif(h.file_name, ''), ifnull(a.file_name, '')),
                h.start_time,
                h.end_time,
                ifnull(nullif(h.genre, ''), ifnull(a.genre, '')),
                ifnull(nullif(h.length_sec, 0), ifnull(a.length_sec, 0))
            FROM history_entry h
            LEFT JOIN asset a ON a.id = h.asset_id
            WHERE h.session_id = \(sessionId)
              AND h.played = 1
            ORDER BY h.start_time ASC;
            """
            
            var stmt: OpaquePointer?
            var validPlaysByTitle: [String: (title: String, artist: String, fileName: String, bpm: Double, rawKey: String, genre: String, lastTime: Date, maxDuration: Double, count: Int, isPlaying: Bool, startTime: Date, endTime: Date?)] = [:]
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                defer { sqlite3_finalize(stmt) }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let name = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                    let artist = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                    let bpm = sqlite3_column_double(stmt, 3)
                    let rawKey = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                    let fileName = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
                    let startUnix = sqlite3_column_int64(stmt, 6)
                    let endUnix = sqlite3_column_int64(stmt, 7)
                    let genre = sqlite3_column_text(stmt, 8).map { String(cString: $0) } ?? ""
                    let assetLengthSec = sqlite3_column_int64(stmt, 9)
                    
                    let title = !name.isEmpty ? name : (fileName as NSString).deletingPathExtension
                    guard !title.isEmpty else { continue }
                    
                    let startDate = Date(timeIntervalSince1970: TimeInterval(startUnix))
                    var endDate: Date? = nil
                    var duration: Double = 0.0
                    
                    if endUnix > startUnix {
                        endDate = Date(timeIntervalSince1970: TimeInterval(endUnix))
                        duration = Double(endUnix - startUnix)
                    } else if assetLengthSec > 0 {
                        duration = Double(assetLengthSec)
                    } else {
                        duration = 180.0
                    }
                    
                    let norm = FavoriteCombosService.normalize(title)
                    guard !norm.isEmpty else { continue }
                    
                    if var existing = validPlaysByTitle[norm] {
                        existing.lastTime = max(existing.lastTime, startDate)
                        existing.maxDuration = max(existing.maxDuration, duration)
                        existing.count += 1
                        if existing.bpm <= 0 && bpm > 0 { existing.bpm = bpm }
                        if existing.rawKey.isEmpty && !rawKey.isEmpty { existing.rawKey = rawKey }
                        if existing.genre.isEmpty && !genre.isEmpty { existing.genre = genre }
                        validPlaysByTitle[norm] = existing
                    } else {
                        validPlaysByTitle[norm] = (
                            title: title,
                            artist: artist,
                            fileName: fileName,
                            bpm: bpm,
                            rawKey: rawKey,
                            genre: genre,
                            lastTime: startDate,
                            maxDuration: duration,
                            count: 1,
                            isPlaying: false,
                            startTime: startDate,
                            endTime: endDate
                        )
                    }
                }
            }
            
            let sortedTracks = validPlaysByTitle.values
                .map { val in
                    SessionPlayedTrack(
                        id: "past_\(sessionId)_\(FavoriteCombosService.normalize(val.title))",
                        title: val.title,
                        artist: val.artist,
                        fileName: val.fileName,
                        playedAt: val.lastTime,
                        durationSeconds: val.maxDuration,
                        playCount: val.count,
                        bpm: val.bpm,
                        rawKey: val.rawKey,
                        genre: val.genre,
                        isCurrentlyPlaying: false,
                        startTime: val.startTime,
                        endTime: val.endTime
                    )
                }
                .sorted { a, b in
                    if a.playedAt != b.playedAt {
                        return a.playedAt > b.playedAt
                    }
                    return a.title < b.title
                }
            
            return sortedTracks
        }
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
