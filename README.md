# Seamless WiFi

**Stay connected as you move.**

Seamless WiFi is a native macOS menu bar app that helps your Mac move to a better saved Wi-Fi network when the current connection becomes weak or unhealthy.

[![macOS CI](https://github.com/ashhadsheikh/seamless-wifi/actions/workflows/ci.yml/badge.svg)](https://github.com/ashhadsheikh/seamless-wifi/actions/workflows/ci.yml)
[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## What it does

- Shows your current Wi-Fi network, signal strength, and internet reachability from the menu bar.
- Lists nearby networks that macOS has saved and can use.
- Automatically switches when a saved alternative's Wi-Fi signal is at least 12 dB stronger for 15 seconds. The alternative's internet quality cannot be measured until connected.
- Offers **Ask before switching** and **Monitor only** modes.
- Uses saved Wi-Fi credentials from macOS Keychain to request a network switch. macOS may show a Keychain or administrator authorization prompt. The app holds a retrieved credential in memory while it is running and does not save it to disk.

Automatic switching waits for a sustained improvement and observes a three-minute cooldown by default to reduce repeated switching. In Settings, adjust the minimum signal improvement (6–24 dB) and cooldown (30 seconds–10 minutes).

Automatic switching has not yet been verified as reliable across macOS configurations. macOS permissions, hidden network names, Keychain access controls, or network association authorization can prevent a switch. Check the app's status after a switch attempt; do not assume the network changed until the current network confirms it.

## Install

There is no public signed release yet. You can build the app from source on macOS 13 or later with Xcode Command Line Tools and Swift 6:

```sh
git clone https://github.com/ashhadsheikh/seamless-wifi.git
cd seamless-wifi
swift test
./scripts/package-app.sh
open "dist/Seamless WiFi.app"
```

The packaging script creates a universal app for Apple Silicon and Intel Macs, plus ZIP and DMG archives. Local builds are ad-hoc signed. macOS may require you to confirm the first launch. A Developer ID signature and notarization are required for a frictionless download from the web.

## Permissions

Seamless WiFi asks for Location Services access so macOS can provide Wi-Fi network names and BSSIDs. You can manage this in **System Settings → Privacy & Security → Location Services**. Without permission, macOS may hide Wi-Fi names and the app cannot reliably identify networks to switch between.

## How connection quality is measured

Wi-Fi signal and internet health are shown separately. A strong signal does not necessarily mean that the internet connection is healthy.

The app reads Wi-Fi signal strength, noise, and link rate through CoreWLAN. It checks the current internet path with Apple’s Network framework and measures the time to establish a lightweight TCP connection to a probe endpoint. This connection time is an estimate, not a pure round-trip latency measurement.

Internet quality on another Wi-Fi network cannot be known until the Mac connects to it. Packet loss is not currently measured. The app avoids showing these as known measurements.

## Privacy

- No account, backend, analytics, or cloud service.
- Saved Wi-Fi credentials remain managed by macOS Keychain. During a switch, the app requests the saved credential from Keychain and keeps it in memory until the app quits to avoid repeated Keychain reads. macOS may prompt for authorization. The app does not write credentials to disk.
- Live measurements and switching state stay in memory.
- Only app preferences, such as switching mode, signal threshold, and cooldown, are saved locally.
- No connection history or persistent monitoring logs.

## Development

Run the unit tests:

```sh
swift test
```

Build the app locally:

```sh
swift build
./scripts/package-app.sh
```

GitHub Actions runs the unit tests and builds release binaries for Apple Silicon and Intel Macs.
