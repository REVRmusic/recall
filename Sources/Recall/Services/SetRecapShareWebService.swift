import Foundation
import AppKit

/// Service de partage en ligne sécurisé des statistiques de mix (Set Recap)
/// Génère des URLs sécurisées, cryptographiquement imprévisibles et introuvables par les moteurs de recherche.
public final class SetRecapShareWebService {
    public static let shared = SetRecapShareWebService()
    
    private let supabaseUrl = "https://qyvbnfcngltkgaercyby.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF5dmJuZmNuZ2x0a2dhZXJjeWJ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQ2ODg5MzAsImV4cCI6MjA1MDI2NDkzMH0.UXPQPSAlYmu2kaWY3fzVnEpY32ckPzzQRCsnpdrK3Sw"
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
    
    /// Publie les statistiques du set sur la base de données et génère l'URL sécurisée
    public func publishSetRecap(
        stats: SetRecapStats,
        sessionStartTime: Date,
        sessionTitle: String,
        hideDuration: Bool = false,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let token = generateSecureShareToken()
        let webUrlString = "\(publicBaseUrl)/\(token)"
        guard let webUrl = URL(string: webUrlString) else {
            completion(.failure(NSError(domain: "RecallShare", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL invalide."])))
            return
        }
        
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
        
        // Sérialisation des statistiques
        let statsDict: [String: Any] = [
            "totalTracksCount": stats.totalTracksCount,
            "totalPlaysCount": stats.totalPlaysCount,
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
        payload["stats"] = statsDict
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            completion(.failure(NSError(domain: "RecallShare", code: -2, userInfo: [NSLocalizedDescriptionKey: "Impossible d'encoder les données."])))
            return
        }
        
        guard let endpoint = URL(string: "\(supabaseUrl)/rest/v1/dj_set_recaps") else {
            completion(.failure(NSError(domain: "RecallShare", code: -3, userInfo: [NSLocalizedDescriptionKey: "Point d'accès Supabase invalide."])))
            return
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData
        request.timeoutInterval = 10.0
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                        // Copie automatique du lien dans le presse-papier macOS
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(webUrlString, forType: .string)
                        completion(.success(webUrl))
                    } else if httpResponse.statusCode == 404 {
                        let desc = "La table de récapitulatif (dj_set_recaps) n'est pas encore créée sur le serveur."
                        completion(.failure(NSError(domain: "RecallShare", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: desc])))
                    } else {
                        let serverMsg = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Erreur HTTP \(httpResponse.statusCode)"
                        completion(.failure(NSError(domain: "RecallShare", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: serverMsg])))
                    }
                } else {
                    completion(.failure(NSError(domain: "RecallShare", code: -4, userInfo: [NSLocalizedDescriptionKey: "Réponse serveur invalide."])))
                }
            }
        }
        task.resume()
    }
}
