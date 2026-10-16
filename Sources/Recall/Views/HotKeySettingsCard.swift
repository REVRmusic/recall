import SwiftUI

public struct HotKeySettingsCard: View {
    @EnvironmentObject var settings: UserSettings
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // En-tête
            HStack(spacing: 6) {
                Label {
                    Text("Raccourcis Clavier Globaux")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.white)
                } icon: {
                    Image(systemName: "command.square.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color.accentCyan)
                }
                
                Spacer()
                
                // Badge du mode actif
                Text(settings.hotKeyPreset.title)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(settings.hotKeyPreset == .disabled ? .white.opacity(0.4) : Color.accentCyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(settings.hotKeyPreset == .disabled ? Color.white.opacity(0.06) : Color.accentCyan.opacity(0.18))
                    .cornerRadius(4)
            }
            
            Text("Contrôlez Recall instantanément en plein mix sans quitter Serato ou Rekordbox.")
                .font(.system(size: 9.5))
                .foregroundColor(.white.opacity(0.60))
            
            // Sélecteur de préréglages
            VStack(spacing: 4) {
                ForEach(HotKeyModifierPreset.allCases) { preset in
                    Button {
                        settings.hotKeyPreset = preset
                    } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .stroke(settings.hotKeyPreset == preset ? Color.accentCyan : Color.white.opacity(0.25), lineWidth: 1.5)
                                    .frame(width: 12, height: 12)
                                
                                if settings.hotKeyPreset == preset {
                                    Circle()
                                        .fill(Color.accentCyan)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(preset.title)
                                    .font(.system(size: 10, weight: settings.hotKeyPreset == preset ? .bold : .medium))
                                    .foregroundColor(settings.hotKeyPreset == preset ? .white : .white.opacity(0.75))
                                
                                Text(preset.subtitle)
                                    .font(.system(size: 8.5))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(settings.hotKeyPreset == preset ? Color.accentCyan.opacity(0.12) : Color.white.opacity(0.03))
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(settings.hotKeyPreset == preset ? Color.accentCyan.opacity(0.50) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }
            .padding(.top, 2)
            
            // Tableau des touches d'action
            if settings.hotKeyPreset != .disabled {
                VStack(spacing: 4) {
                    hotKeyRow(
                        icon: "eye.fill",
                        title: "Afficher / Masquer Recall",
                        keyCombo: settings.hotKeyPreset.toggleSymbol
                    )
                    
                    hotKeyRow(
                        icon: "rectangle.compress.vertical",
                        title: "Basculer mode compact / complet",
                        keyCombo: settings.hotKeyPreset.compactSymbol
                    )
                    
                    hotKeyRow(
                        icon: "magnifyingglass",
                        title: "Ouvrir recherche Recall par-dessus le mix",
                        keyCombo: settings.hotKeyPreset.searchSymbol
                    )
                }
                .padding(6)
                .background(Color.white.opacity(0.04))
                .cornerRadius(6)
                
                // Note de sécurité Serato
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Color.accentCyan.opacity(0.85))
                        .padding(.top, 1)
                    
                    Text("Astuce Sécurité DJ : Dans Rekordbox, ⇧⌘R déclenche Jump Reverse (saut arrière platine 1), et dans Serato, ⇧⌘F active la recherche de caisse. Le mode ⌥⌘ (Cmd + Option) est 100% libre et garanti sans conflit en plein mix.")
                        .font(.system(size: 8.5))
                        .foregroundColor(.white.opacity(0.55))
                        .lineSpacing(1.2)
                }
                .padding(6)
                .background(Color.accentCyan.opacity(0.06))
                .cornerRadius(5)
            }
        }
    }
    
    private func hotKeyRow(icon: String, title: String, keyCombo: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(Color.accentCyan)
                .frame(width: 14)
            
            Text(title)
                .font(.system(size: 9.5))
                .foregroundColor(.white.opacity(0.80))
            
            Spacer()
            
            Text(keyCombo)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.12))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.20), lineWidth: 0.8)
                )
        }
        .padding(.vertical, 1)
    }
}
