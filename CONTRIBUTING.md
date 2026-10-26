# Contributing

Thanks for helping improve Seamless WiFi. Bug reports, thoughtful feature requests, and pull requests are welcome.

## Development setup

- macOS 13 or later
- Xcode Command Line Tools with Swift 6

```sh
git clone https://github.com/ashhadsheikh/seamless-wifi.git
cd seamless-wifi
swift test
swift build -c release
./scripts/package-app.sh
```

Keep changes focused and explain the user impact in pull requests. Add or update unit tests for changes to the network scoring or switching decision logic. Please do not include Wi-Fi passwords, private network names, BSSIDs, or unredacted screenshots in issues or pull requests.

## Project principles

- Keep credentials in macOS Keychain and never store Wi-Fi passwords in the app.
- Keep measurements and monitoring state in memory; do not add connection history or persistent monitoring logs.
- Prefer Apple frameworks and avoid new third-party dependencies unless they clearly help.
- Describe measured behavior accurately and avoid overstating what a measurement proves.
