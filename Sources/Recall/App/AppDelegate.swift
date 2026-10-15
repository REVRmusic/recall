import Cocoa
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        // Délai de survol propre et réactif (0.7s) évitant les déclenchements parasites
        UserDefaults.standard.register(defaults: ["NSInitialToolTipDelay": 700])
        
        let windowController = FloatingWindowController.shared
        windowController.show()
        
        // Surveillance active
        SeratoMonitorService.shared.startMonitoring()
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        FloatingWindowController.shared.show()
        return true
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        SeratoMonitorService.shared.stopMonitoring()
    }
}
