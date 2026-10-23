# SweetPort Forward Kit

Everything for the **app runtime + apps + UI-acceleration** work that sits on top of a booting
ios-sweet, prepared so that work can start the day a phone is in hand.

**Target:** a CPU-compatible Snapdragon with 16 KB pages and an **Adreno 6xx** GPU and an
unlockable bootloader — the ios-sweet base (Redmi Note 10 Pro `sweet`, or Poco X3 NFC).
Not for the Galaxy A02s (see the main report; that needs the atomics rewrite first).

## HONEST STATUS — read this first

| Part | What is in this kit | Tested? |
|---|---|---|
| `.ipa` runtime | A **written procedure + helper script** to ad-hoc-sign an app, place it in the root image, and launch it | **No.** Not run on a device. |
| App UI (SweetCam / SweetWiFi / SweetBT) | **Real Swift/UIKit source** — the screens, controls, and the code that calls the driver | **No.** Not built with Xcode, not run on device or simulator. |
| Driver side of each app | A **written contract** (`driver-contract.md`): the exact kernel interface the app calls. Plus a tiny stub so the boundary is clear. | **No.** The driver itself does not exist yet — per-device kernel work that needs the hardware. |
| GPU UI acceleration | A **step-by-step implementation plan** (`gpu-ui/PLAN.md`) mapped onto ios-sweet's real patch structure. Not code. | **No.** Needs the GPU driver, which needs the device. |

Nothing here is labeled "working." The app halves and the install procedure are the genuinely
phone-independent parts and are real. Each app is useless until its driver exists, and the drivers are
built and tested **on the phone** (build → flash → boot → read log → fix), exactly as ios-sweet built
its existing drivers.

**No iOS image is included or distributable.** You supply your own IPSW (Apple's licence); these apps
are dropped into the root image you build, as `BUILD_STEPS.md` describes.

## Layout

| Path | What |
|---|---|
| `BUILD_STEPS.md` | The day-one sequence: base, then where the runtime, apps, and GPU work slot in |
| `ipa-runtime/` | Install & launch `.ipa` apps (your own + legitimately-obtained unencrypted); signing; limits |
| `apps/SweetCam/` | Camera app: source + driver contract |
| `apps/SweetWiFi/` | Wi-Fi app (Ethernet-bridge model): source + driver contract |
| `apps/SweetBT/` | Bluetooth app: skeleton + contract (hardest, latest) |
| `gpu-ui/PLAN.md` | UI-on-GPU: direct scanout → iOS's own GLES renderer → Mesa turnip driver |

## Order of work (each gated on the one before)

1. **Base:** ios-sweet boots iOS 16 to the home screen on the device (already proven on `sweet`).
2. **`.ipa` runtime:** install and launch a self-built one-screen app. Proves the whole app pipeline
   (sign → install → SpringBoard icon → launch → render → touch). Our own apps ride this path.
3. **SweetWiFi** — first real app: the Ethernet-bridge path gives every app real internet for the
   least driver complexity.
4. **SweetCam** — camera driver + app.
5. **GPU UI acceleration** — direct scanout first (biggest win, no GPU), then the GLES renderer + driver.
6. **SweetBT** — last; a full Bluetooth host stack is the hardest piece.

See `BUILD_STEPS.md` for the concrete steps under each.
