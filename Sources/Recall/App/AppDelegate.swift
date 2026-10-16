import Cocoa
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        // Délai de survol optimisé (0.9s) évitant les déclenchements intempestifs tout en restant réactif
        let tooltipDelayMs = 900
        UserDefaults.standard.register(defaults: [
            "NSInitialToolTipDelay": tooltipDelayMs,
            "NSReshowToolTipDelay": tooltipDelayMs,
            "NSAutoToolTipDelay": tooltipDelayMs
        ])
        UserDefaults.standard.set(tooltipDelayMs, forKey: "NSInitialToolTipDelay")
        UserDefaults.standard.set(tooltipDelayMs, forKey: "NSReshowToolTipDelay")
        UserDefaults.standard.set(tooltipDelayMs, forKey: "NSAutoToolTipDelay")
        
        let windowController = FloatingWindowController.shared
        windowController.show()
        
        // Surveillance active
        SeratoMonitorService.shared.startMonitoring()
        
        // Recherche de mise à jour automatique au démarrage (uniquement si connecté à Internet)
        AutoUpdateService.shared.checkForUpdatesOnStartup()
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        FloatingWindowController.shared.show()
        return true
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        SeratoMonitorService.shared.stopMonitoring()
    }
}
