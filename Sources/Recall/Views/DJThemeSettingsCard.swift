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
                
                // Curseur de précision DJ Pro
                HStack(spacing: 10) {
                    HStack(spacing: 3.5) {
                        Image(systemName: "square.fill")
                            .font(.system(size: 7))
                        Text("Opaque (0%)")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(settings.glassTranslucency <= 0.04 ? settings.accentColor : .white.opacity(0.45))
                    
                    DJTranslucencySlider(value: $settings.glassTranslucency)
                    
                    HStack(spacing: 3.5) {
                        Text("Translucide (100%)")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        Image(systemName: "sparkles")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(settings.glassTranslucency >= 0.96 ? settings.accentColor : .white.opacity(0.45))
                }
                .padding(.vertical, 2)
                
                Text("Le verre dépoli floute dynamiquement la fenêtre sous Recall (ex: Serato ou Rekordbox). À 100%, l'effet verre dépoli est maximal et laisse transparaître vos formes d'onde et pistes en arrière-plan.")
                    .font(.system(size: 8.5))
                    .foregroundColor(.white.opacity(0.48))
                    .fixedSize(horizontal: false, vertical: true)
            }
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
}

// MARK: - Curseur Tactile Haute Définition pour la Translucidité (Style Console DJ)

public struct DJTranslucencySlider: View {
    @Binding var value: Double
    @EnvironmentObject var settings: UserSettings
    @State private var isDragging: Bool = false
    @State private var isHovered: Bool = false
    
    private let presetNotches: [Double] = [0.0, 0.35, 0.65, 1.0]
    
    public init(value: Binding<Double>) {
        self._value = value
    }
    
    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let thumbRadius: CGFloat = 9
            let thumbDiameter: CGFloat = thumbRadius * 2
            let trackWidth = max(10, width - thumbDiameter)
            let clampedVal = max(0.0, min(1.0, value))
            let thumbX = thumbRadius + CGFloat(clampedVal) * trackWidth
            let centerY = geo.size.height / 2
            
            ZStack(alignment: .leading) {
                // 1. Fond du rail encastré
                Capsule()
                    .fill(Color.black.opacity(0.65))
                    .frame(width: trackWidth, height: 6)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                    .position(x: width / 2, y: centerY)
                
                // 2. Piste active lumineuse
                if clampedVal > 0.005 {
                    let activeWidth = CGFloat(clampedVal) * trackWidth
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    settings.accentColor.opacity(0.90),
                                    settings.accentSecondaryColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: activeWidth, height: 6)
                        .shadow(color: settings.accentColor.opacity(isDragging || isHovered ? 0.65 : 0.30), radius: 5, x: 0, y: 0)
                        .position(x: thumbRadius + activeWidth / 2, y: centerY)
                }
                
                // 3. Repères discrets (notches des présets clés)
                ForEach(presetNotches, id: \.self) { notch in
                    let notchX = thumbRadius + CGFloat(notch) * trackWidth
                    Circle()
                        .fill(clampedVal >= notch ? settings.accentColor : Color.white.opacity(0.25))
                        .frame(width: 3.2, height: 3.2)
                        .position(x: notchX, y: centerY)
                }
                
                // 4. Curseur tactile DJ Pro (Thumb)
                ZStack {
                    // Halo néon externe
                    Circle()
                        .fill(settings.accentColor.opacity(isDragging ? 0.35 : (isHovered ? 0.20 : 0.08)))
                        .frame(width: 26, height: 26)
                        .blur(radius: 2)
                    
                    // Corps du curseur
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#2C3038"),
                                    Color(hex: "#15181E")
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: thumbDiameter, height: thumbDiameter)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.40),
                                            Color.white.opacity(0.10)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.70), radius: 3, x: 0, y: 2)
                    
                    // Anneau d'accent lumineux
                    Circle()
                        .stroke(settings.accentColor, lineWidth: 1.8)
                        .frame(width: thumbDiameter - 2, height: thumbDiameter - 2)
                    
                    // Point central luminescent
                    Circle()
                        .fill(Color.white)
                        .frame(width: 4, height: 4)
                        .shadow(color: settings.accentColor, radius: 2)
                }
                .scaleEffect(isDragging ? 1.15 : (isHovered ? 1.08 : 1.0))
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
                .position(x: thumbX, y: centerY)
            }
            .animation(isDragging ? nil : .spring(response: 0.25, dampingFraction: 0.8), value: clampedVal)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let x = gesture.location.x - thumbRadius
                        let pct = max(0.0, min(1.0, Double(x / trackWidth)))
                        let stepped = (pct * 100).rounded() / 100.0
                        self.value = stepped
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .frame(height: 24)
    }
}

