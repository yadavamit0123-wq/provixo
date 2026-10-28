# GitHub Actions — Android APK & AAB (ProVixo Customer)

## Repository secrets

Add these in **Settings → Secrets and variables → Actions**:

| Secret | Description |
|--------|-------------|
| `KEYSTORE_BASE64` | Base64 of `prt.jks` (see command below) |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_PASSWORD` | Key password (often same as keystore) |
| `KEY_ALIAS` | Alias inside the JKS |

## Encode keystore (run on your Mac)

```bash
base64 -i "/Users/amityadav/Projects/prt.jks" | pbcopy
```

Paste clipboard into GitHub secret `KEYSTORE_BASE64`.

## SHA-1 / SHA-256 (Firebase & Google Maps)

Replace `YOUR_ALIAS` with the alias from your JKS:

```bash
"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" -list -v \
  -keystore "/Users/amityadav/Projects/prt.jks" \
  -alias YOUR_ALIAS
```

Add **SHA-1** and **SHA-256** in [Firebase Console](https://console.firebase.google.com/) → Project **provixo-4af10** → Android app **com.pt.provixo** → App fingerprint.

Repeat for **com.pt.provixoprovider** in the provider repo / Firebase app entry.

## Run build

Push to `main`/`master` or use **Actions → Android Release (APK + AAB) → Run workflow**.

Download **Artifacts**: `provixo-customer-apk` and `provixo-customer-aab`.
