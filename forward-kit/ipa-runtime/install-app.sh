#!/bin/bash
# Install an iOS .app into a MOUNTED ios-sweet root image, offline on the build PC.
# TEMPLATE — not run on a device. Review before use. Adjust paths to your setup.
#
#   install-app.sh <App.app> <mounted-root> [entitlements.plist]
#
# Requirements on the Linux build host:
#   - ldid        (ad-hoc Mach-O signer; the Linux-friendly stand-in for `codesign -s -`)
#   - the root image mounted read-write (fsck.hfsplus -fy IMG; mount -t hfsplus -o loop,force IMG MNT)
# This only edits files on the mounted root; it does not touch a phone.
set -euo pipefail

APP=${1:?usage: install-app.sh <App.app> <mounted-root> [entitlements.plist]}
ROOT=${2:?mounted root path}
ENTS=${3:-}

[ -d "$APP" ] || { echo "not a .app bundle: $APP" >&2; exit 1; }
[ -d "$ROOT/System/Library/CoreServices" ] || { echo "does not look like an iOS root: $ROOT" >&2; exit 1; }

name=$(basename "$APP" .app)
bin="$APP/$name"
[ -f "$bin" ] || bin=$(/usr/bin/plutil -extract CFBundleExecutable raw "$APP/Info.plist" 2>/dev/null \
                        | sed "s|^|$APP/|") || true
[ -f "$bin" ] || { echo "cannot find the executable inside $APP" >&2; exit 1; }

# 1) Require an arm64 slice (arm64e-only apps will not run on this port).
if command -v lipo >/dev/null 2>&1; then
  lipo -archs "$bin" | tr ' ' '\n' | grep -qx arm64 || { echo "no arm64 slice in $bin" >&2; exit 1; }
fi

# 2) Ad-hoc sign (optionally with entitlements). Honored but not verified by ios-sweet patch 0035/0036.
if [ -n "$ENTS" ]; then ldid -S"$ENTS" "$bin"; else ldid -S "$bin"; fi

# 3) Copy the bundle into the system app location on the root.
dest="$ROOT/Applications/$name.app"
rm -rf "$dest"; mkdir -p "$ROOT/Applications"; cp -a "$APP" "$dest"
chmod -R a+rX "$dest"

echo "installed: $dest"
echo "NOTE: SpringBoard reads the installed-app cache at first boot. If the icon does not appear,"
echo "      rebuild the app registration on-device (uicache-equivalent) or seed the app-state plist;"
echo "      that step must be verified on the device and is intentionally not faked here."
