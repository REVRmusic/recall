import SwiftUI
import AppKit

/// Fenêtre du Compagnon Téléphone : QR code à scanner, adresse locale, PIN et statut du flux en direct
public struct PhoneCompanionView: View {
    @ObservedObject private var companion: PhoneCompanionService = .shared
    @EnvironmentObject var settings: UserSettings
    public var onClose: () -> Void
    
    @State private var portText: String = ""
    @State private var pinText: String = ""
    @State private var copiedFeedback: Bool = false
    @State private var showAdvanced: Bool = false
    
    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider().background(Color.borderSubtle)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    statusBanner
                    qrSection
                    hotspotTip
                    advancedSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            
            Divider().background(Color.borderSubtle)
            footer
        }
        .frame(width: 440)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.darkBg))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderSubtle, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            portText = String(settings.phoneCompanionPort)
            pinText = settings.phoneCompanionPin
        }
    }
    
    // MARK: - En-tête
    
    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(LinearGradient(colors: [settings.accentColor, settings.accentSecondaryColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 28, height: 28)
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Compagnon Téléphone")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text("Suggestions en direct sur votre téléphone • Sans Internet")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Fermer la fenêtre (Échap)")
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }
    
    // MARK: - Statut
    
    private var statusColor: Color {
        if companion.lastError != nil { return Color(hex: "#FF5252") }
        if companion.isRunning { return Color(hex: "#38EB61") }
        if companion.isStarting { return Color(hex: "#FF9E14") }
        return .white.opacity(0.35)
    }
    
    private var statusText: String {
        if let err = companion.lastError { return err }
        if companion.isRunning {
            switch companion.connectedClients {
            case 0: return "Serveur actif • En attente d'un téléphone"
            case 1: return "Serveur actif • 1 téléphone connecté"
            default: return "Serveur actif • \(companion.connectedClients) appareils connectés"
            }
        }
        if companion.isStarting { return "Démarrage du serveur local…" }
        return "Serveur arrêté"
    }
    
    private var statusBanner: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
                .shadow(color: statusColor.opacity(0.8), radius: 4)
            
            Text(statusText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { companion.isRunning || companion.isStarting },
                set: { companion.setEnabled($0) }
            ))
            .toggleStyle(.switch)
            .tint(settings.accentColor)
            .scaleEffect(0.85)
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(statusColor.opacity(0.35), lineWidth: 1))
    }
    
    // MARK: - QR code & URL
    
    @ViewBuilder
    private var qrSection: some View {
        VStack(spacing: 12) {
            if companion.isRunning, let url = companion.primaryURL, let qr = PhoneCompanionQRCode.image(for: url, size: 520) {
                Image(nsImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                    .shadow(color: settings.accentColor.opacity(0.25), radius: 18, x: 0, y: 6)
                
                VStack(spacing: 5) {
                    Text("Scannez avec l'appareil photo du téléphone")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.white)
                    Text("Le téléphone doit être sur le même Wi‑Fi que ce Mac (ou ce Mac connecté au hotspot du téléphone).")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                urlRow(label: "Adresse", value: displayURL(url), copyValue: url)
                
                if let bonjour = companion.bonjourHostURL {
                    urlRow(label: "iPhone (Bonjour)", value: displayURL(bonjour), copyValue: bonjour)
                }
                
                if companion.localAddresses.count > 1 {
                    Text("Autres interfaces : " + companion.localAddresses.dropFirst().joined(separator: ", "))
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
            } else if companion.isRunning {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 30))
                        .foregroundColor(Color(hex: "#FF9E14"))
                    Text("Aucun réseau local détecté")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Text("Connectez ce Mac à un Wi‑Fi ou au partage de connexion de votre téléphone, l'adresse apparaîtra automatiquement.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 44))
                        .foregroundColor(.white.opacity(0.2))
                    Text(companion.isStarting ? "Démarrage…" : "Activez le compagnon pour afficher le QR code")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
    
    private func displayURL(_ url: String) -> String {
        // Le PIN est masqué dans l'affichage ; il reste encodé dans le QR code
        if let range = url.range(of: "?pin=") {
            return String(url[..<range.lowerBound])
        }
        return url
    }
    
    private func urlRow(label: String, value: String, copyValue: String) -> some View {
        HStack(spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 8.5, weight: .heavy))
                .foregroundColor(settings.accentColor)
                .tracking(0.8)
                .frame(width: 92, alignment: .leading)
            
            Text(value)
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.92))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            
            Spacer(minLength: 4)
            
            Button {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(copyValue, forType: .string)
                withAnimation { copiedFeedback = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { copiedFeedback = false }
                }
            } label: {
                Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(copiedFeedback ? Color(hex: "#38EB61") : .white.opacity(0.7))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Copier le lien complet (avec PIN)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
    }
    
    // MARK: - Conseil club (hotspot)
    
    private var hotspotTip: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(settings.accentColor)
                .padding(.top, 1)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Mode club recommandé : hotspot du téléphone")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.92))
                Text("Pas de Wi‑Fi fiable en cabine ? Activez le partage de connexion sur le téléphone et connectez-y ce Mac. Aucune donnée mobile n'est consommée : tout reste en local.")
                    .font(.system(size: 9.5))
                    .foregroundColor(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(settings.accentColor.opacity(0.22), lineWidth: 1))
        )
    }
    
    // MARK: - Options avancées (PIN / Port)
    
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showAdvanced.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("Sécurité & réseau")
                        .font(.system(size: 10.5, weight: .bold))
                    Spacer()
                    Text(settings.phoneCompanionPin.isEmpty ? "Sans PIN" : "PIN \(settings.phoneCompanionPin)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(settings.phoneCompanionPin.isEmpty ? Color(hex: "#FF9E14") : settings.accentColor)
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            
            if showAdvanced {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Code PIN")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                            Text("Demandé aux téléphones qui n'ont pas scanné le QR. Vide = accès libre (déconseillé en club).")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        TextField("1234", text: $pinText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .frame(width: 76)
                            .onSubmit { applyPin() }
                        Button("Nouveau") {
                            pinText = String(format: "%04d", Int.random(in: 0...9999))
                            applyPin()
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .controlSize(.small)
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Port réseau")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                            Text("À changer uniquement si le port \(PhoneCompanionService.defaultPort) est déjà occupé.")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                        TextField("8765", text: $portText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .frame(width: 76)
                            .onSubmit { applyPort() }
                        Button("Appliquer") { applyPort() }
                            .font(.system(size: 10, weight: .semibold))
                            .controlSize(.small)
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Démarrer automatiquement avec Recall")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                            Text("Le flux est prêt dès l'ouverture, sans passer par cette fenêtre.")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                        Toggle("", isOn: $settings.phoneCompanionAutoStart)
                            .toggleStyle(.switch)
                            .tint(settings.accentColor)
                            .scaleEffect(0.85)
                            .labelsHidden()
                    }
                }
                .padding(.leading, 4)
                .transition(.opacity)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
    }
    
    private func applyPin() {
        let cleaned = pinText.trimmingCharacters(in: .whitespacesAndNewlines).filter { $0.isNumber || $0.isLetter }
        pinText = cleaned
        guard cleaned != settings.phoneCompanionPin else { return }
        settings.phoneCompanionPin = cleaned
        // Le PIN est lu à chaque requête : pas besoin de redémarrer, le QR se régénère tout seul
        companion.objectWillChange.send()
    }
    
    private func applyPort() {
        guard let value = Int(portText.trimmingCharacters(in: .whitespacesAndNewlines)), (1024...65535).contains(value) else {
            portText = String(settings.phoneCompanionPort)
            return
        }
        guard value != settings.phoneCompanionPort else { return }
        settings.phoneCompanionPort = value
        if companion.isRunning || companion.isStarting {
            companion.restart()
        }
    }
    
    // MARK: - Pied de page
    
    private var footer: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 9.5))
                    .foregroundColor(settings.accentColor.opacity(0.85))
                Text("Lecture seule • Réseau local uniquement • Zéro cloud")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Button {
                onClose()
            } label: {
                Text("Fermer")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.cardBg.opacity(0.5))
    }
}
