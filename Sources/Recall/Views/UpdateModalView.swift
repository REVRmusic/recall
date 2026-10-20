import SwiftUI
import AppKit

public struct UpdateModalView: View {
    @ObservedObject var autoUpdate: AutoUpdateService = .shared
    public var onClose: () -> Void
    
    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // En-tête de la fenêtre
            HStack(alignment: .center, spacing: 10) {
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.accentCyan)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Mise à jour logicielle")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("Recall v\(autoUpdate.currentAppVersion)")
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
            
            Divider()
                .background(Color.borderSubtle)
            
            // Corps de la modale
            VStack(spacing: 16) {
                if autoUpdate.isInstalling {
                    // État 0 : Téléchargement et installation automatique en cours
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.accentCyan.opacity(0.18))
                                .frame(width: 52, height: 52)
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color.accentCyan)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Installation de Recall \(autoUpdate.availableUpdate?.tagName ?? "")…")
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(autoUpdate.installStatus ?? "Téléchargement en cours…")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.accentCyan)
                        }
                        
                        VStack(spacing: 6) {
                            ProgressView(value: autoUpdate.downloadProgress, total: 1.0)
                                .progressViewStyle(.linear)
                                .tint(Color.accentCyan)
                                .frame(maxWidth: 300)
                            
                            Text("\(Int(autoUpdate.downloadProgress * 100)) % • Remplacement dans /Applications et relance automatique")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                    
                } else if let installError = autoUpdate.installError {
                    // État d'erreur d'installation avec option de secours
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentOrange.opacity(0.18))
                                .frame(width: 52, height: 52)
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color.accentOrange)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Échec de l'installation automatique")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(installError)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.65))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 12)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 135)
                    
                } else if autoUpdate.isChecking {
                    // État 1 : Recherche en cours
                    VStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .padding(.top, 10)
                        
                        VStack(spacing: 4) {
                            Text("Recherche de mises à jour en cours…")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Connexion aux serveurs de publication...")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 140)
                    
                } else if autoUpdate.isUpdateAvailable, let release = autoUpdate.availableUpdate {
                    // État 2 : Nouvelle version disponible !
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentCyan.opacity(0.18))
                                .frame(width: 52, height: 52)
                            Image(systemName: "sparkles")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color.accentCyan)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Nouvelle version disponible !")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 6) {
                                Text("Recall \(release.tagName)")
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundColor(Color.accentCyan)
                                
                                Text("•")
                                    .foregroundColor(.white.opacity(0.3))
                                
                                Text("Actuelle : v\(autoUpdate.currentAppVersion)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        
                        if let bodyText = release.body, !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ScrollView {
                                Text(bodyText)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.75))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                            }
                            .frame(maxHeight: 100)
                            .background(Color.cardBg.opacity(0.7))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.borderSubtle, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.top, 6)
                    
                } else if let status = autoUpdate.manualCheckStatus,
                          (status.lowercased().contains("aucune connexion") ||
                           status.lowercased().contains("impossible") ||
                           status.lowercased().contains("erreur")) {
                    // État 3 : Erreur ou hors-ligne
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentOrange.opacity(0.18))
                                .frame(width: 52, height: 52)
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color.accentOrange)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Connexion impossible")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(status)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 130)
                    
                } else {
                    // État 4 : Recall est à jour
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentGreen.opacity(0.18))
                                .frame(width: 52, height: 52)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color.accentGreen)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Recall est à jour")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Vous utilisez actuellement la version la plus récente (v\(autoUpdate.currentAppVersion)).")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 130)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
                .background(Color.borderSubtle)
            
            // Barre d'actions inférieure
            HStack(spacing: 10) {
                if autoUpdate.isInstalling {
                    Text("Veuillez patienter quelques secondes…")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                    Spacer()
                } else if autoUpdate.installError != nil {
                    Button {
                        autoUpdate.openBrowserFallback()
                        onClose()
                    } label: {
                        Text("Télécharger via navigateur")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button {
                        autoUpdate.installUpdate()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Réessayer")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.accentCyan)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                } else if autoUpdate.isUpdateAvailable {
                    Button {
                        onClose()
                    } label: {
                        Text("Plus tard")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button {
                        autoUpdate.installUpdate()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Installer et relancer")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.accentCyan)
                        .cornerRadius(6)
                        .shadow(color: Color.accentCyan.opacity(0.3), radius: 4, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    
                } else if !autoUpdate.isChecking {
                    Button {
                        autoUpdate.checkForUpdatesManually()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .bold))
                            Text("Rechercher à nouveau")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
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
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.cardBg.opacity(0.5))
        }
        .frame(width: 410)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
