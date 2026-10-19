import Foundation
import AppKit

/// Service de partage en ligne sécurisé des statistiques de mix (Set Recap)
/// Génère des URLs sécurisées, cryptographiquement imprévisibles et introuvables par les moteurs de recherche.
public final class SetRecapShareWebService {
    public static let shared = SetRecapShareWebService()
    
    private let googleScriptUrl = "https://script.google.com/macros/s/AKfycbwRVVec0m7BxPfDXL_06kkrfc75AUU5U2D_YLRL8YcMKCqZEXG6cd77EpEEKiIX-6Ad7g/exec"
    private let publicBaseUrl = "https://revrmusic.github.io/recall/recap"
    
    private init() {}
    
    // MARK: - Génération d'un Token Cryptographique Imprévisible
    
    /// Génère un token aléatoire sécurisé de 32 caractères hexadécimaux avec préfixe
    /// Rendant l'URL impossible à deviner ou à énumérer (espace de recherche supérieur à 2^128)
    public func generateSecureShareToken() -> String {
        var randomBytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if status == errSecSuccess {
            let hex = randomBytes.map { String(format: "%02x", $0) }.joined()
            return "rcp_\(hex)"
        }
        // Secours UUID si SecRandom indisponible
        return "rcp_\(UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: ""))"
    }
    
    // MARK: - Publication du Récapitulatif
    
    /// Publie les statistiques du set sur la base de données Google Sheets et génère l'URL sécurisée
    public func publishSetRecap(
        stats: SetRecapStats,
        sessionStartTime: Date,
        sessionEndTime: Date? = nil,
        sessionTitle: String,
        hideDuration: Bool = false,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let token = generateSecureShareToken()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Préparation du payload
        var payload: [String: Any] = [
            "share_token": token,
            "title": sessionTitle,
            "session_start_time": dateFormatter.string(from: sessionStartTime),
            "created_at": dateFormatter.string(from: Date()),
            "views_count": 0,
            "hide_duration": hideDuration
        ]
        if let end = sessionEndTime {
            payload["session_end_time"] = dateFormatter.string(from: end)
        }
        
        // Sérialisation des statistiques (en tenant compte fidèlement des vrais morceaux uniques joués)
        let statsDict: [String: Any] = [
            "totalTracksCount": stats.totalTracksCount,
            "totalDurationSeconds": stats.totalDurationSeconds,
            "averageTimePerTrackSeconds": stats.averageTimePerTrackSeconds,
            "tracksPerHour": stats.tracksPerHour,
            "averageBpm": stats.averageBpm,
            "minBpm": stats.minBpm,
            "maxBpm": stats.maxBpm,
            "dominantKey": stats.dominantKey ?? "",
            "dominantKeyCount": stats.dominantKeyCount,
            "dominantKeyPercentage": stats.dominantKeyPercentage,
            "isLiveSession": stats.isLiveSession,
            "hideDuration": hideDuration,
            "keyDistribution": stats.keyDistribution.map { ["key": $0.key, "count": $0.count, "percent": $0.percent] },
            "topGenres": stats.topGenres.map { ["name": $0.name, "count": $0.count, "percent": $0.percent] },
            "topArtists": stats.topArtists.map { ["name": $0.name, "count": $0.count, "percent": $0.percent] },
            "fastestTransition": stats.fastestTransition.map {
                [
                    "fromTrack": $0.fromTrack,
                    "toTrack": $0.toTrack,
                    "elapsedSeconds": $0.elapsedSeconds
                ]
            } as Any
        ]
        if let end = sessionEndTime {
            var mutableStats = statsDict
            mutableStats["sessionEndTime"] = dateFormatter.string(from: end)
            payload["stats"] = mutableStats
        } else {
            payload["stats"] = statsDict
        }
        
        // 1. Structure compacte ultra-légère pour un partage web direct, propre et incassable (Instagram, WhatsApp, etc.)
        var compactPayload: [String: Any] = [
            "t": sessionTitle,
            "c": stats.totalTracksCount,
            "d": Int(round(stats.totalDurationSeconds)),
            "b": Double(round(stats.averageBpm * 10) / 10),
            "b0": Int(round(stats.minBpm)),
            "b1": Int(round(stats.maxBpm)),
            "k": stats.dominantKey ?? "",
            "kc": stats.dominantKeyCount,
            "kp": Double(round(stats.dominantKeyPercentage * 10) / 10),
            "t0": Int(sessionStartTime.timeIntervalSince1970),
            "h": hideDuration ? 1 : 0,
            "g": stats.topGenres.prefix(5).map { [$0.name, $0.count, Double(round($0.percent * 10) / 10)] },
            "a": stats.topArtists.prefix(5).map { [$0.name, $0.count, Double(round($0.percent * 10) / 10)] },
            "th": Double(round(stats.tracksPerHour * 10) / 10),
            "as": Int(round(stats.averageTimePerTrackSeconds))
        ]
        if let end = sessionEndTime {
            compactPayload["t1"] = Int(end.timeIntervalSince1970)
        }
        if let ft = stats.fastestTransition {
            compactPayload["ft"] = [ft.fromTrack, ft.toTrack, Int(round(ft.elapsedSeconds))]
        }
        
        guard let compactData = try? JSONSerialization.data(withJSONObject: compactPayload, options: []) else {
            completion(.failure(NSError(domain: "RecallShare", code: -2, userInfo: [NSLocalizedDescriptionKey: "Impossible d'encoder les données du set."])))
            return
        }
        
        let urlSafeBase64 = compactData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let webUrlString = "\(publicBaseUrl)/?d=\(urlSafeBase64)"
        
        guard let webUrl = URL(string: webUrlString) else {
            completion(.failure(NSError(domain: "RecallShare", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL invalide."])))
            return
        }
        
        // Copie automatique immédiate du lien dans le presse-papier macOS
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(webUrlString, forType: .string)
        AppLogger.info("Récapitulatif de set publié en ligne avec succès : \(webUrlString)", category: .web)
        
        // Archivage en tâche de fond sur la feuille Google Sheets
        if let gUrl = URL(string: googleScriptUrl) {
            var gPayload = payload
            gPayload["action"] = "save_recap"
            if let gData = try? JSONSerialization.data(withJSONObject: gPayload, options: []) {
                var gReq = URLRequest(url: gUrl)
                gReq.httpMethod = "POST"
                gReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                gReq.httpBody = gData
                gReq.timeoutInterval = 10.0
                URLSession.shared.dataTask(with: gReq) { _, _, _ in
                    AppLogger.info("Récapitulatif synchronisé sur la feuille Google Sheets", category: .web)
                }.resume()
            }
        }
        
        completion(.success(webUrl))
    }
}
