# Mactokio

**Mac** + **Tok**en + **I/O**

Your smartphone authenticator app, now on your Mac.

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black.svg)
![Swift](https://img.shields.io/badge/Swift-native-orange.svg)

A security-first TOTP/HOTP authenticator built natively for macOS. Your secrets are **AES-256 encrypted**, **hardware-bound**, and **never leave your device**. No cloud. No sync. No account. Just your codes.

![Mactokio](screenshot.png)

---

## Why Mactokio?

Most people transfer authenticator accounts to their Mac by screenshotting the export QR code and sending it via email, Telegram, or WhatsApp. That screenshot — containing all your secret keys — now lives in chat histories, email servers, and cloud photo backups.

**Mactokio solves this.** Point your Mac's webcam at the QR code on your phone screen. Your secrets travel through the air, not through the internet. No screenshot. No file transfer. No cloud.

---

## Safe Import via Webcam

The recommended way to import your accounts:

1. On your phone, open your authenticator app → export/transfer accounts
2. In Mactokio, click **+** → **From Camera**
3. Hold your phone's screen up to your Mac's webcam
4. Done — all accounts imported and encrypted

The camera uses confidence-based detection across multiple frames, with visual feedback (tracking → green for success, red for invalid QR). Your secrets are encrypted the instant they're read.

Also supports:

- **From File** — QR code image or text file
- **From Clipboard** — QR screenshot or `otpauth://` URI

Supports standard `otpauth://` URIs and Google Authenticator migration format (`otpauth-migration://`).

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

## Features

- TOTP and HOTP with SHA-1 / SHA-256 / SHA-512
- Webcam QR scanner with confidence-based detection
- Google Authenticator bulk migration in one scan
- Touch ID / device password on every launch
- Auto-lock codes after 3 cycles
- Search and filter accounts
- One-tap copy to clipboard
- Zero network access

---

## Installation

1. Download `Mactokio.zip` from [Releases](https://github.com/dalirnet/mactokio/releases/latest)
2. Extract and move `Mactokio.app` to Applications
3. Right-click → Open (first time only, to bypass Gatekeeper)

**Requirements:** macOS 13.0+

## Build

```bash
make build    # build the app
make run      # build and launch
make release  # universal binary (arm64 + x86_64)
make dist     # release + zip for distribution
```

## License

MIT
