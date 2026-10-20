import Foundation
import Combine
import Network
import AppKit
import CoreImage
import SwiftUI

/// Compagnon Téléphone : diffuse en direct l'état de la fenêtre principale de Recall
/// (morceau en cours, suggestions, Sélec) vers n'importe quel navigateur du réseau local (Wi‑Fi ou hotspot).
///
/// Fonctionne 100 % hors ligne : Recall embarque un mini serveur HTTP qui sert une page mobile
/// et pousse les mises à jour via Server-Sent Events (SSE). Aucune donnée ne quitte le réseau local.
@MainActor
public final class PhoneCompanionService: ObservableObject {
    public static let shared = PhoneCompanionService()
    
    public static let defaultPort: UInt16 = 8765
    
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var isStarting: Bool = false
    @Published public private(set) var connectedClients: Int = 0
    @Published public private(set) var lastError: String? = nil
    @Published public private(set) var localAddresses: [String] = []
    @Published public private(set) var activePort: UInt16 = PhoneCompanionService.defaultPort
    
    private var server: PhoneCompanionHTTPServer?
    private var addressRefreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var latestSnapshot: Data = Data()
    
    private init() {}
    
    // MARK: - URL d'accès
    
    /// URL complète à scanner (inclut le PIN pour une connexion sans saisie sur le téléphone)
    public var primaryURL: String? {
        guard let host = localAddresses.first else { return nil }
        return url(forHost: host)
    }
    
    public func url(forHost host: String) -> String {
        var str = "http://\(host):\(activePort)/"
        let pin = UserSettings.shared.phoneCompanionPin.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pin.isEmpty {
            str += "?pin=\(pin)"
        }
        return str
    }
    
    /// Nom Bonjour du Mac (ex: MacBook-Pro.local) utilisable depuis un iPhone sur le même réseau
    public var bonjourHostURL: String? {
        var host = ProcessInfo.processInfo.hostName
        if host.isEmpty || host == "localhost" { return nil }
        if !host.hasSuffix(".local") { host += ".local" }
        return url(forHost: host)
    }
    
    // MARK: - Cycle de vie
    
    public func setEnabled(_ enabled: Bool) {
        if enabled { start() } else { stop() }
    }
    
    public func start() {
        guard server == nil, !isStarting else { return }
        isStarting = true
        lastError = nil
        
        let configuredPort = UInt16(clamping: UserSettings.shared.phoneCompanionPort)
        activePort = configuredPort == 0 ? PhoneCompanionService.defaultPort : configuredPort
        
        let newServer = PhoneCompanionHTTPServer(port: activePort)
        newServer.pinProvider = {
            UserDefaults.standard.string(forKey: "phoneCompanionPin")?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        newServer.onReady = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isRunning = true
                self.isStarting = false
                self.lastError = nil
                self.refreshLocalAddresses()
                AppLogger.info("Compagnon Téléphone démarré sur le port \(self.activePort)", category: .web)
            }
        }
        newServer.onFailure = { [weak self] message in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.lastError = message
                AppLogger.error("Compagnon Téléphone : \(message)", category: .web)
                self.stop()
            }
        }
        newServer.onClientCountChange = { [weak self] count in
            Task { @MainActor [weak self] in
                self?.connectedClients = count
            }
        }
        
        server = newServer
        subscribeToStateChanges()
        publishSnapshot(force: true)
        
        addressRefreshTimer?.invalidate()
        addressRefreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshLocalAddresses() }
        }
        
        newServer.start()
    }
    
    public func stop() {
        guard let running = server else {
            isStarting = false
            isRunning = false
            return
        }
        server = nil
        running.stop()
        addressRefreshTimer?.invalidate()
        addressRefreshTimer = nil
        cancellables.removeAll()
        isRunning = false
        isStarting = false
        connectedClients = 0
        AppLogger.info("Compagnon Téléphone arrêté", category: .web)
    }
    
    public func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.start()
        }
    }
    
    // MARK: - Observation de l'état Recall
    
    private func subscribeToStateChanges() {
        cancellables.removeAll()
        let publishers: [AnyPublisher<Void, Never>] = [
            SeratoMonitorService.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            UserSettings.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            ToPlayService.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            SessionHistoryService.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(publishers)
            .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.publishSnapshot()
            }
            .store(in: &cancellables)
    }
    
    /// Reconstruit l'état JSON et le diffuse aux téléphones connectés si quelque chose a changé
    public func publishSnapshot(force: Bool = false) {
        guard let server else { return }
        let snapshot = PhoneCompanionSnapshotBuilder.build()
        guard let data = try? JSONSerialization.data(withJSONObject: snapshot, options: []) else { return }
        guard force || data != latestSnapshot else { return }
        latestSnapshot = data
        server.publish(snapshot: data)
    }
    
    // MARK: - Adresses réseau locales
    
    public func refreshLocalAddresses() {
        let addresses = PhoneCompanionService.localIPv4Addresses()
        if addresses != localAddresses {
            localAddresses = addresses
        }
    }
    
    /// Liste des adresses IPv4 des interfaces Wi‑Fi / Ethernet actives (en0 en premier)
    nonisolated public static func localIPv4Addresses() -> [String] {
        var found: [(name: String, ip: String)] = []
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return [] }
        defer { freeifaddrs(ifaddrPtr) }
        
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ptr = cursor {
            cursor = ptr.pointee.ifa_next
            let flags = Int32(bitPattern: ptr.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_RUNNING) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
            guard let addr = ptr.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: ptr.pointee.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("bridge") else { continue }
            
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            guard result == 0 else { continue }
            let ip = String(cString: host)
            guard !ip.hasPrefix("169.254.") else { continue }
            found.append((name, ip))
        }
        
        found.sort { a, b in
            if a.name == "en0" { return true }
            if b.name == "en0" { return false }
            return a.name < b.name
        }
        var seen = Set<String>()
        return found.compactMap { seen.insert($0.ip).inserted ? $0.ip : nil }
    }
}

// MARK: - Mini serveur HTTP + SSE (indépendant du thread principal)

/// Serveur HTTP minimaliste basé sur Network.framework.
/// Tout l'état interne est manipulé exclusivement sur `queue`.
final class PhoneCompanionHTTPServer {
    private final class Client {
        let connection: NWConnection
        var buffer = Data()
        var isSSE = false
        init(connection: NWConnection) { self.connection = connection }
    }
    
    let port: UInt16
    private let queue = DispatchQueue(label: "fr.revr.recall.phone-companion", qos: .userInitiated)
    private var listener: NWListener?
    private var clients: [ObjectIdentifier: Client] = [:]
    private var sseClients: [ObjectIdentifier: Client] = [:]
    private var heartbeat: DispatchSourceTimer?
    private var latestSnapshot = Data("{}".utf8)
    
    var pinProvider: () -> String = { "" }
    var onReady: (() -> Void)?
    var onFailure: ((String) -> Void)?
    var onClientCountChange: ((Int) -> Void)?
    
    init(port: UInt16) {
        self.port = port
    }
    
    func start() {
        queue.async { [self] in
            guard listener == nil else { return }
            
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            if let tcp = params.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
                tcp.noDelay = true
                tcp.enableKeepalive = true
            }
            
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                onFailure?("Port invalide.")
                return
            }
            
            let newListener: NWListener
            do {
                newListener = try NWListener(using: params, on: nwPort)
            } catch {
                onFailure?("Impossible d'ouvrir le port \(port) : \(error.localizedDescription)")
                return
            }
            
            newListener.service = NWListener.Service(name: "Recall DJ", type: "_http._tcp")
            newListener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    self.onReady?()
                case .failed(let error):
                    self.onFailure?(Self.describe(error: error, port: self.port))
                default:
                    break
                }
            }
            newListener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            
            listener = newListener
            startHeartbeat()
            newListener.start(queue: queue)
        }
    }
    
    func stop() {
        queue.async { [self] in
            listener?.cancel()
            listener = nil
            heartbeat?.cancel()
            heartbeat = nil
            let all = clients.values
            clients.removeAll()
            sseClients.removeAll()
            all.forEach { $0.connection.cancel() }
            onClientCountChange?(0)
        }
    }
    
    /// Mémorise le dernier état et le pousse immédiatement à tous les téléphones connectés
    func publish(snapshot: Data) {
        queue.async { [self] in
            latestSnapshot = snapshot
            guard !sseClients.isEmpty else { return }
            let frame = Self.sseFrame(for: snapshot)
            for (key, client) in sseClients {
                client.connection.send(content: frame, completion: .contentProcessed { [weak self] error in
                    if error != nil { self?.remove(key: key) }
                })
            }
        }
    }
    
    private static func describe(error: NWError, port: UInt16) -> String {
        if case .posix(let code) = error, code == .EADDRINUSE {
            return "Le port \(port) est déjà utilisé par une autre application. Changez de port puis relancez."
        }
        return "Erreur réseau : \(error.localizedDescription)"
    }
    
    // MARK: Connexions
    
    private func accept(_ connection: NWConnection) {
        let client = Client(connection: connection)
        let key = ObjectIdentifier(client)
        clients[key] = client
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.remove(key: key)
            default:
                break
            }
        }
        connection.start(queue: queue)
        receive(on: client, key: key)
    }
    
    private func remove(key: ObjectIdentifier) {
        guard let client = clients.removeValue(forKey: key) else { return }
        let wasSSE = sseClients.removeValue(forKey: key) != nil
        client.connection.cancel()
        if wasSSE { onClientCountChange?(sseClients.count) }
    }
    
    private func receive(on client: Client, key: ObjectIdentifier) {
        client.connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                client.buffer.append(data)
                if client.buffer.count > 64 * 1024 {
                    self.remove(key: key)
                    return
                }
                if let headerEnd = client.buffer.range(of: Data("\r\n\r\n".utf8)) {
                    let headerData = client.buffer.subdata(in: 0..<headerEnd.lowerBound)
                    client.buffer.removeAll()
                    self.handle(headerData: headerData, client: client, key: key)
                    return
                }
            }
            if isComplete || error != nil {
                self.remove(key: key)
                return
            }
            self.receive(on: client, key: key)
        }
    }
    
    // MARK: Routage
    
    private func handle(headerData: Data, client: Client, key: ObjectIdentifier) {
        guard let headerText = String(data: headerData, encoding: .utf8) ?? String(data: headerData, encoding: .isoLatin1),
              let requestLine = headerText.components(separatedBy: "\r\n").first else {
            send(.plain(400, "Bad Request"), to: client, key: key)
            return
        }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            send(.plain(400, "Bad Request"), to: client, key: key)
            return
        }
        let method = String(parts[0]).uppercased()
        let target = String(parts[1])
        let components = URLComponents(string: target)
        let path = components?.path ?? target
        let query = components?.queryItems ?? []
        
        guard method == "GET" || method == "HEAD" else {
            send(.plain(405, "Method Not Allowed"), to: client, key: key)
            return
        }
        
        let providedPin = query.first(where: { $0.name == "pin" })?.value ?? ""
        let expectedPin = pinProvider()
        let isAuthorized = expectedPin.isEmpty || providedPin == expectedPin
        
        switch path {
        case "/", "/index.html":
            send(.html(PhoneCompanionWebPage.html), to: client, key: key)
            
        case "/manifest.json":
            send(.json(Data(PhoneCompanionWebPage.manifest.utf8), contentType: "application/manifest+json"), to: client, key: key)
            
        case "/api/state":
            guard isAuthorized else {
                send(.json(Data(#"{"error":"pin_required"}"#.utf8), status: 403), to: client, key: key)
                return
            }
            send(.json(latestSnapshot), to: client, key: key)
            
        case "/api/events":
            guard isAuthorized else {
                send(.json(Data(#"{"error":"pin_required"}"#.utf8), status: 403), to: client, key: key)
                return
            }
            client.isSSE = true
            sseClients[key] = client
            onClientCountChange?(sseClients.count)
            var head = "HTTP/1.1 200 OK\r\n"
            head += "Content-Type: text/event-stream; charset=utf-8\r\n"
            head += "Cache-Control: no-cache, no-store\r\n"
            head += "Connection: keep-alive\r\n"
            head += "X-Accel-Buffering: no\r\n\r\n"
            head += "retry: 1500\n\n"
            var payload = Data(head.utf8)
            payload.append(Self.sseFrame(for: latestSnapshot))
            client.connection.send(content: payload, completion: .contentProcessed { [weak self] error in
                if error != nil { self?.remove(key: key) }
            })
            
        case "/favicon.ico":
            send(.plain(204, ""), to: client, key: key)
            
        default:
            send(.plain(404, "Not Found"), to: client, key: key)
        }
    }
    
    private struct Response {
        var status: Int
        var contentType: String
        var body: Data
        
        static func plain(_ status: Int, _ body: String) -> Response {
            Response(status: status, contentType: "text/plain; charset=utf-8", body: Data(body.utf8))
        }
        static func html(_ html: String) -> Response {
            Response(status: 200, contentType: "text/html; charset=utf-8", body: Data(html.utf8))
        }
        static func json(_ data: Data, status: Int = 200, contentType: String = "application/json; charset=utf-8") -> Response {
            Response(status: status, contentType: contentType, body: data)
        }
        
        var reason: String {
            switch status {
            case 200: return "OK"
            case 204: return "No Content"
            case 400: return "Bad Request"
            case 403: return "Forbidden"
            case 404: return "Not Found"
            case 405: return "Method Not Allowed"
            default: return "OK"
            }
        }
    }
    
    private func send(_ response: Response, to client: Client, key: ObjectIdentifier) {
        var head = "HTTP/1.1 \(response.status) \(response.reason)\r\n"
        head += "Content-Type: \(response.contentType)\r\n"
        head += "Content-Length: \(response.body.count)\r\n"
        head += "Cache-Control: no-store\r\n"
        head += "Connection: close\r\n\r\n"
        var payload = Data(head.utf8)
        payload.append(response.body)
        client.connection.send(content: payload, completion: .contentProcessed { [weak self] _ in
            self?.remove(key: key)
        })
    }
    
    private static func sseFrame(for data: Data) -> Data {
        var frame = Data("data: ".utf8)
        frame.append(data)
        frame.append(Data("\n\n".utf8))
        return frame
    }
    
    private func startHeartbeat() {
        heartbeat?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 20, repeating: 20)
        timer.setEventHandler { [weak self] in
            guard let self, !self.sseClients.isEmpty else { return }
            let ping = Data(": ping\n\n".utf8)
            for (key, client) in self.sseClients {
                client.connection.send(content: ping, completion: .contentProcessed { [weak self] error in
                    if error != nil { self?.remove(key: key) }
                })
            }
        }
        timer.resume()
        heartbeat = timer
    }
}

// MARK: - Construction de l'état diffusé au téléphone

/// Transforme l'état courant de Recall (monitor, filtres, Sélec) en dictionnaire JSON,
/// en appliquant exactement les mêmes filtres que la fenêtre principale.
@MainActor
enum PhoneCompanionSnapshotBuilder {
    
    static func build() -> [String: Any] {
        let monitor = SeratoMonitorService.shared
        let settings = UserSettings.shared
        let toPlay = ToPlayService.shared
        let session = SessionHistoryService.shared
        let current = monitor.currentTrack
        
        let mode: String
        let tracks: [Track]
        if settings.isToPlayFilterActive {
            mode = "toplay"
            tracks = applyFilters(toPlay.toTrackList(referenceTrack: current), reference: current, settings: settings)
        } else if settings.isFavoritesFilterActive {
            mode = "favorites"
            tracks = applyFilters(monitor.favoriteSuggestions, reference: current, settings: settings)
        } else {
            mode = "suggestions"
            tracks = applyFilters(monitor.historySuggestions, reference: current, settings: settings)
        }
        
        let software: String
        switch monitor.activeDJSoftware {
        case .rekordbox: software = "rekordbox"
        case .serato: software = "serato"
        case .auto: software = "auto"
        }
        
        var dict: [String: Any] = [
            "v": 1,
            "generatedAt": Int(Date().timeIntervalSince1970 * 1000),
            "app": [
                "version": AutoUpdateService.shared.currentAppVersion,
                "theme": settings.djTheme.rawValue,
                "accent": settings.djTheme.hexCode,
                "accent2": hex(from: settings.djTheme.nsSecondaryColor)
            ],
            "status": [
                "software": software,
                "connected": monitor.isSeratoConnected || monitor.isRekordboxConnected,
                "deck": monitor.activeDeckSelection,
                "manualOverride": monitor.manualTrackOverride != nil,
                "playedCount": session.playedCount,
                "isLoading": monitor.isLoading
            ],
            "mode": mode,
            "filters": [
                "harmonic": settings.isHarmonicFilterActive,
                "bpm": settings.isBpmFilterActive,
                "bpmTolerance": settings.bpmTolerancePercent,
                "favorites": settings.isFavoritesFilterActive,
                "toPlay": settings.isToPlayFilterActive,
                "hidePlayed": settings.hidePlayedTracks,
                "direction": settings.transitionDirection.rawValue,
                "keyMode": settings.keyDisplayMode
            ],
            "tracks": tracks.prefix(80).map { serialize($0, settings: settings) },
            "totalCount": tracks.count,
            "toPlayCount": toPlay.tracks.count
        ]
        
        if let current {
            dict["nowPlaying"] = serialize(current, settings: settings)
        } else {
            dict["nowPlaying"] = NSNull()
        }
        return dict
    }
    
    /// Réplique du filtrage de `MainFloatingView` (Harmonie, BPM, morceaux déjà joués)
    static func applyFilters(_ input: [Track], reference: Track?, settings: UserSettings) -> [Track] {
        var list = input
        if settings.isHarmonicFilterActive, reference != nil {
            list = list.filter { $0.harmonicRelation?.isCompatible == true }
        }
        if settings.isBpmFilterActive, let currentBpm = reference?.bpm, currentBpm > 0 {
            let tol = settings.bpmTolerancePercent / 100.0
            list = list.filter { track in
                guard track.bpm > 0 else { return false }
                if abs(track.bpm / currentBpm - 1.0) <= tol { return true }
                if abs((track.bpm / 2.0) / currentBpm - 1.0) <= tol { return true }
                if abs((track.bpm * 2.0) / currentBpm - 1.0) <= tol { return true }
                return false
            }
        }
        if settings.hidePlayedTracks {
            list = list.filter { !$0.isPlayedInSession }
        }
        return list
    }
    
    static func serialize(_ track: Track, settings: UserSettings) -> [String: Any] {
        var dict: [String: Any] = [
            "id": track.id,
            "title": track.displayTitle,
            "artist": track.displayArtist,
            "bpm": track.bpm,
            "bpmText": track.displayBpm,
            "key": track.displayKey(mode: settings.keyDisplayMode),
            "keyColor": track.camelotKey.map { hex(from: NSColor($0.color)) } ?? "",
            "count": track.transitionCount,
            "matchType": matchCode(track.matchType),
            "isFavorite": track.isFavorite,
            "played": track.isPlayedInSession,
            "genre": track.displayGenre,
            "direction": track.direction.rawValue
        ]
        if let diff = track.bpmDiff {
            dict["bpmDiff"] = diff
        }
        if let rel = track.harmonicRelation {
            dict["relation"] = rel.shortBadgeText
            dict["relationLong"] = rel.badgeText
            dict["compatible"] = rel.isCompatible
            dict["energyBoost"] = rel.isEnergyBoost
        }
        return dict
    }
    
    private static func matchCode(_ type: MatchType) -> String {
        switch type {
        case .directTransition: return "direct"
        case .sameSongVariant: return "variant"
        case .routineSequence: return "routine"
        case .manualFavorite: return "favorite"
        }
    }
    
    static func hex(from color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Génération de QR code

enum PhoneCompanionQRCode {
    static func image(for string: String, size: CGFloat) -> NSImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        
        let scale = size / output.extent.width
        let scaled = output.samplingNearest().transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rep = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}
