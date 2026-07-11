# NetStatusWidget

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
to a GitHub Release.

## Notes

- The app polls `networksetup`, `scutil`, and `route` — all read-only, no elevated
  permissions required.
- VPN detection first checks system-configured VPN services (`scutil --nc list`); if none are
  connected, it falls back to detecting active `utunN` tunnel interfaces and matching known
  third-party VPN apps (Tailscale, NordVPN, WireGuard, etc.) currently running.
