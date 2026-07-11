# OAuth callback routing

The public OAuth provider callback is always `https://vagina.app/callback`.
The server keeps the existing `web`, `mobile`, and `desktop` redirect URI
configuration keys. Within each environment all three values point to that
environment's shared HTTPS callback bridge.

OAuth state is an opaque random value with a client-type routing prefix:

```text
w.<random>  # Web
m.<random>  # Mobile
d.<random>  # Desktop
```

The prefix is an unauthenticated routing hint. The static callback page reads
only that prefix:

- `w.` starts Flutter Web and lets the Web client exchange the callback.
- `m.` and `d.` forward the allow-listed OAuth query parameters to
  `app.aoki.yuki.vagina://oauth/callback`.
- Missing, unknown, or empty prefixes fail without starting Flutter or opening
  a native URI.

The API remains authoritative. It hashes and looks up the complete state,
checks that the prefix matches the stored client type, and then applies the
existing provider, expiry, one-time-consumption, and PKCE checks.

Native platform registration:

- Android registers the custom scheme intent filter in `AndroidManifest.xml`.
- iOS registers the custom scheme in `Info.plist`.
- Windows registers the protocol for the current user when the app starts and
  forwards warm activations to the existing app process.
- Future native runners must use the same callback URI.

OAuth callback routing does not use Android App Links, iOS Universal Links,
`assetlinks.json`, AASA, or associated-domain entitlements.
