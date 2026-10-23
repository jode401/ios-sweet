# SweetCam — driver contract

The boundary between the **app** (in this folder, real Swift) and the **kernel camera driver**
(does not exist yet; built on-device). The app depends only on what is written here.

**Status:** contract only. The driver is per-device kernel work (sensor over I²C/CCI, CSI receiver,
ISP/debayer) that must be built and tested on the phone.

## Service

An IOKit user client published under the name **`SweetCam`** (matched by `IOServiceMatching("SweetCam")`).
Follows the pattern of ios-sweet's existing in-kernel IOKit services (e.g. SweetHID).

## External methods (`IOConnectCallScalarMethod`)

| Selector | Name | Inputs | Effect |
|---|---|---|---|
| 0 | `start` | `width`, `height` | Power the sensor, begin streaming, allocate the shared frame buffer |
| 1 | `stop` | — | Stop streaming, free the buffer |
| 2 | `setFormat` | `fourcc` | Optional; default is BGRA8888 |

## Shared frame buffer (`IOConnectMapMemory`, memory type 0)

- The driver allocates one buffer and maps it into the app.
- Pixel format: **BGRA8888**, `bytesPerRow = width * 4`, top-left origin.
- The driver writes the newest frame into the buffer (**latest-wins**; double-buffer internally and flip,
  so the app never sees a half-written frame). A `uint32` frame sequence number at a fixed header offset
  lets the app detect new frames; for bring-up, polling the buffer at 15 Hz (as the app does) is fine.

## Driver responsibilities (the hard, on-device part)

1. Sensor power sequencing (regulators, clocks, reset GPIO).
2. Sensor control over I²C/CCI; read chip-ID first (the first gate).
3. CSI receiver + ISP (or a minimal path): capture RAW, **debayer to BGRA on the ISP or CPU**.
4. Publish frames into the shared buffer (latest-wins).
5. Expose exposure/focus later as added selectors (post-bring-up).

## Out of scope for the app
- No ISP tuning (quality is basic).
- No Portrait/HDR (those need Apple's pipeline).
- The app does **not** use Apple's AVFoundation/Camera.app path — it talks to this driver directly.

## Bring-up gates (on device)
1. `start` succeeds and chip-ID is logged.
2. One BGRA frame appears in the buffer → the app shows it / saves a JPEG.
3. Steady live frames at the app's 15 Hz.
