import Cocoa
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
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
