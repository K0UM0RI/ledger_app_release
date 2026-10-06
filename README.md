# Ledger ðŸ“±

> Simple, fast, and completely offline debt & IOU tracker for Android.

Ledger helps you easily track who owes you and who you owe with friends and family. No accounts, no ads, no trackers, and no internet connection required.

---

## âœ¨ Features

- **âš¡ Fast & Lightweight**: Clean, responsive interface with instant search.
- **ðŸ”’ 100% Offline & Private**: Zero network requests. All data stays strictly on your local device.
- **ðŸš« Zero Ads**: Completely distraction-free and free forever.
- **ðŸŒ— Dark & Light Mode**: Automatically adapts or toggle your preference in Settings.
- **ðŸ”„ Full Data Portability**: Export and import your data anytime as transparent JSON backups with one-tap copy & paste.
- **ðŸ“Š Detailed Histories**: View sorted transaction histories and settle up balances with a single tap.

---

## ðŸ“¥ Download & Installation

1. Go to the [Releases](https://github.com/K0UM0RI/ledger_app_release/releases) page.
2. Download the latest `app-release.apk`.
3. Open the downloaded file on your Android device.
4. If prompted, allow "Install unknown apps" for your browser/file manager.
5. Tap **Install** and enjoy!

---

## ðŸ“– User Guide

### Adding Friends & Transactions
1. Tap the **+** button on the home screen to add a friend.
2. Tap on any friend's card to view their transaction history.
3. Tap **Add Transaction** to record an amount (specify whether you lent money or borrowed money).
4. When a debt is paid off, tap **Settle Up** to balance the account.

### Backup & Restore
- **Export Backup**: Go to `Settings` -> `Export Data`. You can copy the JSON directly to your clipboard or save it.
- **Restore Backup**: Go to `Settings` -> `Import Data`. Paste your JSON backup to restore your friends and transactions. You can choose to **Merge** with existing records or **Replace** everything.

---

## ðŸ› ï¸ Building from Source

If you prefer to build the app from source:

1. Ensure you have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed (Dart 3.x).
2. Clone this repository:
   ```bash
   git clone https://github.com/K0UM0RI/ledger_app_release.git
   cd ledger_app_release
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run in debug mode:
   ```bash
   flutter run
   ```

---

## ðŸ“„ License

This project is licensed under the [MIT License](LICENSE).