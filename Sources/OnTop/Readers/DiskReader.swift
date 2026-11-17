import Foundation

/// Used space on the boot volume.
final class DiskReader: StatReader {
    let id = "disk"
    let name = "Disk"
    let symbolName = "internaldrive"

    func sample() -> StatReading {
        let url = URL(fileURLWithPath: "/")
        guard
            let values = try? url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
            ]),
            let total = values.volumeTotalCapacity, total > 0
        else {
            return StatReading(barText: "—", menuValue: "unavailable")
        }

        let available = Double(values.volumeAvailableCapacityForImportantUsage ?? 0)
        let totalD = Double(total)
        let used = max(totalD - available, 0)
        let pct = (used / totalD) * 100
        let gb = 1_000_000_000.0  // Finder reports disk sizes in decimal GB

        return StatReading(
            barText: String(format: "%3.0f%%", pct),
            menuValue: String(format: "%.0f%%  ·  %.0f / %.0f GB used", pct, used / gb, totalD / gb)
        )
    }
}
