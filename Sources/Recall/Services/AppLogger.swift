import Foundation
import Cocoa
import os

/// Niveaux de sévérité des logs Recall
public enum LogLevel: String, Codable, Comparable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
    case fault = "FAULT"
    
    public var priority: Int {
        switch self {
        case .debug: return 1
        case .info: return 2
        case .warning: return 3
        case .error: return 4
        case .fault: return 5
        }
    }
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.priority < rhs.priority
    }
}

/// Catégories fonctionnelles pour identifier et filtrer les événements
public enum LogCategory: String, CaseIterable {
    case general = "General"
    case system = "System"
    case seratoDB = "SeratoDB"
    case session = "Session"
    case rekordbox = "Rekordbox"
    case export = "Export"
    case web = "Web"
    case update = "Update"
    case hotkey = "Hotkey"
    case ui = "UI"
}

/// Système de journalisation haute performance et ultra-léger pour Recall.
/// - Impact CPU quasi nul : exécution asynchrone par lots en arrière-plan (QoS Utility), aucun appel bloquant sur le thread audio/UI.
/// - Empreinte disque strictement plafonnée : taille maximale de 2 Mo par fichier, rotation à 2 archives (max 6 Mo au total).
/// - Nettoyage automatique : suppression des journaux de plus de 7 jours.
/// - Double émission : fichier local (~/Library/Logs/Recall/recall.log) + Apple Unified Logging (os.Logger).
public final class AppLogger {
    public static let shared = AppLogger()
    
    // MARK: - Constantes & Limites
    
    private let maxLogFileSizeBytes: Int64 = 2 * 1024 * 1024 // 2 Mo max par fichier
    private let maxRotatedFiles = 2                         // recall.1.log, recall.2.log
    private let maxBufferCount = 50                         // Flush automatique si 50 lignes en attente
    private let flushIntervalSeconds: TimeInterval = 5.0     // Flush périodique toutes les 5 secondes
    private let maxRetentionDays: TimeInterval = 7 * 24 * 3600 // 7 jours de rétention
    
    // MARK: - Propriétés internes
    
    private let queue = DispatchQueue(label: "fr.mixify.recall.logger", qos: .utility)
    private var memoryBuffer: [String] = []
    private var flushTimer: DispatchSourceTimer?
    private var isConfigured = false
    
    private let logsDirectory: URL
    private let currentLogFile: URL
    private let dateFormatter: DateFormatter
    
    private let osLoggers: [LogCategory: os.Logger]
    
    // MARK: - Initialisation
    
    private init() {
        // Dossier standard macOS : ~/Library/Logs/Recall/
        let appLogsURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Recall", isDirectory: true)
        
        self.logsDirectory = appLogsURL
        self.currentLogFile = appLogsURL.appendingPathComponent("recall.log")
        
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        df.timeZone = TimeZone.current
        self.dateFormatter = df
        
        var loggers: [LogCategory: os.Logger] = [:]
        for cat in LogCategory.allCases {
            loggers[cat] = os.Logger(subsystem: "fr.mixify.recall", category: cat.rawValue)
        }
        self.osLoggers = loggers
        
        setupDirectoryAndTimer()
    }
    
    deinit {
        flushTimer?.cancel()
        flushBufferSynchronously()
    }
    
    // MARK: - Configuration Initiale
    
    private func setupDirectoryAndTimer() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // 1. Création sécurisée du répertoire si inexistant
            if !FileManager.default.fileExists(atPath: self.logsDirectory.path) {
                try? FileManager.default.createDirectory(at: self.logsDirectory, withIntermediateDirectories: true)
            }
            
            // 2. Nettoyage initial des logs expirés (> 7 jours)
            self.purgeExpiredLogs()
            
            // 3. Configuration du timer de vidage par lots (Batch Flushing)
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + self.flushIntervalSeconds, repeating: self.flushIntervalSeconds)
            timer.setEventHandler { [weak self] in
                self?.flushBuffer()
            }
            timer.resume()
            self.flushTimer = timer
            self.isConfigured = true
            
            // Log de démarrage système
            self.appendEntry(
                level: .info,
                category: .system,
                message: "Recall démarré - Système de suivi actif (macOS \(ProcessInfo.processInfo.operatingSystemVersionString))",
                file: #file,
                line: #line,
                forceImmediateFlush: true
            )
        }
    }
    
    // MARK: - Méthodes Publiques de Journalisation (Autoclosures pour 0 CPU si inactif)
    
    public static func debug(
        _ message: @autoclosure () -> String,
        category: LogCategory = .general,
        file: String = #file,
        line: Int = #line
    ) {
        #if DEBUG
        shared.log(level: .debug, category: category, message: message(), file: file, line: line)
        #endif
    }
    
    public static func info(
        _ message: @autoclosure () -> String,
        category: LogCategory = .general,
        file: String = #file,
        line: Int = #line
    ) {
        shared.log(level: .info, category: category, message: message(), file: file, line: line)
    }
    
    public static func warning(
        _ message: @autoclosure () -> String,
        category: LogCategory = .general,
        file: String = #file,
        line: Int = #line
    ) {
        shared.log(level: .warning, category: category, message: message(), file: file, line: line)
    }
    
    public static func error(
        _ message: @autoclosure () -> String,
        category: LogCategory = .general,
        error: Error? = nil,
        file: String = #file,
        line: Int = #line
    ) {
        var msg = message()
        if let err = error {
            msg += " [Détails: \(err.localizedDescription)]"
        }
        shared.log(level: .error, category: category, message: msg, file: file, line: line, forceImmediateFlush: true)
    }
    
    public static func fault(
        _ message: @autoclosure () -> String,
        category: LogCategory = .general,
        error: Error? = nil,
        file: String = #file,
        line: Int = #line
    ) {
        var msg = message()
        if let err = error {
            msg += " [Détails: \(err.localizedDescription)]"
        }
        shared.log(level: .fault, category: category, message: msg, file: file, line: line, forceImmediateFlush: true)
    }
    
    // MARK: - Traitement Interne
    
    private func log(
        level: LogLevel,
        category: LogCategory,
        message: String,
        file: String,
        line: Int,
        forceImmediateFlush: Bool = false
    ) {
        // Envoi immédiat vers Apple Unified Logging (os.Logger)
        if let logger = osLoggers[category] {
            switch level {
            case .debug:
                logger.debug("\(message, privacy: .public)")
            case .info:
                logger.info("\(message, privacy: .public)")
            case .warning:
                logger.warning("\(message, privacy: .public)")
            case .error:
                logger.error("\(message, privacy: .public)")
            case .fault:
                logger.fault("\(message, privacy: .public)")
            }
        }
        
        // Envoi asynchrone dans le buffer fichier (non-bloquant)
        queue.async { [weak self] in
            self?.appendEntry(
                level: level,
                category: category,
                message: message,
                file: file,
                line: line,
                forceImmediateFlush: forceImmediateFlush
            )
        }
    }
    
    private func appendEntry(
        level: LogLevel,
        category: LogCategory,
        message: String,
        file: String,
        line: Int,
        forceImmediateFlush: Bool
    ) {
        let timestamp = dateFormatter.string(from: Date())
        let filename = (file as NSString).lastPathComponent
        let formattedLine = "[\(timestamp)] [\(level.rawValue)] [\(category.rawValue)] [\(filename):\(line)] \(message)\n"
        
        memoryBuffer.append(formattedLine)
        
        if forceImmediateFlush || memoryBuffer.count >= maxBufferCount {
            flushBuffer()
        }
    }
    
    // MARK: - Écriture Disque & Rotation
    
    private func flushBuffer() {
        guard !memoryBuffer.isEmpty else { return }
        
        let batch = memoryBuffer.joined()
        memoryBuffer.removeAll(keepingCapacity: true)
        
        writeToFile(batch)
    }
    
    private func flushBufferSynchronously() {
        queue.sync {
            guard !memoryBuffer.isEmpty else { return }
            let batch = memoryBuffer.joined()
            memoryBuffer.removeAll()
            writeToFile(batch)
        }
    }
    
    private func writeToFile(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        // Vérification de la rotation
        checkAndRotateLogFileIfNeeded(additionalBytes: Int64(data.count))
        
        if FileManager.default.fileExists(atPath: currentLogFile.path) {
            if let handle = try? FileHandle(forWritingTo: currentLogFile) {
                defer {
                    try? handle.close()
                }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                // Secours
                try? data.write(to: currentLogFile, options: .atomic)
            }
        } else {
            try? data.write(to: currentLogFile, options: .atomic)
        }
    }
    
    private func checkAndRotateLogFileIfNeeded(additionalBytes: Int64) {
        guard FileManager.default.fileExists(atPath: currentLogFile.path) else { return }
        
        var currentSize: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: currentLogFile.path),
           let size = attrs[.size] as? Int64 {
            currentSize = size
        }
        
        if currentSize + additionalBytes > maxLogFileSizeBytes {
            rotateLogs()
        }
    }
    
    private func rotateLogs() {
        let fm = FileManager.default
        
        // 1. Supprimer le fichier le plus ancien s'il existe (recall.2.log)
        let oldest = logsDirectory.appendingPathComponent("recall.\(maxRotatedFiles).log")
        if fm.fileExists(atPath: oldest.path) {
            try? fm.removeItem(at: oldest)
        }
        
        // 2. Décaler les archives existantes vers le numéro supérieur
        for i in (1..<maxRotatedFiles).reversed() {
            let src = logsDirectory.appendingPathComponent("recall.\(i).log")
            let dst = logsDirectory.appendingPathComponent("recall.\(i + 1).log")
            if fm.fileExists(atPath: src.path) {
                try? fm.moveItem(at: src, to: dst)
            }
        }
        
        // 3. Déplacer recall.log vers recall.1.log
        let archive1 = logsDirectory.appendingPathComponent("recall.1.log")
        if fm.fileExists(atPath: currentLogFile.path) {
            try? fm.moveItem(at: currentLogFile, to: archive1)
        }
    }
    
    private func purgeExpiredLogs() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else {
            return
        }
        
        let now = Date()
        for file in files where file.pathExtension == "log" {
            if let resourceValues = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = resourceValues.contentModificationDate {
                if now.timeIntervalSince(modDate) > maxRetentionDays {
                    try? fm.removeItem(at: file)
                }
            }
        }
    }
    
    // MARK: - Gestionnaire d'Exceptions / Crash
    
    /// Capture et écrit immédiatement les erreurs fatales avant fermeture
    public func registerCrashHandler() {
        NSSetUncaughtExceptionHandler { exception in
            AppLogger.shared.logUncaughtException(exception)
        }
    }
    
    public func logUncaughtException(_ exception: NSException) {
        let reason = exception.reason ?? "Aucune raison fournie"
        let name = exception.name.rawValue
        let stack = exception.callStackSymbols.joined(separator: "\n\t")
        
        let message = """
        [FATAL EXCEPTION CRASH]
        Exception: \(name)
        Raison: \(reason)
        Trace de la pile d'exécution :
        \t\(stack)
        """
        
        // Écriture synchrone prioritaire
        queue.sync {
            let timestamp = dateFormatter.string(from: Date())
            let line = "[\(timestamp)] [FAULT] [System] \(message)\n"
            writeToFile(line)
        }
    }
    
    // MARK: - Actions Utilisateur & Diagnostics
    
    /// Ouvre le dossier contenant les fichiers logs dans le Finder
    public func revealInFinder() {
        if !FileManager.default.fileExists(atPath: currentLogFile.path) {
            // Créer un fichier de log vide si nécessaire
            try? "".write(to: currentLogFile, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.selectFile(currentLogFile.path, inFileViewerRootedAtPath: logsDirectory.path)
    }
    
    /// Efface l'intégralité des journaux existants
    public func clearAllLogs() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.memoryBuffer.removeAll()
            
            let fm = FileManager.default
            if let files = try? fm.contentsOfDirectory(at: self.logsDirectory, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "log" {
                    try? fm.removeItem(at: file)
                }
            }
            
            self.appendEntry(
                level: .info,
                category: .system,
                message: "Tous les fichiers de logs ont été réinitialisés par l'utilisateur.",
                file: #file,
                line: #line,
                forceImmediateFlush: true
            )
        }
    }
    
    /// Calcule la taille cumulée des fichiers journaux sur le disque
    public func getLogFileSizeDescription() -> String {
        var totalBytes: Int64 = 0
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in files where file.pathExtension == "log" {
                if let attrs = try? fm.attributesOfItem(atPath: file.path),
                   let size = attrs[.size] as? Int64 {
                    totalBytes += size
                }
            }
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }
    
    /// Génère un rapport de diagnostic synthétique complet prêt à être partagé au support Mixify
    public func generateDiagnosticReport() -> String {
        var report = ""
        report += "=== RAPPORT DE DIAGNOSTIC RECALL ===\n"
        report += "Généré le : \(dateFormatter.string(from: Date()))\n"
        report += "Version de Recall : \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))\n"
        report += "Système : macOS \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        report += "Architecture : \(getSystemArchitecture())\n"
        report += "Processeur : \(ProcessInfo.processInfo.processorCount) cœurs\n"
        report += "Mémoire vive totale : \(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)) Go\n"
        report += "Taille des journaux locaux : \(getLogFileSizeDescription())\n"
        report += "Contact Support : support@mixify.fr\n"
        report += "Site web : https://mixify.fr\n\n"
        
        report += "=== ÉTAT DES SERVICES DJ ===\n"
        let runningApps = NSWorkspace.shared.runningApplications
        let seratoRunning = runningApps.contains { ($0.bundleIdentifier?.lowercased() ?? "").contains("serato") || ($0.localizedName?.lowercased() ?? "").contains("serato") }
        let rekordboxRunning = runningApps.contains { ($0.bundleIdentifier?.lowercased() ?? "").contains("rekordbox") || ($0.localizedName?.lowercased() ?? "").contains("rekordbox") }
        report += "Serato DJ Pro en cours : \(seratoRunning ? "OUI" : "NON")\n"
        report += "Rekordbox en cours : \(rekordboxRunning ? "OUI" : "NON")\n"
        report += "Chemin BDD configuré : \(UserSettings.shared.effectiveDatabasePath)\n\n"
        
        report += "=== DERNIERS ÉVÉNEMENTS (EXTRAIT LOGS) ===\n"
        if let logContent = try? String(contentsOf: currentLogFile, encoding: .utf8) {
            let lines = logContent.components(separatedBy: "\n").filter { !$0.isEmpty }
            let tail = lines.suffix(120).joined(separator: "\n")
            report += tail.isEmpty ? "(Aucun événement consigné dans ce fichier)" : tail
        } else {
            report += "(Fichier de log introuvable ou inaccessible)"
        }
        report += "\n=== FIN DU RAPPORT ===\n"
        
        return report
    }
    
    private func getSystemArchitecture() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { ptr in
                String(cString: ptr)
            }
        }
        return machine
    }
    
    /// Prépare la fermeture propre de l'application
    public func handleApplicationWillTerminate() {
        appendEntry(
            level: .info,
            category: .system,
            message: "Recall s'est arrêté proprement (Application Will Terminate)",
            file: #file,
            line: #line,
            forceImmediateFlush: true
        )
        flushBufferSynchronously()
    }
}
