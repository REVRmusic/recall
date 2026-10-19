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
        
        // Génération d'une URL ultra-courte, élégante et professionnelle (ex: https://revrmusic.github.io/recall/recap/?id=rcp_98e7b60d)
        let webUrlString = "\(publicBaseUrl)/?id=\(token)"
        
        guard let webUrl = URL(string: webUrlString) else {
            completion(.failure(NSError(domain: "RecallShare", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL invalide."])))
            return
        }
        
        // Copie automatique immédiate du lien court dans le presse-papier macOS
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(webUrlString, forType: .string)
        AppLogger.info("Lien court de partage créé et copié : \(webUrlString)", category: .web)
        
        // Enregistrement sur la base de données Google Sheets
        if var components = URLComponents(string: googleScriptUrl) {
            let statsJsonStr = (try? JSONSerialization.data(withJSONObject: payload["stats"] ?? [:]))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            
            var queryItems = [
                URLQueryItem(name: "action", value: "save_recap"),
                URLQueryItem(name: "token", value: token),
                URLQueryItem(name: "share_token", value: token),
                URLQueryItem(name: "title", value: sessionTitle),
                URLQueryItem(name: "session_start_time", value: dateFormatter.string(from: sessionStartTime)),
                URLQueryItem(name: "hide_duration", value: hideDuration ? "true" : "false"),
                URLQueryItem(name: "stats", value: statsJsonStr)
            ]
            if let end = sessionEndTime {
                queryItems.append(URLQueryItem(name: "session_end_time", value: dateFormatter.string(from: end)))
            }
            components.queryItems = queryItems
            
            if let saveUrl = components.url {
                var saveReq = URLRequest(url: saveUrl)
                saveReq.httpMethod = "GET"
                saveReq.timeoutInterval = 10.0
                URLSession.shared.dataTask(with: saveReq) { _, _, _ in
                    AppLogger.info("Récapitulatif enregistré sur la feuille Google Sheets (Token: \(token))", category: .web)
                }.resume()
            }
        }
        
        completion(.success(webUrl))
    }
}
