# Mactokio

Your smartphone authenticator app, now on your Mac.

A security-first TOTP/HOTP authenticator built natively for macOS. Your secrets are **AES-256 encrypted**, **hardware-bound**, and **never leave your device**. No cloud. No sync. No account. Just your codes.

![Mactokio](screenshot.png)

---

## Security

| Layer          | Detail                                             |
| -------------- | -------------------------------------------------- |
| Encryption     | AES-256 with hardware-derived key                  |
| Key derivation | SHA-256 of device hardware UUID                    |
| Storage        | Encrypted files with `700`/`600` POSIX permissions |
| Authentication | Touch ID or device password on every launch        |
| Network        | Zero — no internet access, no telemetry            |

---

## Import from anywhere

Migrate your accounts from Google Authenticator, Microsoft Authenticator, Authy, or any TOTP/HOTP provider. No export to cloud needed — import directly via:

- **File** — text or QR code image
- **Clipboard** — copied text or QR screenshot
- **Camera** — scan QR code directly

Supports standard `otpauth://` URIs and Google Authenticator migration format.

---

## Features

- TOTP and HOTP with SHA-1 / SHA-256 / SHA-512
- Auto-lock codes after 3 cycles
- Search and filter accounts
- One-tap copy to clipboard

---

## Requirements

macOS 13.0+

## Installation

1. Download `Mactokio.zip` from [Releases](https://github.com/dalirnet/mactokio/releases/latest)
2. Extract and move `Mactokio.app` to Applications
3. Right-click → Open (first time only, to bypass Gatekeeper)

## Build

```bash
make build    # build the app
make run      # build and launch
make release  # universal binary (arm64 + x86_64)
make dist     # release + zip for distribution
```

## License

MIT
