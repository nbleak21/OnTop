import Foundation

/// Total CPU usage, averaged across all logical cores, from the delta of
/// per-core tick counters between samples.
final class CPUReader: StatReader {
    let id = "cpu"
    let name = "CPU"
    let symbolName = "cpu"

    private var previous: [UInt32]?

    func sample() -> StatReading {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount
        )
        guard result == KERN_SUCCESS, let info else {
            return StatReading(barText: "—", menuValue: "unavailable")
        }
        defer {
            let size = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: UnsafeRawPointer(info))), size)
        }

        let ticks = UnsafeBufferPointer(start: info, count: Int(infoCount))
        let current = (0..<Int(infoCount)).map { UInt32(bitPattern: ticks[$0]) }

        var busyFraction = 0.0
        var counted = 0
        let states = Int(CPU_STATE_MAX)

        if let previous, previous.count == current.count {
            for core in 0..<Int(cpuCount) {
                let base = core * states
                let user = Double(current[base + Int(CPU_STATE_USER)] &- previous[base + Int(CPU_STATE_USER)])
                let system = Double(current[base + Int(CPU_STATE_SYSTEM)] &- previous[base + Int(CPU_STATE_SYSTEM)])
                let nice = Double(current[base + Int(CPU_STATE_NICE)] &- previous[base + Int(CPU_STATE_NICE)])
                let idle = Double(current[base + Int(CPU_STATE_IDLE)] &- previous[base + Int(CPU_STATE_IDLE)])
                let busy = user + system + nice
                let total = busy + idle
                if total > 0 {
                    busyFraction += busy / total
                    counted += 1
                }
            }
        }
        previous = current

        let pct = counted > 0 ? (busyFraction / Double(counted)) * 100 : 0
        return StatReading(
            barText: String(format: "%.0f%%", pct),
            menuValue: String(format: "%.0f%%  ·  %d cores", pct, Int(cpuCount))
        )
    }
}
