import AppKit

// Diagnostic: print the SMC temperature sensors discovered on this machine.
if CommandLine.arguments.contains("--list-sensors") {
    TemperatureReader.dumpSensors()
    exit(0)
}

// Diagnostic: list the SMC power (watt) sensors discovered on this machine.
if CommandLine.arguments.contains("--list-power") {
    guard SMC.shared.open() else { print("Could not open AppleSMC."); exit(0) }
    let keys = SMC.shared.discoverPowerKeys().sorted { $0.value > $1.value }
    print("Power sensors (flt, W): \(keys.count)")
    for k in keys { print(String(format: "  %@  %9.3f W", k.key, k.value)) }
    SMC.shared.close()
    exit(0)
}

// Diagnostic: sample GPU + FPS once, wait, and print a live reading.
if CommandLine.arguments.contains("--probe") {
    let gpu = GPUReader()
    let fps = FPSReader()
    let power = PowerReader()
    _ = gpu.sample()
    _ = fps.sample()
    _ = power.sample()
    Thread.sleep(forTimeInterval: 1.5)
    print("GPU:   \(gpu.sample().menuValue)")
    print("Power: \(power.sample().menuValue)")
    print("FPS:   \(fps.sample().menuValue)")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // menu-bar only, no Dock icon
app.run()
