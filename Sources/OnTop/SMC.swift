import Foundation
import IOKit

// Four-character code helpers (SMC keys and data types are packed FourCCs).
func fourCC(_ s: String) -> UInt32 {
    var result: UInt32 = 0
    for byte in s.utf8.prefix(4) {
        result = (result << 8) | UInt32(byte)
    }
    return result
}

func fourCCString(_ value: UInt32) -> String {
    let bytes = [
        UInt8((value >> 24) & 0xff),
        UInt8((value >> 16) & 0xff),
        UInt8((value >> 8) & 0xff),
        UInt8(value & 0xff),
    ]
    return String(bytes: bytes, encoding: .ascii) ?? ""
}

// 32-byte payload carried by an SMC transaction.
typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
    // Swift reuses an inner struct's tail padding for the next field, unlike C.
    // These 3 bytes make the struct a full 12 bytes so `result` lands at the
    // same offset the kernel expects (keeping SMCParamStruct at 80 bytes).
    var reserved0: UInt8 = 0
    var reserved1: UInt8 = 0
    var reserved2: UInt8 = 0
}

/// Mirrors the kernel's SMCKeyData_t. Field order and types must match the C
/// struct exactly (Swift lays out stored properties in declaration order).
private struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCLimitData()
    var keyInfo = SMCKeyInfoData()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )
}

// SMC command codes placed in `data8`.
private enum SMCCommand {
    static let readBytes: UInt8 = 5
    static let readIndex: UInt8 = 8
    static let readKeyInfo: UInt8 = 9
}

/// Thin wrapper over the AppleSMC user client. Read-only; opens lazily.
final class SMC {
    static let shared = SMC()

    private var connection: io_connect_t = 0
    private var isOpen = false

    @discardableResult
    func open() -> Bool {
        if isOpen { return true }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        isOpen = (result == kIOReturnSuccess)
        return isOpen
    }

    func close() {
        if isOpen {
            IOServiceClose(connection)
            isOpen = false
        }
    }

    private func call(_ input: inout SMCParamStruct, _ output: inout SMCParamStruct) -> Bool {
        guard isOpen else { return false }
        let inputSize = MemoryLayout<SMCParamStruct>.stride
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        let kr = IOConnectCallStructMethod(connection, 2, &input, inputSize, &output, &outputSize)
        return kr == kIOReturnSuccess && output.result == 0
    }

    /// Low-level sanity check for `--list-sensors`.
    func probe() {
        let stride = MemoryLayout<SMCParamStruct>.stride
        print("SMCParamStruct stride = \(stride) \(stride == 80 ? "(ok)" : "(EXPECTED 80)")")
        print("AppleSMC open() = \(open())")
    }

    private func keyInfo(_ key: UInt32) -> SMCKeyInfoData? {
        var input = SMCParamStruct()
        input.key = key
        input.data8 = SMCCommand.readKeyInfo
        var output = SMCParamStruct()
        guard call(&input, &output) else { return nil }
        return output.keyInfo
    }

    /// Number of keys the SMC exposes (value of the "#KEY" key).
    func keyCount() -> Int {
        guard let (bytes, _) = readRaw(fourCC("#KEY")) else { return 0 }
        return Int(UInt32(bytes.0) << 24 | UInt32(bytes.1) << 16 | UInt32(bytes.2) << 8 | UInt32(bytes.3))
    }

    /// The FourCC key at a given enumeration index.
    func key(at index: Int) -> UInt32? {
        var input = SMCParamStruct()
        input.data8 = SMCCommand.readIndex
        input.data32 = UInt32(index)
        var output = SMCParamStruct()
        guard call(&input, &output) else { return nil }
        return output.key
    }

    /// Raw bytes plus the key's declared data type.
    func readRaw(_ key: UInt32) -> (SMCBytes, UInt32)? {
        guard let info = keyInfo(key) else { return nil }
        var input = SMCParamStruct()
        input.key = key
        input.keyInfo.dataSize = info.dataSize
        input.data8 = SMCCommand.readBytes
        var output = SMCParamStruct()
        guard call(&input, &output) else { return nil }
        return (output.bytes, info.dataType)
    }

    /// Decode a temperature key to degrees Celsius (handles sp78 and flt).
    func readTemperature(_ key: UInt32) -> Double? {
        guard let (bytes, type) = readRaw(key) else { return nil }
        if type == fourCC("sp78") {
            let raw = Int16(bitPattern: UInt16(bytes.0) << 8 | UInt16(bytes.1))
            return Double(raw) / 256.0
        }
        if type == fourCC("flt ") {
            let bits = UInt32(bytes.0) | UInt32(bytes.1) << 8 | UInt32(bytes.2) << 16 | UInt32(bytes.3) << 24
            return Double(Float(bitPattern: bits))
        }
        return nil
    }

    /// Decode a float ("flt ") key to a Double.
    func readFloat(_ key: UInt32) -> Double? {
        guard let (bytes, type) = readRaw(key), type == fourCC("flt ") else { return nil }
        let bits = UInt32(bytes.0) | UInt32(bytes.1) << 8 | UInt32(bytes.2) << 16 | UInt32(bytes.3) << 24
        return Double(Float(bitPattern: bits))
    }

    /// Enumerate all keys and return those that read back as plausible
    /// temperatures (0–120 °C), paired with their current value.
    func discoverTemperatureKeys() -> [(key: String, value: Double)] {
        discover(prefix: "T", low: 0, high: 120) { readTemperature($0) }
    }

    /// Enumerate all keys and return the "P" (power, watts) float sensors.
    func discoverPowerKeys() -> [(key: String, value: Double)] {
        discover(prefix: "P", low: 0.001, high: 2000) { readFloat($0) }
    }

    private func discover(prefix: String, low: Double, high: Double,
                          read: (UInt32) -> Double?) -> [(key: String, value: Double)] {
        guard open() else { return [] }
        var found: [(String, Double)] = []
        let count = keyCount()
        guard count > 0 else { return [] }
        for index in 0..<count {
            guard let code = key(at: index) else { continue }
            let name = fourCCString(code)
            guard name.hasPrefix(prefix) else { continue }
            if let value = read(code), value > low, value < high {
                found.append((name, value))
            }
        }
        return found
    }
}
