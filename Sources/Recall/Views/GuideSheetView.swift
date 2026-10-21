import SwiftUI

public struct GuideSheetView: View {
    @Environment(\.dismiss) var dismiss
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // En-tête
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentCyan.opacity(0.2))
                        .frame(width: 26, height: 26)
                    
                    Image(systemName: "questionmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(Color.accentCyan)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Guide & Légende Recall")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Comprendre les indicateurs et les suggestions")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.55))
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .background(Color.darkBg)
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    
                    // SECTION 1 : Les compteurs d'enchaînements (2x, 7x, flammes)
                    guideCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label {
                                    Text("Compteurs d'enchaînements")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                } icon: {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(Color.accentFire)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    badgeExample(text: "2x", color: Color.accentCyan)
                                    badgeExample(text: "🔥 7x", color: Color.accentFire)
                                }
                            }
                            
                            Text("Ce chiffre indique **le nombre exact de fois où vous avez enchaîné ce morceau juste après le morceau actuellement en cours**, lors de vos vrais sets de mix.")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                bulletPoint(
                                    boldText: "Badge cyan (ex: 1x, 2x) :",
                                    desc: "Enchaînement déjà réalisé et validé dans une session passée."
                                )
                                bulletPoint(
                                    boldText: "Flamme orange (ex: 🔥 5x, 🔥 11x) :",
                                    desc: "Vos routines favorites, jouées au moins 3 fois en live."
                                )
                            }
                            .padding(.top, 2)
                        }
                    }
                    
                    // SECTION 2 : Combos Favoris (❤️ FAV) & Mémorisation
                    guideCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label {
                                    Text("Combos Favoris & Coups de cœur")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                } icon: {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(Color(hex: "#FF5252"))
                                }
                                
                                Spacer()
                                
                                badgeExample(text: "❤️ FAV", color: Color(hex: "#FF5252"))
                            }
                            
                            Text("Enregistrez instantanément les associations réussies entre deux morceaux pour vous en souvenir lors de vos prochains sets :")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                bulletPoint(
                                    boldText: "Bouton '+ Sauvegarder combo' :",
                                    desc: "Apparaît sur la carte dès que deux platines sont actives ou après une transition réussie."
                                )
                                bulletPoint(
                                    boldText: "Cœur au survol ❤️ :",
                                    desc: "Cliquez sur le cœur à droite de n'importe quel morceau suggéré pour lier la paire."
                                )
                                bulletPoint(
                                    boldText: "Classement naturel & Badge ❤️ FAV :",
                                    desc: "Dans la liste principale, vos combos favoris s'affichent à leur rang historique réel (ex: 2x, 🔥 5x) avec leur badge ❤️ FAV."
                                )
                                bulletPoint(
                                    boldText: "Filtre exclusif [ Favs ❤️ ] :",
                                    desc: "Cliquez sur ce filtre pour isoler et afficher uniquement vos combinaisons favorites mémorisées."
                                )
                            }
                            .padding(.top, 2)
                        }
                    }
                    
                    // SECTION 3 : Clés Camelot & Harmonie
                    guideCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label {
                                    Text("Harmonie musicale & Roue de Camelot")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                } icon: {
                                    Image(systemName: "circle.grid.cross.fill")
                                        .foregroundColor(Color.accentPurple)
                                }
                                
                                Spacer()
                                
                                badgeExample(text: "9A", color: Color(hex: "#E2BCFF"))
                            }
                            
                            Text("Recall respecte les couleurs de la roue de Camelot pour identifier instantanément les morceaux compatibles :")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                bulletPoint(
                                    boldText: "Identique (ex: 9A → 9A) :",
                                    desc: "Même tonalité. Transition totalement fluide et imperceptible."
                                )
                                bulletPoint(
                                    boldText: "Voisine (±1, ex: 9A → 8A ou 10A) :",
                                    desc: "Clé adjacente. Compatibilité harmonique naturelle."
                                )
                                bulletPoint(
                                    boldText: "Relative (A ⇄ B, ex: 9A ⇄ 9B) :",
                                    desc: "Changement de mode Mineur ⇄ Majeur sans dissonance."
                                )
                                bulletPoint(
                                    boldText: "⚡️ Boost +1/2 Ton (ex: 9A → 4A) :",
                                    desc: "+1 demi-ton (+7 Camelot) : la montée d'énergie la plus puissante en mix."
                                )
                                bulletPoint(
                                    boldText: "⚡️ Boost +1 Ton (ex: 9A → 11A) :",
                                    desc: "+1 ton (+2 Camelot) : modulation montante festive et entraînante."
                                )
                                bulletPoint(
                                    boldText: "Diagonale (ex: 9A ⇄ 8B ou 10B) :",
                                    desc: "Passage modal d'un cran entre Majeur et Mineur."
                                )
                            }
                        }
                    }
                    
                    // SECTION 4 : BPM & Écart de tempo
                    guideCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label {
                                    Text("BPM & Écart de tempo")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                } icon: {
                                    Image(systemName: "metronome")
                                        .foregroundColor(Color.accentGreen)
                                }
                                
                                Spacer()
                                
                                badgeExample(text: "128.0 +2.0", color: Color.accentGreen)
                            }
                            
                            Text("Affiche le tempo du morceau et l'écart en BPM par rapport au morceau actuel :")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.85))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                bulletPoint(
                                    boldText: "Vert (+0 à ±3 BPM) :",
                                    desc: "Tempo quasi identique, calage immédiat sans distorsion."
                                )
                                bulletPoint(
                                    boldText: "Orange (±3 à ±8 BPM) :",
                                    desc: "Écart modéré, nécessite un pitch-shift ou transition préparée."
                                )
                                bulletPoint(
                                    boldText: "Filtre BPM ±10% :",
                                    desc: "Prend en compte automatiquement le double/demi-tempo (ex: 75 ⇄ 150 BPM)."
                                )
                            }
                        }
                    }
                    
                    // SECTION 5 : Glisser-Déposer direct vers Serato
                    guideCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label {
                                Text("Glisser-Déposer (Drag & Drop)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            } icon: {
                                Image(systemName: "hand.draw.fill")
                                    .foregroundColor(Color.accentCyan)
                            }
                            
                            Text("L'intégralité de la carte de chaque morceau est **saisissable à la souris** :")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.85))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                bulletPoint(
                                    boldText: "1. Cliquez n'importe où",
                                    desc: "sur la ligne d'un morceau suggéré."
                                )
                                bulletPoint(
                                    boldText: "2. Glissez le morceau",
                                    desc: "vers la platine de votre logiciel DJ (Serato DJ Pro ou Rekordbox)."
                                )
                                bulletPoint(
                                    boldText: "3. Relâchez :",
                                    desc: "La piste se charge instantanément sur votre platine."
                                )
                            }
                        }
                    }
                    
                    // SECTION 6 : Suivi de session & Morceaux déjà joués (✓ JOUÉ)
                    guideCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label {
                                    Text("Morceaux déjà joués & Session")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                } icon: {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(Color(hex: "#7ED6DF"))
                                }
                                
                                Spacer()
                                
                                badgeExample(text: "✓ JOUÉ", color: Color(hex: "#7ED6DF"))
                            }
                            
                            Text("Recall mémorise tous les morceaux joués pendant votre set actuel pour vous avertir visuellement :")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                bulletPoint(
                                    boldText: "Marquage visuel [JOUÉ] :",
                                    desc: "Le titre est mis en valeur avec le style et la couleur configurés dans vos réglages."
                                )
                                bulletPoint(
                                    boldText: "Filtre anti pré-écoute :",
                                    desc: "Un morceau n'est validé que s'il a tourné au moins le délai choisi dans les paramètres (25s par défaut). Les pré-écoutes au casque sont ignorées."
                                )
                                bulletPoint(
                                    boldText: "Bouton Reset en haut ↺ :",
                                    desc: "Cliquez sur l'icône ↺ tout en haut à gauche pour remettre à zéro et démarrer une nouvelle session."
                                )
                                bulletPoint(
                                    boldText: "Générateur de Tracklist (Cmd+Shift+T) :",
                                    desc: "Exportez à tout moment le sommaire YouTube (00:00 Artiste - Titre), 1001Tracklists, Réseaux sociaux ou playlist M3U8 depuis le menu Fichier ou les Réglages."
                                )
                                bulletPoint(
                                    boldText: "Set Recap & Statistiques (Cmd+Shift+S) :",
                                    desc: "Consultez en direct vos statistiques de session : durée totale, BPM moyen, tonalité dominante, cadence de mix, enchaînement le plus rapide et top artistes."
                                )
                                bulletPoint(
                                    boldText: "Thèmes DJ & Verre dépoli :",
                                    desc: "Personnalisez l'ambiance avec 4 thèmes néon (Cyan Neon par défaut, Electric Purple, Sunset Amber, Acid Green) et réglez la transparence du verre dépoli dans les Paramètres (⌘,) ou le menu Fenêtre ➔ Thème DJ."
                                )
                            }
                            .padding(.top, 2)
                        }
                    }
                    
                    // SECTION 7 : Fiabilité & Respect de votre historique
                    guideCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label {
                                Text("Fiabilité des suggestions")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            } icon: {
                                Image(systemName: "shield.checkerboard")
                                    .foregroundColor(Color.accentBlue)
                            }
                            
                            Text("Recall ne se fie **jamais** au nombre d'écoutes globales de votre bibliothèque musicale. L'application examine uniquement les **enchaînements chronologiques réels** effectués pendant vos sessions (durée de jeu valide entre 25s et 12min). Les sessions de moins de **10 minutes** ou de moins de **10 titres** (tests, tri de bibliothèque) sont ignorées.")
                                .font(.system(size: 10.5))
                                .foregroundColor(.white.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    // SECTION : Suggérer une idée ou faire un retour
                    guideCard {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label {
                                    Text("Une idée d'amélioration ?")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                } icon: {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(Color.accentCyan)
                                }
                                
                                Spacer()
                                
                                Text("REVR")
                                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                                    .foregroundColor(Color.accentCyan)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.accentCyan.opacity(0.18))
                                    .cornerRadius(3)
                            }
                            
                            Text("Recall est développé avec passion pour la communauté DJ. Vos idées et retours terrain sont précieux pour façonner les prochaines fonctionnalités.")
                                .font(.system(size: 10.5))
                                .foregroundColor(.white.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Button {
                                if let url = URL(string: "https://revrmusic.github.io/recall/?feedback=1&source=app_macos") {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 8.5))
                                    Text("Partager une suggestion (Web) ↗")
                                        .font(.system(size: 9.5, weight: .bold))
                                }
                                .foregroundColor(Color.accentCyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(Color.accentCyan.opacity(0.16))
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                        }
                    }
                    
                    // SECTION 8 : Mentions Légales & Confidentialité
                    guideCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label {
                                    Text("Mentions Légales & Confidentialité")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                } icon: {
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundColor(Color.accentCyan)
                                }
                                
                                Spacer()
                                
                                badgeExample(text: "100% LOCAL", color: Color.accentCyan)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                bulletPoint(
                                    boldText: "Confidentialité & Zéro télémétrie :",
                                    desc: "Recall fonctionne à 100 % hors-ligne sur votre Mac. Aucun serveur externe n'est contacté, aucune donnée personnelle ou historique n'est collectée."
                                )
                                bulletPoint(
                                    boldText: "Intégrité des données :",
                                    desc: "L'accès à l'historique de session s'effectue en lecture seule stricte (PRAGMA query_only = ON), sans jamais modifier ni risquer d'altérer vos fichiers de base."
                                )
                                bulletPoint(
                                    boldText: "Marques déposées :",
                                    desc: "Serato DJ Pro est une marque déposée de Serato Limited. Rekordbox est une marque déposée d'AlphaTheta Corporation (Pioneer DJ). Recall est un utilitaire compagnon indépendant développé par REVR et n'est en aucun cas affilié, sponsorisé, approuvé ou certifié par Serato Limited ou AlphaTheta Corporation."
                                )
                            }
                        }
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 345, height: 510)
        .background(Color.darkBg)
    }
    
    private func guideCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(11)
        .background(Color.cardBg)
        .cornerRadius(9)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private func bulletPoint(boldText: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .foregroundColor(Color.accentCyan)
                .font(.system(size: 11, weight: .bold))
            
            (Text(boldText).fontWeight(.bold).foregroundColor(.white) +
             Text(" ") +
             Text(desc).foregroundColor(.white.opacity(0.75)))
                .font(.system(size: 10.5))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func badgeExample(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(0.6), lineWidth: 0.8)
            )
    }
}
