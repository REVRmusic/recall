import Cocoa

// Délai de survol prolongé (1.8s) pour ne pas gêner la navigation dans la liste des morceaux
let tooltipDelayMs = 1800
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
