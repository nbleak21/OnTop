import AppKit

// Diagnostic: print the SMC temperature sensors discovered on this machine.
if CommandLine.arguments.contains("--list-sensors") {
    TemperatureReader.dumpSensors()
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // menu-bar only, no Dock icon
app.run()
