# SweetBT — Bluetooth (skeleton, hardest, scheduled last)

**Status:** skeleton + contract only. This is the hardest of the three apps because it needs a full
Bluetooth **host stack**, not just a driver. Do it after Wi-Fi, camera, and the GPU work.

## Why it's the hardest
A camera or Wi-Fi driver moves bytes to/from one chip. Bluetooth needs an entire protocol stack above
the radio: HCI → L2CAP → SMP (pairing/encryption) → GATT → the specific profiles (A2DP audio, HID, etc.).
Apple's own stack is closed, so we bring our own.

## Approach
1. **Driver:** expose the controller's **HCI** transport (UART/SMD/USB depending on the chip) as a
   packet interface from the kernel. Load the chip's own firmware.
2. **Host stack:** run **BTstack** (BlueKitchen; permissive dual license — verify terms for your use) or
   port an existing stack, in userspace, over that HCI interface.
3. **App (`SweetBT`):** a UIKit screen (mirrors `SweetWiFi`'s list/connect pattern) that calls a small
   control interface — power, scan, pair, connect — exposed by the stack. See `Sources/SweetBTClient.swift`
   for the shape.

## Control interface (IOKit user client `SweetBT`, to finalize with the stack)

| Selector | Name | Notes |
|---|---|---|
| 0 | `powerOn` | Load firmware, HCI reset |
| 1 | `scan` | Inquiry / LE scan → device list |
| 2 | `pair` | SMP pairing with a device address |
| 3 | `connect` | Open a profile (HID/A2DP/…) |

## Bring-up gates (on device)
1. HCI up: controller answers `HCI_Reset` + reads its address.
2. Scan returns a nearby device.
3. Pair with one device.
4. One profile works (e.g. a BT keyboard as HID).

The UI follows `apps/SweetWiFi/Sources/WiFiViewController.swift` closely; it is not duplicated here until
the stack's control interface is finalized on real hardware.
