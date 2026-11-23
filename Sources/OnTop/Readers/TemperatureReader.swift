// Copyright (c) 2026 OnTop contributors
// SPDX-License-Identifier: MIT

import Foundation

/// CPU temperature from the SMC. Discovers sensor keys once, then reads only
/// those each tick. Falls back to the OS thermal-pressure state when no
/// numeric sensors are readable (common on some Apple Silicon configs).
final class TemperatureReader: StatReader {
    let id = "temp"
    let name = "Temp"
    let symbolName = "thermometer.medium"

    /// nil = not yet discovered; [] = none available, use fallback.
    private var sensorKeys: [UInt32]?

    func sample() -> StatReading {
        if sensorKeys == nil {
            discover()
        }

        if let keys = sensorKeys, !keys.isEmpty {
            var values: [Double] = []
            for key in keys {
                if let value = SMC.shared.readTemperature(key), value > 0, value < 120 {
                    values.append(value)
                }
            }
            if !values.isEmpty {
                let avg = values.reduce(0, +) / Double(values.count)
                let peak = values.max() ?? avg
                return StatReading(
                    barText: String(format: "%2.0f°", avg),
                    menuValue: String(format: "%.0f°C avg  ·  %.0f°C peak", avg, peak)
                )
            }
        }

        return thermalFallback()
    }

    private func discover() {
        let discovered = SMC.shared.discoverTemperatureKeys()
        // Prefer CPU performance-core sensors ("Tp..") on Apple Silicon or the
        // classic Intel CPU proximity keys ("TC0."); otherwise use every sensor.
        let cpu = discovered.filter { $0.key.hasPrefix("Tp") || $0.key.hasPrefix("TC0") }
        let chosen = cpu.isEmpty ? discovered : cpu
        sensorKeys = chosen.map { fourCC($0.key) }
    }

    private func thermalFallback() -> StatReading {
        let label: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: label = "Nominal"
        case .fair: label = "Fair"
        case .serious: label = "Serious"
        case .critical: label = "Critical"
        @unknown default: label = "Unknown"
        }
        return StatReading(barText: label, menuValue: "\(label)  ·  no SMC sensor")
    }

    /// Used by the `--list-sensors` diagnostic flag.
    static func dumpSensors() {
        SMC.shared.probe()
        guard SMC.shared.open() else {
            print("Could not open AppleSMC.")
            return
        }
        let sensors = SMC.shared.discoverTemperatureKeys()
        print("SMC key count: \(SMC.shared.keyCount())")
        print("Temperature-like sensors found: \(sensors.count)")
        for sensor in sensors.sorted(by: { $0.value > $1.value }) {
            print(String(format: "  %@  %6.2f °C", sensor.key, sensor.value))
        }
        SMC.shared.close()
    }
}
