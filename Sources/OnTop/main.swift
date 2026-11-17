import AppKit

// Diagnostic: print the SMC temperature sensors discovered on this machine.
if CommandLine.arguments.contains("--list-sensors") {
    TemperatureReader.dumpSensors()
    exit(0)
}

// Diagnostic: sample GPU + FPS once, wait, and print a live reading.
if CommandLine.arguments.contains("--probe") {
    let gpu = GPUReader()
    let fps = FPSReader()
    _ = gpu.sample()
    _ = fps.sample()
    Thread.sleep(forTimeInterval: 1.5)
    print("GPU: \(gpu.sample().menuValue)")
    print("FPS: \(fps.sample().menuValue)")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // menu-bar only, no Dock icon
app.run()
