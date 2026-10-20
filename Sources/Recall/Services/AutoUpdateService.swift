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

// MARK: - Service de Mise à Jour Automatique (Téléchargement, Déquarantaine & Installation 1-Clic)

public class AutoUpdateService: ObservableObject {
    public static let shared = AutoUpdateService()
    
    @Published public var isUpdateAvailable: Bool = false
    @Published public var showUpdateBanner: Bool = true
    @Published public var availableUpdate: GitHubRelease? = nil
    @Published public var isChecking: Bool = false
    @Published public var manualCheckStatus: String? = nil
    
    // États d'installation automatique
    @Published public var isInstalling: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var installStatus: String? = nil
    @Published public var installError: String? = nil
    
    private var hasCheckedOnStartup: Bool = false
    private var progressObservation: NSKeyValueObservation?
    private var activeDownloadTask: URLSessionDownloadTask?
    private let repoApiUrl = "https://api.github.com/repos/REVRmusic/recall/releases/latest"
    
    public init() {}
    
    /// Version courante de l'application Recall
    public var currentAppVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !version.isEmpty {
            return version
        }
        return "1.0.9"
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
        
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            
            let pathMonitor = NWPathMonitor()
            let monitorQueue = DispatchQueue(label: "fr.revr.recall.networkMonitor")
            
            pathMonitor.pathUpdateHandler = { [weak self] path in
                pathMonitor.cancel()
                guard path.status == .satisfied else { return }
                self?.performReleaseCheck(isManual: false)
            }
            
            pathMonitor.start(queue: monitorQueue)
        }
    }
    
    // MARK: - Vérification Manuelle (depuis la modale des Paramètres)
    
    public func checkForUpdatesManually() {
        guard !isChecking, !isInstalling else { return }
        isChecking = true
        installError = nil
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
        request.timeoutInterval = 6.0
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Recall-macOS/\(currentAppVersion)", forHTTPHeaderField: "User-Agent")
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6.0
        config.timeoutIntervalForResource = 6.0
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
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
    
    // MARK: - Installation Automatique en 1 Clic (Sans Quarantaine Gatekeeper)
    
    public func dismissBanner() {
        showUpdateBanner = false
    }
    
    /// Lance le téléchargement et l'installation automatique de la mise à jour en tâche de fond,
    /// supprime l'attribut de quarantaine Gatekeeper (`xattr -cr`), applique la signature ad-hoc stable
    /// et relance automatiquement Recall.
    public func installUpdate() {
        guard !isInstalling else { return }
        guard let update = availableUpdate else { return }
        
        // Préférence pour l'archive ZIP macOS (extraction directe via ditto sans monter de volume DMG)
        let zipAsset = update.assets.first(where: {
            $0.name.lowercased().contains("mac") && $0.name.lowercased().hasSuffix(".zip")
        })
        let dmgAsset = update.assets.first(where: {
            $0.name.lowercased().hasSuffix(".dmg")
        })
        
        guard let chosenAsset = zipAsset ?? dmgAsset,
              let assetURL = URL(string: chosenAsset.browserDownloadUrl) else {
            openBrowserFallback()
            return
        }
        
        let isZip = chosenAsset.name.lowercased().hasSuffix(".zip")
        
        DispatchQueue.main.async {
            self.isInstalling = true
            self.installError = nil
            self.downloadProgress = 0.02
            self.installStatus = "Téléchargement de Recall \(update.tagName)…"
        }
        
        var request = URLRequest(url: assetURL)
        request.setValue("Recall-macOS/\(currentAppVersion)", forHTTPHeaderField: "User-Agent")
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 300.0
        let session = URLSession(configuration: config)
        
        let downloadTask = session.downloadTask(with: request) { [weak self] tempLocalURL, response, error in
            guard let self = self else { return }
            self.progressObservation?.invalidate()
            self.progressObservation = nil
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.installError = "Échec du téléchargement : \(error.localizedDescription)"
                    self.installStatus = nil
                }
                return
            }
            
            guard let httpResp = response as? HTTPURLResponse,
                  (200...299).contains(httpResp.statusCode),
                  let tempLocalURL = tempLocalURL else {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.installError = "Le fichier de mise à jour est introuvable sur le serveur."
                    self.installStatus = nil
                }
                return
            }
            
            // Copie immédiate du fichier temporaire avant que URLSession ne le supprime
            let workDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("RecallUpdate-\(UUID().uuidString)", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
                let archivePath = workDir.appendingPathComponent(isZip ? "Recall-macOS.zip" : "Recall.dmg")
                try FileManager.default.moveItem(at: tempLocalURL, to: archivePath)
                
                DispatchQueue.main.async {
                    self.downloadProgress = 0.85
                    self.installStatus = "Préparation et vérification de l'application…"
                }
                
                self.extractPrepareAndRelaunch(archiveURL: archivePath, workDir: workDir, isZip: isZip)
            } catch {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.installError = "Erreur lors de la préparation : \(error.localizedDescription)"
                    self.installStatus = nil
                }
            }
        }
        
        progressObservation = downloadTask.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            let fraction = max(0.02, min(0.82, progress.fractionCompleted * 0.82))
            DispatchQueue.main.async {
                self?.downloadProgress = fraction
            }
        }
        
        activeDownloadTask = downloadTask
        downloadTask.resume()
    }
    
    /// Ancien nom conservé pour compatibilité : lance désormais l'installation automatique
    public func openDownload() {
        installUpdate()
    }
    
    /// Repli d'ouverture dans le navigateur uniquement si aucun asset binaire n'est attaché
    public func openBrowserFallback() {
        guard let update = availableUpdate else { return }
        if let dmgAsset = update.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }),
           let url = URL(string: dmgAsset.browserDownloadUrl) {
            NSWorkspace.shared.open(url)
            return
        }
        if let htmlUrl = URL(string: update.htmlUrl) {
            NSWorkspace.shared.open(htmlUrl)
        }
    }
    
    private func extractPrepareAndRelaunch(archiveURL: URL, workDir: URL, isZip: Bool) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            let extractDir = workDir.appendingPathComponent("extracted", isDirectory: true)
            try? fm.createDirectory(at: extractDir, withIntermediateDirectories: true)
            
            if isZip {
                // Extraction native macOS via ditto
                let status = Self.runProcess("/usr/bin/ditto", arguments: ["-x", "-k", archiveURL.path, extractDir.path])
                if status != 0 {
                    DispatchQueue.main.async {
                        self.isInstalling = false
                        self.installError = "Impossible de décompresser l'archive de mise à jour."
                        self.installStatus = nil
                    }
                    return
                }
            } else {
                // Montage silencieux du DMG
                let mountDir = workDir.appendingPathComponent("mount", isDirectory: true)
                try? fm.createDirectory(at: mountDir, withIntermediateDirectories: true)
                let attachStatus = Self.runProcess(
                    "/usr/bin/hdiutil",
                    arguments: ["attach", archiveURL.path, "-mountpoint", mountDir.path, "-nobrowse", "-quiet"]
                )
                guard attachStatus == 0 else {
                    DispatchQueue.main.async {
                        self.isInstalling = false
                        self.installError = "Impossible de monter l'image disque Recall.dmg."
                        self.installStatus = nil
                    }
                    return
                }
                let mountedApp = mountDir.appendingPathComponent("Recall.app")
                let targetExtractedApp = extractDir.appendingPathComponent("Recall.app")
                _ = Self.runProcess("/usr/bin/ditto", arguments: [mountedApp.path, targetExtractedApp.path])
                _ = Self.runProcess("/usr/bin/hdiutil", arguments: ["detach", mountDir.path, "-quiet", "-force"])
            }
            
            let stagedApp = extractDir.appendingPathComponent("Recall.app")
            guard fm.fileExists(atPath: stagedApp.path) else {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.installError = "Recall.app est absent de l'archive téléchargée."
                    self.installStatus = nil
                }
                return
            }
            
            DispatchQueue.main.async {
                self.downloadProgress = 0.94
                self.installStatus = "Validation de la signature macOS…"
            }
            
            // 1. Suppression intégrale de tout attribut de quarantaine Gatekeeper
            _ = Self.runProcess("/usr/bin/xattr", arguments: ["-cr", stagedApp.path])
            
            // 2. Permissions d'exécution sur le binaire principal
            let mainExecutable = stagedApp.appendingPathComponent("Contents/MacOS/Recall")
            _ = Self.runProcess("/bin/chmod", arguments: ["+x", mainExecutable.path])
            
            // 3. Signature ad-hoc avec designated requirement stable pour préserver les autorisations TCC / Accessibilité
            _ = Self.runProcess(
                "/usr/bin/codesign",
                arguments: [
                    "--force", "--deep", "--sign", "-",
                    "--identifier", "fr.revr.recall",
                    "-r=designated => identifier \"fr.revr.recall\"",
                    stagedApp.path
                ]
            )
            
            // 4. Détermination de l'emplacement cible (/Applications/Recall.app ou bundle courant)
            let currentBundlePath = Bundle.main.bundlePath
            let targetAppPath: String
            if currentBundlePath.hasSuffix(".app") && fm.isWritableFile(atPath: (currentBundlePath as NSString).deletingLastPathComponent) {
                targetAppPath = currentBundlePath
            } else {
                targetAppPath = "/Applications/Recall.app"
            }
            
            DispatchQueue.main.async {
                self.downloadProgress = 1.0
                self.installStatus = "Redémarrage de Recall…"
            }
            
            let pid = ProcessInfo.processInfo.processIdentifier
            let scriptPath = workDir.appendingPathComponent("install_update.sh")
            let scriptContent = """
            #!/bin/bash
            # Attendre la fermeture du processus actuel (max 5s)
            for i in $(seq 1 25); do
                if ! kill -0 \(pid) 2>/dev/null; then
                    break
                fi
                sleep 0.2
            done
            
            rm -rf "\(targetAppPath)" 2>/dev/null || true
            /usr/bin/ditto "\(stagedApp.path)" "\(targetAppPath)"
            
            # Si Recall était lancé depuis un autre dossier que /Applications, mettre aussi /Applications à jour
            if [ "\(targetAppPath)" != "/Applications/Recall.app" ] && [ -w "/Applications" ]; then
                rm -rf "/Applications/Recall.app" 2>/dev/null || true
                /usr/bin/ditto "\(stagedApp.path)" "/Applications/Recall.app"
                /usr/bin/xattr -cr "/Applications/Recall.app" 2>/dev/null || true
            fi
            
            /usr/bin/xattr -cr "\(targetAppPath)" 2>/dev/null || true
            /usr/bin/open -n "\(targetAppPath)"
            rm -rf "\(workDir.path)" 2>/dev/null || true
            """
            
            do {
                try scriptContent.write(to: scriptPath, atomically: true, encoding: .utf8)
                _ = Self.runProcess("/bin/chmod", arguments: ["+x", scriptPath.path])
                
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/bash")
                proc.arguments = [scriptPath.path]
                try proc.run()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    NSApplication.shared.terminate(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.installError = "Impossible de finaliser l'installation : \(error.localizedDescription)"
                    self.installStatus = nil
                }
            }
        }
    }
    
    @discardableResult
    private static func runProcess(_ launchPath: String, arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
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
