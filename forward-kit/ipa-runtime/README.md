# .ipa runtime — install and launch apps

How this port runs `.ipa` apps: **your own builds** and **legitimately-obtained unencrypted** apps.
This is the pipeline every app in this kit (SweetCam/SweetWiFi/SweetBT) rides on.

**Status:** procedure + helper script written, **not run on a device.** Nothing here is "working" yet.

## What a .ipa is

A zip: `Payload/<App>.app/` containing an arm64 Mach-O executable, `Info.plist`, and resources.
For this port the executable must have an **arm64** slice (not only arm64e). Most apps do.

## Signing — why it still matters with security "off"

iOS loads only code with a valid code signature, even when AMFI policy is permissive. ios-sweet's
patches **0035/0036** make every signed binary on the root a platform binary and honor its entitlements
without verifying them. So an **ad-hoc signature** is enough:

```sh
codesign -f -s - --entitlements entitlements.plist Payload/<App>.app/<App>
```

- Ad-hoc (`-s -`) means no Apple developer certificate is needed.
- A minimal `entitlements.plist` (e.g. `application-identifier`, `get-task-allow`) is parsed and honored.
- FairPlay-encrypted App Store binaries (`LC_ENCRYPTION_INFO_64 cryptid=1`) are **not** handled — see Limits.

## Install paths

| App kind | Where it goes | How SpringBoard sees it |
|---|---|---|
| Our system apps (SweetCam/SweetWiFi/SweetBT) and bring-up test apps | `/<root>/Applications/<App>.app` (system app location) | Registered at boot by `installd`/`lsregister`; the kit's `install-app.sh` also seeds the app-state so the icon appears first boot |
| Ordinary third-party unencrypted `.ipa` | Normally `/var/containers/Bundle/Application/<UUID>/` via `installd` | For bring-up, the system-app path above is simplest until on-device `installd` install is confirmed |

`install-app.sh` (in this folder) does the offline, PC-side install into a mounted root image:
ad-hoc signs, copies the `.app` into `/Applications`, and records the install so SpringBoard shows it.
It is a **procedure to run on your PC against the HFS+ root image**, not a device tool.

## Acceptance — report each stage separately

1. **Installed** — the `.app` is present and registered.
2. **Icon** — it shows on the home screen.
3. **Launched** — the process starts and `main()` is reached (check the kernel/launchd log).
4. **Rendered** — first frame on screen.
5. **Used** — the core function works.

A home-screen icon is **not** proof of execution. Log launch and render separately.

## Limits (hard)

- **FairPlay-encrypted App Store apps:** not supported. Their code is encrypted; running them needs
  Apple's copy protection removed, which this project does not do, by any method.
- **App Store install / Apple ID sign-in:** not supported (needs Apple device attestation).
- **Framework gaps:** apps needing Metal/GPU, camera, audio, GPS or push will fail or crash until those
  drivers exist. Expect missing-symbol or service-unavailable failures; log them per app.
- **arm64e-only apps** (built only for pointer-authentication devices) will not run — need an arm64 slice.

## First target

A one-screen UIKit app you build yourself (one label + one button that writes a file). It exercises the
whole pipeline with zero driver dependencies — the right first proof before SweetWiFi/SweetCam.
