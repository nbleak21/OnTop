import Foundation

/// A single snapshot of a statistic, ready to render.
struct StatReading {
    /// Short value for the menu-bar slot, e.g. "42%" or "↓1.2M".
    var barText: String
    /// Fuller value for the dropdown row, e.g. "42%  ·  6.8 / 16 GB".
    var menuValue: String
}

/// Something OnTop can measure and display. One instance per stat.
protocol StatReader: AnyObject {
    /// Stable identifier used for persistence (e.g. "ram").
    var id: String { get }
    /// Human label shown in the dropdown (e.g. "RAM").
    var name: String { get }
    /// SF Symbol name shown next to the value.
    var symbolName: String { get }
    /// Produce the current reading. Called on the main thread on a timer.
    func sample() -> StatReading
}

// MARK: - Formatting helpers

enum Fmt {
    /// Human byte rate for the dropdown, e.g. "1.2 MB/s".
    static func rate(_ bytesPerSec: Double) -> String {
        let (value, unit) = scale(bytesPerSec)
        return String(format: "%.1f %@/s", value, unit)
    }

    /// Compact byte rate for the tight menu-bar slot, e.g. "1.2M".
    static func rateCompact(_ bytesPerSec: Double) -> String {
        let (value, unit) = scale(bytesPerSec)
        let letter = unit.first.map(String.init) ?? ""
        return String(format: "%.1f%@", value, letter == "B" ? "" : letter)
    }

    private static func scale(_ bytes: Double) -> (Double, String) {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = max(bytes, 0)
        var idx = 0
        while value >= 1024 && idx < units.count - 1 {
            value /= 1024
            idx += 1
        }
        return (value, units[idx])
    }
}
