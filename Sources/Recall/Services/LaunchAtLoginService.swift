import Foundation
import ServiceManagement

/// Service gérant le lancement automatique de Recall au démarrage de macOS
public enum LaunchAtLoginService {
    @MainActor
    public static func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    if service.status != .enabled {
                        try service.register()
                        AppLogger.info("Démarrage automatique macOS activé avec succès.", category: .system)
                    }
                } else {
                    if service.status == .enabled {
                        try service.unregister()
                        AppLogger.info("Démarrage automatique macOS désactivé avec succès.", category: .system)
                    }
                }
            } catch {
                AppLogger.warning("Configuration démarrage automatique (SMAppService) : \(error.localizedDescription)", category: .system)
            }
        }
    }
    
    @MainActor
    public static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}
