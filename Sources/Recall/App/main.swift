import Cocoa

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

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
