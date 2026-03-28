# GeoFilza18

Read-only file manager for **iOS 18.0 – 18.6.2** using the [darksword](https://github.com/opa334/darksword-kexploit) kernel exploit.

Based on [GeoFilza](https://github.com/GeoSn0w/GeoFilza) (iOS 12) by GeoSn0w, adapted for iOS 18 with the KFS implementation from [lara](https://github.com/rooootdev/lara).

## Features

- **Exploit tab**: Download kernelcache, run darksword, initialize KFS
- **Browser tab**: Navigate the full iOS filesystem (read-only) via kernel vnode name cache
- **Search tab**: Auto-scanner for Apple Pay / Wallet image directories
- **Logs tab**: Full exploit and KFS debug output

## Building

The IPA is built automatically via GitHub Actions on every push.

Download the unsigned IPA from [Actions](../../actions) → latest workflow run → `GeoFilza18` artifact.

To install, re-sign the IPA with your free Apple Developer account using Xcode or a signing tool, then sideload to your device.

### Manual build
1. Open `GeoFilza18.xcodeproj` in Xcode 16+
2. Set your development team (free Apple Developer account works)
3. Build & run directly to your physical iOS device via Xcode

## Credits
- **opa334** — darksword kernel exploit, XPF
- **roooot** — lara KFS implementation
- **GeoSn0w** — original GeoFilza concept
- **AlfieCG** — libgrabkernel2

## Original GeoFilza

The legacy iOS 12 code is preserved in `geoPatcher/` and `geoPatcher.xcodeproj/`.
