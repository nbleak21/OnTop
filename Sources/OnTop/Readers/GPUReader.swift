import Foundation
import IOKit

/// GPU utilization from the accelerator's IORegistry PerformanceStatistics.
/// On Apple Silicon this is the `AGXAccelerator*` service; "Device
/// Utilization %" is the overall busy figure.
final class GPUReader: StatReader {
    let id = "gpu"
    let name = "GPU"
    let symbolName = "square.stack.3d.up.fill"

    func sample() -> StatReading {
        guard let stats = Self.performanceStatistics() else {
            return StatReading(barText: "—", menuValue: "unavailable")
        }

        let device = intValue(stats, "Device Utilization %") ?? intValue(stats, "GPU Activity(%)") ?? 0
        let tiler = intValue(stats, "Tiler Utilization %") ?? 0
        let renderer = intValue(stats, "Renderer Utilization %") ?? 0

        return StatReading(
            barText: String(format: "%d%%", device),
            menuValue: String(format: "%d%%  ·  tiler %d%%  render %d%%", device, tiler, renderer)
        )
    }

    private func intValue(_ dict: [String: Any], _ key: String) -> Int? {
        (dict[key] as? NSNumber)?.intValue
    }

    /// Walk the IOAccelerator services and return the first PerformanceStatistics dict.
    private static func performanceStatistics() -> [String: Any]? {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOAccelerator")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            var properties: Unmanaged<CFMutableDictionary>?
            let result = IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0)
            var found: [String: Any]?
            if result == kIOReturnSuccess,
               let dict = properties?.takeRetainedValue() as? [String: Any],
               let perf = dict["PerformanceStatistics"] as? [String: Any] {
                found = perf
            }
            IOObjectRelease(entry)
            if let found { return found }
            entry = IOIteratorNext(iterator)
        }
        return nil
    }
}
