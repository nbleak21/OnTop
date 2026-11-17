import Foundation

/// RAM usage, computed to match Activity Monitor's "Memory Used"
/// (App Memory + Wired + Compressed).
final class MemoryReader: StatReader {
    let id = "ram"
    let name = "RAM"
    let symbolName = "memorychip"

    private let totalBytes: Double = {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return Double(size)
    }()

    func sample() -> StatReading {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let host = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(host, HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return StatReading(barText: "—", menuValue: "unavailable")
        }

        let page = Double(vm_page_size)
        let wired = Double(stats.wire_count) * page
        let compressed = Double(stats.compressor_page_count) * page
        let appMemory = (Double(stats.internal_page_count) - Double(stats.purgeable_count)) * page
        let used = max(wired + compressed + appMemory, 0)

        let pct = totalBytes > 0 ? (used / totalBytes) * 100 : 0
        let gb = 1024.0 * 1024.0 * 1024.0
        return StatReading(
            barText: String(format: "%.0f%%", pct),
            menuValue: String(format: "%.0f%%  ·  %.1f / %.0f GB", pct, used / gb, totalBytes / gb)
        )
    }
}
