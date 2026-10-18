import Foundation
import Network
import Combine
import AppKit

// MARK: - Modèles GitHub Release

public struct GitHubRelease: Codable, Identifiable {
    public var id: String { tagName }
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlUrl: String
    public let publishedAt: String?
    public let assets: [GitHubAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

public struct GitHubAsset: Codable {
    public let name: String
    public let browserDownloadUrl: String
    public let size: Int?
    public let downloadCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
        case downloadCount = "download_count"
    }
}

// MARK: - Service de Mise à Jour Automatique

public class AutoUpdateService: ObservableObject {
    public static let shared = AutoUpdateService()
    
    @Published public var isUpdateAvailable: Bool = false
    @Published public var showUpdateBanner: Bool = true
    @Published public var availableUpdate: GitHubRelease? = nil
    @Published public var isChecking: Bool = false
    @Published public var manualCheckStatus: String? = nil
    
    private var hasCheckedOnStartup: Bool = false
    private let repoApiUrl = "https://api.github.com/repos/REVRmusic/recall/releases/latest"
    
    public init() {}
    
    /// Version courante de l'application Recall
    public var currentAppVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !version.isEmpty {
            return version
        }
        return "1.0.4"
    }
    
    // MARK: - Déclenchement au Démarrage de l'Application
    
    /// Recherche de mise à jour au démarrage :
    /// - Exécutée strictement une seule fois par lancement d'application
    /// - Différée de 3.0s pour garantir un démarrage instantané de l'interface et du deck DJ
    /// - Vérifie en amont la présence d'une connexion internet active (NWPathMonitor)
    /// - 100% asynchrone, protégée contre les erreurs réseau et sans aucun risque de blocage ou de crash
    public func checkForUpdatesOnStartup() {
        guard !hasCheckedOnStartup else { return }
        hasCheckedOnStartup = true
        
        // Délai de courtoisie de 3.0s : priorité absolue au démarrage instantané de Recall
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            
            // Vérification de la connectivité Internet
            let pathMonitor = NWPathMonitor()
            let monitorQueue = DispatchQueue(label: "fr.revr.recall.networkMonitor")
            
            pathMonitor.pathUpdateHandler = { [weak self] path in
                pathMonitor.cancel() // Libération immédiate du moniteur
                
                // Si l'ordinateur n'est pas connecté à Internet (ex : club, festival, mode avion)
                guard path.status == .satisfied else {
                    // Sortie silencieuse : aucun appel réseau, aucun log invasif, zéro impact sur les performances
                    return
                }
                
                // Connecté à Internet : recherche asynchrone de la dernière release
                self?.performReleaseCheck(isManual: false)
            }
            
            pathMonitor.start(queue: monitorQueue)
        }
    }
    
    // MARK: - Vérification Manuelle (depuis la modale des Paramètres)
    
    public func checkForUpdatesManually() {
        guard !isChecking else { return }
        isChecking = true
        manualCheckStatus = "Vérification en cours..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let pathMonitor = NWPathMonitor()
            let monitorQueue = DispatchQueue(label: "fr.revr.recall.manualNetworkMonitor")
            
            pathMonitor.pathUpdateHandler = { [weak self] path in
                pathMonitor.cancel()
                
                guard path.status == .satisfied else {
                    DispatchQueue.main.async {
                        self?.manualCheckStatus = "Aucune connexion Internet détectée."
                        self?.isChecking = false
                    }
                    return
                }
                
                self?.performReleaseCheck(isManual: true)
            }
            
            pathMonitor.start(queue: monitorQueue)
        }
    }
    
    // MARK: - Requête GitHub Releases
    
    private func performReleaseCheck(isManual: Bool) {
        guard let url = URL(string: repoApiUrl) else {
            if isManual {
                DispatchQueue.main.async {
                    self.manualCheckStatus = "URL de mise à jour invalide."
                    self.isChecking = false
                }
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0 // Timeout strict de 5 secondes
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Recall-macOS/\(currentAppVersion)", forHTTPHeaderField: "User-Agent")
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 5.0
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Gestion des erreurs réseau sans planter
            if error != nil {
                if isManual {
                    DispatchQueue.main.async {
                        self.manualCheckStatus = "Impossible de joindre le serveur de mise à jour."
                        self.isChecking = false
                    }
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data else {
                if isManual {
                    DispatchQueue.main.async {
                        self.manualCheckStatus = "Aucune mise à jour disponible."
                        self.isChecking = false
                    }
                }
                return
            }
            
            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let current = self.currentAppVersion
                
                if Self.isVersion(release.tagName, greaterThan: current) {
                    DispatchQueue.main.async {
                        self.availableUpdate = release
                        self.isUpdateAvailable = true
                        self.showUpdateBanner = true
                        if isManual {
                            self.manualCheckStatus = "Mise à jour disponible : \(release.tagName)"
                            self.isChecking = false
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isUpdateAvailable = false
                        if isManual {
                            self.manualCheckStatus = "Recall est à jour (v\(current))."
                            self.isChecking = false
                        }
                    }
                }
            } catch {
                if isManual {
                    DispatchQueue.main.async {
                        self.manualCheckStatus = "Erreur de lecture de la version."
                        self.isChecking = false
                    }
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Actions Utilisateur
    
    public func dismissBanner() {
        showUpdateBanner = false
    }
    
    public func openDownload() {
        guard let update = availableUpdate else { return }
        
        // 1. Recherche prioritaire du fichier .dmg pour macOS
        if let dmgAsset = update.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }),
           let url = URL(string: dmgAsset.browserDownloadUrl) {
            NSWorkspace.shared.open(url)
            return
        }
        
        // 2. Recherche alternative du fichier zip macOS
        if let zipAsset = update.assets.first(where: { $0.name.lowercased().contains("mac") && $0.name.lowercased().hasSuffix(".zip") }),
           let url = URL(string: zipAsset.browserDownloadUrl) {
            NSWorkspace.shared.open(url)
            return
        }
        
        // 3. Repli vers la page web de la release GitHub
        if let htmlUrl = URL(string: update.htmlUrl) {
            NSWorkspace.shared.open(htmlUrl)
        }
    }
    
    // MARK: - Comparaison de Versions Sémantiques (SemVer)
    
    public static func parseVersionComponents(_ version: String) -> [Int] {
        var clean = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.lowercased().hasPrefix("v") {
            clean = String(clean.dropFirst())
        }
        if let dashIndex = clean.firstIndex(of: "-") {
            clean = String(clean[..<dashIndex])
        }
        return clean.split(separator: ".").compactMap { Int($0) }
    }
    
    public static func isVersion(_ remote: String, greaterThan current: String) -> Bool {
        let remoteParts = parseVersionComponents(remote)
        let currentParts = parseVersionComponents(current)
        
        let maxCount = max(remoteParts.count, currentParts.count)
        guard maxCount > 0 else { return false }
        
        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }
}
