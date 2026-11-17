import Foundation

/// Full system power draw in watts, from the SMC's main DC rail sensor.
///
/// The key varies by model, so we resolve the first candidate that reads a
/// plausible live value and cache it:
///   PSTR — "System Total Rail" (most Macs, incl. laptops on battery)
///   PDTR — "DC In Total Rail"  (adapter input)
///   PD0R — main DC rail         (Mac Studio/Pro — verified ~10.7W idle)
final class PowerReader: StatReader {
    let id = "power"
    let name = "Power"
    let symbolName = "bolt.fill"

    private let candidates = ["PSTR", "PDTR", "PD0R"]
    private var key: UInt32?
    private var resolved = false

    func sample() -> StatReading {
        if !resolved {
            resolve()
            resolved = true
        }
        guard let key, let watts = SMC.shared.readFloat(key), watts > 0 else {
            return StatReading(barText: "—", menuValue: "unavailable")
        }
        return StatReading(
            barText: String(format: "%.0fW", watts),
            menuValue: String(format: "%.1f W  ·  system total", watts)
        )
    }

    private func resolve() {
        guard SMC.shared.open() else { return }
        for name in candidates {
            let code = fourCC(name)
            // Exclude static rail ratings (hundreds of W) and absent keys.
            if let watts = SMC.shared.readFloat(code), watts > 0.1, watts < 1000 {
                key = code
                return
            }
        }
    }
}
