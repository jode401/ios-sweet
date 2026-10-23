// SweetCamClient — app-side wrapper for the SweetCam kernel driver.
// See ../driver-contract.md. STATUS: real source, NOT compiled or run. The driver it talks
// to does not exist yet; open() returns false when the service is absent.

import Foundation
import IOKit

final class SweetCamClient {
    enum Method: UInt32 { case start = 0, stop = 1, setFormat = 2 }
    enum MemoryType: UInt32 { case frameBuffer = 0 }

    struct Frame {
        let base: UnsafeRawPointer
        let width: Int
        let height: Int
        let bytesPerRow: Int
    }

    private var connect: io_connect_t = 0
    private var mapAddr: mach_vm_address_t = 0
    private var mapSize: mach_vm_size_t = 0
    private(set) var width = 0
    private(set) var height = 0
    private(set) var bytesPerRow = 0

    /// Open the driver. Returns false if the `SweetCam` service is absent (driver not loaded).
    func open() -> Bool {
        guard let match = IOServiceMatching("SweetCam") else { return false }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, match)
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        return IOServiceOpen(service, mach_task_self_, 0, &connect) == KERN_SUCCESS
    }

    /// Start streaming at the requested size and map the shared BGRA frame buffer.
    func start(width w: Int, height h: Int) -> Bool {
        var args: [UInt64] = [UInt64(w), UInt64(h)]
        guard connect != 0,
              IOConnectCallScalarMethod(connect, Method.start.rawValue, &args, 2, nil, nil) == KERN_SUCCESS
        else { return false }
        guard IOConnectMapMemory64(connect, MemoryType.frameBuffer.rawValue, mach_task_self_,
                                   &mapAddr, &mapSize, IOOptionBits(kIOMapAnywhere)) == KERN_SUCCESS,
              mapAddr != 0
        else { return false }
        width = w; height = h; bytesPerRow = w * 4   // BGRA8888
        return true
    }

    /// The latest frame in the shared buffer. Valid until the driver's next write; copy to keep it.
    func latestFrame() -> Frame? {
        guard mapAddr != 0, let base = UnsafeRawPointer(bitPattern: UInt(mapAddr)) else { return nil }
        return Frame(base: base, width: width, height: height, bytesPerRow: bytesPerRow)
    }

    func stop() {
        guard connect != 0 else { return }
        _ = IOConnectCallScalarMethod(connect, Method.stop.rawValue, nil, 0, nil, nil)
        if mapAddr != 0 {
            IOConnectUnmapMemory64(connect, MemoryType.frameBuffer.rawValue, mach_task_self_, mapAddr)
            mapAddr = 0
        }
    }

    deinit {
        stop()
        if connect != 0 { IOServiceClose(connect) }
    }
}
