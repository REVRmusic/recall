import SwiftUI

/// Composant de réglage de l'ambiance visuelle, des thèmes DJ et de la transparence du verre dépoli
public struct DJThemeSettingsCard: View {
    @EnvironmentObject var settings: UserSettings
    
    private let glassPresets: [(label: String, value: Double, desc: String)] = [
        ("Opaque", 0.00, "0% (Fond noir 100% opaque sans transparence)"),
        ("Standard", 0.35, "35% (Translucidité subtile par défaut)"),
        ("Équilibré", 0.65, "65% (Transparence feutrée équilibrée)"),
        ("Translucide", 1.00, "100% (Translucidité maximale, verre dépoli cristallin)")
    ]
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête de section
            HStack {
                Label {
                    Text("Ambiance visuelle (Thèmes DJ)")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.white)
                } icon: {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 11))
                        .foregroundColor(settings.accentColor)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(settings.accentColor)
                        .frame(width: 6, height: 6)
                    
                    Text(settings.djTheme.name.uppercased())
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .foregroundColor(settings.accentColor)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(settings.accentColor.opacity(0.18))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(settings.accentColor.opacity(0.4), lineWidth: 0.8)
                )
            }
            
            Text("Choisissez les accents lumineux pour matcher l'esthétique de vos platines, contrôleurs ou table de mixage, et ajustez la translucidité du verre dépoli.")
                .font(.system(size: 9.5))
                .foregroundColor(.white.opacity(0.60))
                .fixedSize(horizontal: false, vertical: true)
            
            // Grille 2x2 des Thèmes DJ
            VStack(spacing: 7) {
                HStack(spacing: 7) {
                    themeOptionCard(for: .cyanNeon)
                    themeOptionCard(for: .electricPurple)
                }
                HStack(spacing: 7) {
                    themeOptionCard(for: .sunsetAmber)
                    themeOptionCard(for: .acidGreen)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.vertical, 2)
            
            // Réglage de la translucidité du verre dépoli (Frosted Glass)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label {
                        Text("Translucidité (Effet Verre Dépoli)")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.90))
                    } icon: {
                        Image(systemName: "slider.horizontal.below.rectangle")
                            .font(.system(size: 10))
                            .foregroundColor(settings.accentColor)
                    }
                    
                    Spacer()
                    
                    Text(opacityBadgeText)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(settings.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(settings.accentColor.opacity(0.15))
                        .cornerRadius(4)
                }
                
                // Puces de présélection rapide
                HStack(spacing: 5) {
                    ForEach(glassPresets, id: \.label) { preset in
                        let isSelected = abs(settings.glassTranslucency - preset.value) < 0.05
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                settings.glassTranslucency = preset.value
                            }
                        } label: {
                            HStack(spacing: 3) {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 7.5, weight: .bold))
                                }
                                Text(preset.label)
                                    .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(isSelected ? settings.accentColor.opacity(0.25) : Color.white.opacity(0.05))
                            .foregroundColor(isSelected ? settings.accentColor : .white.opacity(0.70))
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(isSelected ? settings.accentColor.opacity(0.65) : Color.white.opacity(0.08), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .help(preset.desc)
                    }
                }
                
                // Curseur de précision
                HStack(spacing: 8) {
                    Text("Opaque (0%)")
                        .font(.system(size: 8.5))
                        .foregroundColor(.white.opacity(0.45))
                    
                    Slider(
                        value: $settings.glassTranslucency,
                        in: 0.00...1.00,
                        step: 0.02
                    )
                    .tint(settings.accentColor)
                    .controlSize(.mini)
                    
                    Text("Translucide (100%)")
                        .font(.system(size: 8.5))
                        .foregroundColor(.white.opacity(0.45))
                }
                
                Text("Le verre dépoli floute dynamiquement la fenêtre sous Recall (ex: Serato ou Rekordbox). À 100%, l'effet verre dépoli est maximal et laisse transparaître vos formes d'onde et pistes en arrière-plan.")
                    .font(.system(size: 8.5))
                    .foregroundColor(.white.opacity(0.48))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Mini Aperçu dynamique du thème
            VStack(alignment: .leading, spacing: 5) {
                Text("Aperçu en direct :")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.60))
                
                livePreviewCard
            }
            .padding(.top, 2)
        }
    }
    
    private var opacityBadgeText: String {
        let pct = Int(round(settings.glassTranslucency * 100))
        if settings.glassTranslucency <= 0.02 {
            return "0% (Opaque)"
        } else if abs(settings.glassTranslucency - 0.35) < 0.04 {
            return "\(pct)% (Standard défaut)"
        } else if settings.glassTranslucency >= 0.98 {
            return "100% (Translucidité max)"
        } else if settings.glassTranslucency >= 0.60 {
            return "\(pct)% (Équilibré)"
        }
        return "\(pct)% translucidité"
    }
    
    /// Carte de sélection individuelle de thème
    private func themeOptionCard(for theme: DJTheme) -> some View {
        let isSelected = settings.djTheme == theme
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                settings.djTheme = theme
            }
        } label: {
            HStack(spacing: 8) {
                // Pastille dégradée lumineuse avec icône
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [theme.accentColor, theme.secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 26, height: 26)
                        .shadow(color: isSelected ? theme.accentColor.opacity(0.6) : Color.clear, radius: 4, x: 0, y: 1)
                    
                    Image(systemName: theme.icon)
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.black.opacity(0.75))
                }
                
                VStack(alignment: .leading, spacing: 1.5) {
                    HStack(spacing: 4) {
                        Text(theme.name)
                            .font(.system(size: 10.5, weight: isSelected ? .bold : .semibold))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.85))
                        
                        if theme == .cyanNeon {
                            Text("DÉFAUT")
                                .font(.system(size: 7, weight: .heavy, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 3)
                                .padding(.vertical, 0.5)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(3)
                        }
                    }
                    
                    Text(theme.subtitle)
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.50))
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(theme.accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? theme.accentColor.opacity(0.16) : Color.white.opacity(0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? theme.accentColor.opacity(0.80) : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 1.4 : 0.8
                    )
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("Activer l'ambiance \(theme.name) (\(theme.subtitle))")
    }
    
    /// Mini-carte d'aperçu dynamique reflétant fidèlement l'ambiance et la transparence
    private var livePreviewCard: some View {
        ZStack {
            // Effet verre dépoli simulé
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.darkBg.opacity(settings.effectiveGlassTintOpacity))
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.20),
                                    settings.accentColor.opacity(0.35),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            
            VStack(spacing: 5) {
                // Mini barre d'en-tête
                HStack(spacing: 5) {
                    Circle()
                        .fill(settings.accentColor)
                        .frame(width: 6, height: 6)
                    
                    Text("RECALL LIVE")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundColor(settings.accentColor)
                    
                    Spacer()
                    
                    HStack(spacing: 3) {
                        Text("BPM ±10%")
                            .font(.system(size: 7.5, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(settings.accentColor.opacity(0.25))
                            .foregroundColor(settings.accentColor)
                            .cornerRadius(3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(settings.accentColor.opacity(0.6), lineWidth: 0.6)
                            )
                        
                        Text("8A")
                            .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Color(hex: "#00E5FF").opacity(0.25))
                            .foregroundColor(Color(hex: "#00E5FF"))
                            .cornerRadius(3)
                    }
                }
                
                // Mini rangée de morceau
                HStack(spacing: 6) {
                    Text("#1")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(settings.accentColor)
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 1)
                        .background(settings.accentColor.opacity(0.20))
                        .cornerRadius(3)
                    
                    VStack(alignment: .leading, spacing: 0.5) {
                        Text("The Weeknd - Blinding Lights")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("171 BPM • 8A ➔ 9A (+1 Energy Boost)")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 7.5))
                            .foregroundColor(Color.accentFire)
                        Text("14x")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .foregroundColor(settings.accentColor)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(settings.accentColor.opacity(0.18))
                    .cornerRadius(4)
                }
                .padding(5)
                .background(Color.cardBg.opacity(0.7))
                .cornerRadius(6)
            }
            .padding(8)
        }
        .frame(height: 74)
    }
}
