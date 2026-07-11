# NetStatusWidget

[فارسی](README.fa.md)

A macOS menu bar app that shows, at a glance:

- Whether an HTTP/HTTPS/SOCKS proxy (or PAC auto-proxy) is set
- Whether DNS servers are manually configured
- Whether a VPN is active, and its name
- The currently connected network (Wi-Fi SSID or Ethernet service)

## Download (no build required)

1. Grab the latest `NetStatusWidget-*-macos.zip` from the [Releases](../../releases) page.
2. Unzip it and drag `NetStatusWidget.app` into `/Applications`.
3. This build is **not signed by an Apple Developer ID**, so on first launch macOS Gatekeeper
   will refuse to open it with an "unidentified developer" warning. To run it:
   - Right-click (or Control-click) `NetStatusWidget.app` → **Open** → confirm **Open** in the dialog.
   - If that still fails, run in Terminal: `xattr -cr /Applications/NetStatusWidget.app`
4. A network icon appears in the menu bar. Click it to see the status panel.

### Verify the download

This build is ad-hoc signed only (not notarized by Apple), so its signature can't prove who
built it. Each [Release](../../releases) publishes a SHA256 checksum for its zip — verify the
file you downloaded matches before opening it:

```bash
shasum -a 256 NetStatusWidget-*-macos.zip
```

Compare the output against the checksum listed on that release's page. If they don't match,
don't open the app — re-download from the official Releases page.

## Build from source

Requires Xcode Command Line Tools (`xcode-select --install`) and Swift 5.9+.

```bash
swift run
```

## Package a release build

```bash
./scripts/build_app.sh 1.0.0
```

Produces `dist/NetStatusWidget.app` and `dist/NetStatusWidget-1.0.0-macos.zip`, ready to attach
to a GitHub Release. The app icon is pre-built at `Packaging/AppIcon.icns`; to regenerate it
from scratch:

```bash
swiftc scripts/generate_icon.swift -o /tmp/gen_icon -framework AppKit
/tmp/gen_icon Packaging/AppIcon.iconset
iconutil -c icns Packaging/AppIcon.iconset -o Packaging/AppIcon.icns
rm -rf Packaging/AppIcon.iconset
```

When cutting a new release, publish the zip's SHA256 in the release notes:

```bash
shasum -a 256 dist/NetStatusWidget-1.0.0-macos.zip
```

## Notes

- The app polls `networksetup`, `scutil`, and `route` — all read-only, no elevated
  permissions required.
- VPN detection first checks system-configured VPN services (`scutil --nc list`); if none are
  connected, it falls back to detecting active `utunN` tunnel interfaces and matching known
  third-party VPN apps (Tailscale, NordVPN, WireGuard, etc.) currently running.
- No network calls, telemetry, or credential handling anywhere in the app — it only reads local
  network configuration.
- The build is unsigned/ad-hoc only. If this project ever accepts external contributions, review
  pull requests carefully before cutting a release — there's no Apple notarization step to catch
  tampered binaries.
