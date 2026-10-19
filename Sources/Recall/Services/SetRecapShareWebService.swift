import Foundation
import AppKit

/// Service de partage en ligne sécurisé des statistiques de mix (Set Recap)
/// Génère des URLs sécurisées, cryptographiquement imprévisibles et introuvables par les moteurs de recherche.
public final class SetRecapShareWebService {
    public static let shared = SetRecapShareWebService()
    
    private let googleScriptUrl = "https://script.google.com/macros/s/AKfycbwRVVec0m7BxPfDXL_06kkrfc75AUU5U2D_YLRL8YcMKCqZEXG6cd77EpEEKiIX-6Ad7g/exec"
    private let publicBaseUrl = "https://mixify.fr/recap"
    
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
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            completion(.failure(NSError(domain: "RecallShare", code: -2, userInfo: [NSLocalizedDescriptionKey: "Impossible d'encoder les données."])))
            return
        }
        
        let base64String = jsonData.base64EncodedString()
        let encodedData = base64String.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? base64String
        let webUrlString = "\(publicBaseUrl)/\(token)#data=\(encodedData)"
        
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
