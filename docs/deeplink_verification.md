# Deeplink Verification Setup

This project uses `https://vagina.app/callback` as the mobile OAuth callback and requires verified HTTPS links:

- Android App Links (`assetlinks.json`)
- iOS Universal Links (`apple-app-site-association`)

These files are intentionally not committed in this repository. Deploy them from the website/infrastructure side.

## 1) Android App Links

Publish this file at:

- `https://vagina.app/.well-known/assetlinks.json`

Required content shape:

- `relation` includes `delegate_permission/common.handle_all_urls`
- `target.namespace` is `android_app`
- `target.package_name` matches app package (currently `app.aoki.yuki.vagina`)
- `target.sha256_cert_fingerprints` includes signing certificate fingerprints for each signing key (debug/release as needed)

Verify:

1. `adb shell pm get-app-links app.aoki.yuki.vagina`
2. Open `https://vagina.app/callback?code=test&state=test` on device/browser and confirm app open routing.
3. Confirm no chooser appears once verification is established.

## 2) iOS Universal Links

Publish this file at one of:

- `https://vagina.app/.well-known/apple-app-site-association`
- `https://vagina.app/apple-app-site-association`

Required content shape:

- JSON object with `applinks.details`
- `details[].appIDs` contains `<TeamID>.app.aoki.yuki.vagina`
- `details[].components` (or `paths`) includes `/callback` route

Client settings already expected by this project:

- `Runner.entitlements` contains `applinks:vagina.app`
- Xcode build settings use `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`
- `CFBundleURLTypes` custom scheme callback removed

Verify:

1. Install app on real device (Universal Links are unreliable on Simulator for validation).
2. Open `https://vagina.app/callback?code=test&state=test` from Safari.
3. Confirm app opens directly and callback is received by `app_links`.

## 3) Functional OAuth Check

1. Start OOBE GitHub sign-in.
2. Complete provider login in browser.
3. Confirm return to app via `https://vagina.app/callback`.
4. Confirm OOBE progresses to the next step and session is established.
5. Repeat while app is on a non-OOBE screen (for example Home) and confirm callback is still handled globally.
