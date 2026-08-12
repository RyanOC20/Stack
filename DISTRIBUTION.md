# Distributing Cairn (macOS)

Cairn is a direct-download macOS app (not Mac App Store). To ship a build that launches
without Gatekeeper warnings, it must be **signed with a Developer ID certificate**,
**notarized** by Apple, and **stapled**. Auto-updates are delivered via **Sparkle**.

The project is already configured for this: **Hardened Runtime is enabled**
(`ENABLE_HARDENED_RUNTIME = YES`, required for notarization) and the app declares the
`com.apple.security.network.client` entitlement. Everything below needs *your* Apple
Developer account, so it isn't automated in CI.

## Prerequisites

- Apple Developer Program membership.
- A **Developer ID Application** certificate in your login keychain
  (Xcode → Settings → Accounts → Manage Certificates → +).
- A notarization credential stored once as a keychain profile:
  ```sh
  xcrun notarytool store-credentials CairnNotary \
    --apple-id "you@example.com" --team-id "YOURTEAMID" \
    --password "app-specific-password"   # create at appleid.apple.com
  ```

## 1. Archive and export (Developer ID)

```sh
xcodebuild -project Cairn.xcodeproj -scheme Cairn -configuration Release \
  -archivePath build/Cairn.xcarchive archive

xcodebuild -exportArchive -archivePath build/Cairn.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export
```

`ExportOptions.plist` (not committed — contains your team id):
```xml
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>YOURTEAMID</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
```

## 2. Notarize and staple

```sh
ditto -c -k --keepParent "build/export/Cairn.app" "build/Cairn.zip"
xcrun notarytool submit "build/Cairn.zip" --keychain-profile CairnNotary --wait
xcrun stapler staple "build/export/Cairn.app"
# verify:
spctl -a -vvv --type execute "build/export/Cairn.app"   # should say: source=Notarized Developer ID
```

## 3. Auto-updates with Sparkle (not yet integrated)

Adding Sparkle is a one-time setup requiring a hosting location for the appcast + builds:

1. **Add the package**: Xcode → File → Add Package Dependencies →
   `https://github.com/sparkle-project/Sparkle` (2.x). Add the `Sparkle` product to the Cairn target.
2. **Generate signing keys**: run Sparkle's `generate_keys` tool. Keep the private key in your
   keychain; copy the public key into `Info.plist` as `SUPublicEDKey`.
3. **Info.plist keys**: add `SUFeedURL` (https URL of your `appcast.xml`) and `SUEnableAutomaticChecks = YES`.
4. **Wire the updater**: hold a `SPUStandardUpdaterController` in `CairnApp` and add a
   "Check for Updates…" menu item to the existing **Account**/app menu that calls
   `updater.checkForUpdates(_:)`.
5. **Publish a release**: notarize+staple (steps 1–2), zip the `.app`, sign the zip with Sparkle's
   `sign_update`, and update `appcast.xml` (version, URL, EdDSA signature) on your host.

Until Sparkle is integrated, distribute the notarized `.app`/`.dmg` manually.

## CI note

Signing/notarization are intentionally **not** in `.github/workflows/ci.yml` — they need your
Developer ID cert and notarization secrets. When ready, add a release workflow gated on a tag
that imports the cert from an encrypted secret and runs steps 1–2.
