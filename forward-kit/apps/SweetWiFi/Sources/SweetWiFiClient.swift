// SweetWiFiClient — app-side wrapper for the SweetWiFi control driver.
// See ../driver-contract.md. STATUS: real source, NOT compiled or run. open() returns false
// when the service is absent. Struct byte layouts must match the driver contract.

import Foundation
import IOKit

final class SweetWiFiClient {
    enum Method: UInt32 { case scan = 0, connect = 1, status = 2, disconnect = 3 }
    enum State: UInt32 { case down = 0, scanning = 1, associating = 2, connected = 3, failed = 4 }
    struct Network: Equatable { let ssid: String; let rssi: Int; let secured: Bool }

    private let recSize = 36          // Network
    private let maxNetworks = 64

    private var conn: io_connect_t = 0

    func open() -> Bool {
        guard let match = IOServiceMatching("SweetWiFi") else { return false }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, match)
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        return IOServiceOpen(service, mach_task_self_, 0, &conn) == KERN_SUCCESS
    }

    func scan() -> [Network] {
        guard conn != 0 else { return [] }
        let cap = 4 + maxNetworks * recSize
        var out = [UInt8](repeating: 0, count: cap)
        var outSize = cap
        let kr = out.withUnsafeMutableBytes {
            IOConnectCallStructMethod(conn, Method.scan.rawValue, nil, 0, $0.baseAddress, &outSize)
        }
        guard kr == KERN_SUCCESS else { return [] }
        let count = Int(out.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) })
        var nets: [Network] = []
        for i in 0..<min(count, maxNetworks) {
            let b = 4 + i * recSize
            let ssidBytes = out[b..<b + 32].prefix { $0 != 0 }
            let ssid = String(bytes: ssidBytes, encoding: .utf8) ?? ""
            let rssi = Int(Int8(bitPattern: out[b + 32]))
            let secured = (out[b + 33] & 1) != 0
            if !ssid.isEmpty { nets.append(Network(ssid: ssid, rssi: rssi, secured: secured)) }
        }
        return nets
    }

    func connect(ssid: String, psk: String) -> Bool {
        guard conn != 0 else { return false }
        var input = [UInt8](repeating: 0, count: 96)   // ssid[32] + psk[64]
        for (i, b) in ssid.utf8.prefix(32).enumerated() { input[i] = b }
        for (i, b) in psk.utf8.prefix(64).enumerated() { input[32 + i] = b }
        return input.withUnsafeBytes {
            IOConnectCallStructMethod(conn, Method.connect.rawValue, $0.baseAddress, $0.count, nil, nil)
        } == KERN_SUCCESS
    }

    func status() -> (state: State, ip: String) {
        guard conn != 0 else { return (.down, "") }
        var out = [UInt8](repeating: 0, count: 8)
        var outSize = 8
        let kr = out.withUnsafeMutableBytes {
            IOConnectCallStructMethod(conn, Method.status.rawValue, nil, 0, $0.baseAddress, &outSize)
        }
        guard kr == KERN_SUCCESS else { return (.down, "") }
        let raw = out.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
        let ip = "\(out[4]).\(out[5]).\(out[6]).\(out[7])"
        return (State(rawValue: raw) ?? .down, ip)
    }

    func disconnect() {
        guard conn != 0 else { return }
        _ = IOConnectCallScalarMethod(conn, Method.disconnect.rawValue, nil, 0, nil, nil)
    }

    deinit { if conn != 0 { IOServiceClose(conn) } }
}
