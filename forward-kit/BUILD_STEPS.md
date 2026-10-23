# BUILD STEPS — day one with a phone

These are the concrete steps for the forward work, assuming you have a supported device
(Redmi Note 10 Pro `sweet` or equivalent Snapdragon + Adreno 6xx + unlocked bootloader) and the
ios-sweet base already boots to the home screen on it. Steps are in dependency order; do not start one
before the one above it passes with recorded evidence (log + photo).

Nothing below is "done" — these are the steps to *do and verify on the device*, not results.

## 0. Base (ios-sweet, already documented upstream)

- Unlock the bootloader. Back up `persist`, `modemst1/2`, `fsg`, `boot`, `dtbo`, `vbmeta`.
- Build the XNU kernel (ios-sweet CI) and the iOS root (`tools/mkiosroot.sh` from your own IPSW).
- `fastboot boot shim/out/shim-boot.img` → home screen. This is the ios-sweet flow; see the repo root README.
- **Gate:** SpringBoard home screen, touch, Settings. (Proven on `sweet` upstream.)

## 1. `.ipa` runtime — prove the app pipeline

Goal: a one-screen app you built installs and launches. See `ipa-runtime/README.md` for the procedure
and `ipa-runtime/install-app.sh`.

- Build a trivial UIKit app (one label + one button) in Xcode for an **iOS 16 arm64** target.
- Ad-hoc sign it, drop it into the root image at `/Applications/`, add it to SpringBoard.
- Boot; confirm the icon appears and the app launches, renders, and responds to touch.
- **Gate (report each separately):** installed → icon shown → launched → rendered → touch works.

## 2. SweetWiFi (do this before the camera — highest value, simplest path)

Driver (on-device kernel work) and app (`apps/SweetWiFi/`).

- **Driver, staged (each a gate):**
  1. Bring up the Wi-Fi core (Snapdragon WCNSS) using the phone's own signed firmware; reference
     the ISC-licensed `wcn36xx` protocol. Log: firmware boots, control channel up.
  2. Present a kernel **Ethernet** `ifnet` (like ios-sweet's `ue0` USB path) that carries the Wi-Fi data.
  3. Expose the control interface in `apps/SweetWiFi/driver-contract.md` (scan / connect / status).
- **App:** install SweetWiFi via step 1's pipeline.
- **Gate:** SweetWiFi scans, shows a known SSID, connects (WPA2 via `wpa_supplicant`); then **Safari
  loads an HTTPS page** — that proves real internet for *all* apps, not just ours.
- Note: the genuine Settings/Control-Center Wi-Fi widget stays empty (that's the hard `IO80211` path,
  out of scope here).

## 3. SweetCam

Driver (on-device) and app (`apps/SweetCam/`).

- **Driver, staged (each a gate):**
  1. Power the sensor, read its chip-ID over I²C/CCI. Log the ID.
  2. Stream one RAW frame; debayer to BGRA; publish it in the shared frame buffer from
     `apps/SweetCam/driver-contract.md`.
  3. Live frames at a steady rate.
- **App:** install SweetCam. Preview from the shared buffer; shutter saves a JPEG.
- **Gate:** a valid saved photo from the real sensor; then a live preview. (Quality basic — no ISP tuning.)

## 4. GPU UI acceleration

See `gpu-ui/PLAN.md`. Order inside this step:

1. **Direct display scanout** (no GPU): stop the per-frame full-screen CPU copy; point the display
   controller at iOS's surface. **Gate:** measured fps/CPU vs the current ~10 Hz copy.
2. **Kernel GPU driver** exposing a KGSL-shaped interface; bring up Mesa turnip (Adreno 6xx).
   **Gate:** a GPU-filled buffer, timed vs CPU.
3. **Point CoreAnimation's GLES renderer at the GPU context.** **Gate:** SpringBoard scroll fps up,
   CPU down, no corruption.

## 5. SweetBT (last)

See `apps/SweetBT/`. A Bluetooth host stack (e.g. BTstack) over the chip's HCI transport + the app.
**Gate:** pair with one device. Hardest piece; schedule last.

## Recording

Every gate needs evidence in a ledger (log excerpt, photo, fps/CPU numbers). Do not mark a feature
working without a reproducible on-device test. Keep device dumps, serials and Apple artifacts out of git.
