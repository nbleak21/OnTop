import Darwin
import Foundation

/// Network throughput (down/up), from the delta of interface byte counters.
final class NetworkReader: StatReader {
    let id = "net"
    let name = "Network"
    let symbolName = "network"

    private var lastIn: UInt64 = 0
    private var lastOut: UInt64 = 0
    private var lastTime = Date()
    private var primed = false

    func sample() -> StatReading {
        let (totalIn, totalOut) = counters()
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTime)

        var downRate = 0.0
        var upRate = 0.0
        if primed && elapsed > 0 {
            // Guard against counter resets/wraps.
            if totalIn >= lastIn { downRate = Double(totalIn - lastIn) / elapsed }
            if totalOut >= lastOut { upRate = Double(totalOut - lastOut) / elapsed }
        }

        lastIn = totalIn
        lastOut = totalOut
        lastTime = now
        primed = true

        return StatReading(
            barText: "↓\(Fmt.rateFixed(downRate)) ↑\(Fmt.rateFixed(upRate))",
            menuValue: "↓ \(Fmt.rate(downRate))   ↑ \(Fmt.rate(upRate))"
        )
    }

    /// Sum ibytes/obytes across all non-loopback link-layer interfaces.
    private func counters() -> (UInt64, UInt64) {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return (0, 0) }
        defer { freeifaddrs(ifaddrPtr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ptr = cursor {
            let ifa = ptr.pointee
            if let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: ifa.ifa_name)
                if !name.hasPrefix("lo"), let dataPtr = ifa.ifa_data {
                    let data = dataPtr.assumingMemoryBound(to: if_data.self).pointee
                    totalIn += UInt64(data.ifi_ibytes)
                    totalOut += UInt64(data.ifi_obytes)
                }
            }
            cursor = ifa.ifa_next
        }
        return (totalIn, totalOut)
    }
}
