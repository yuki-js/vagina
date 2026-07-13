# Windows distribution

VAGINA remains a Flutter Win32 desktop application. MSIX supplies package identity, installation, protocol activation, signing, and Microsoft Store distribution; it does not convert the application to UWP.

## Artifacts

The Windows workflow produces these independent artifacts:

- `windows-release-build`: the unpackaged ZIP. It remains useful for development and portable execution.
- `windows-store-msix`: an unsigned Store-mode MSIX for Partner Center submission.
- `windows-sideload-msix`: an MSIX signed by the configured publisher certificate for direct installation and packaged-runtime testing.

The release build is performed once. Both MSIX variants package the same complete Flutter output, including the executable, Flutter runtime, plug-in libraries, native assets, and `data` directory.

## Canonical icon artwork

Windows and MSIX use the same canonical purple application artwork at `assets/icons/ios/iTunesArtwork@3x.png`. The 1536×1536 PNG is the direct `msix_config.logo_path`, allowing the MSIX tool to generate its required tile, Store, target-size, splash, and badge resources without an intermediate duplicate.

The unpackaged executable icon at `windows/runner/resources/app_icon.ico` is generated from that same PNG:

```console
python3 scripts/generate_windows_icon.py
```

The generator uses standard Windows sizes from 16×16 through 256×256 and embeds PNG-compressed 32-bit entries. Do not edit the ICO directly or introduce a separate Windows/Store logo source.

## Committed package identity

Microsoft Store package identity is public metadata and is committed in `pubspec.yaml`:

| Field | Value |
| --- | --- |
| Package/Identity/Name | `app.aoki.yuki.vagina` |
| Package/Identity/Publisher | `CN=AokiApp Inc.` |
| Package/Properties/PublisherDisplayName | `AokiApp Inc.` |

These values are the canonical inputs for Store and sideload packages. They must match the product identity in Partner Center. Do not duplicate them in GitHub variables or secrets.

## Sideload signing secrets

Configure both GitHub Actions secrets to enable the signed sideload artifact:

| Secret | Content |
| --- | --- |
| `WINDOWS_CERT_PFX` | Base64 encoding of the complete PFX bytes |
| `WINDOWS_CERT_PASSWORD` | PFX password |

Encode a certificate without adding line breaks:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("publisher.pfx"))
```

The PFX must contain a private key. Its X.500 subject must exactly match the committed Publisher `CN=AokiApp Inc.`; the packaging script rejects a mismatch before creating the package. Direct installers must trust the signing certificate chain on the target machine.

Store MSIX files are intentionally unsigned. Partner Center applies Store signing after ingestion. Do not upload the sideload package in place of the Store package.

## CI trigger and trust boundary

Normal Windows preprocessing, tests, debug build, release build, and ZIP artifact creation run for pull requests and pushes.

Store MSIX packaging runs when the event is either:

- a push; or
- a pull request whose head repository is this repository.

Fork pull requests cannot access the signing secrets and skip MSIX packaging. This does not weaken ordinary Windows build coverage.

## OAuth protocol ownership

Both MSIX manifests declare the custom protocol `app.aoki.yuki.vagina`. Windows package registration is the only protocol-registration authority for packaged execution.

At startup, Windows native code queries the process package identity through `GetCurrentPackageFamilyName`. Dart asks for that result over the existing platform channel before OAuth setup:

- packaged process: skip registry access completely;
- unpackaged ZIP/development process: register the protocol under `HKCU\\Software\\Classes` for compatibility.

Do not replace this package-identity check with executable-path heuristics or a compile-time flag. The same release executable is used in packaged and unpackaged forms.

## Versioning

`pubspec.yaml` remains the source version in `major.minor.patch+build` form. The packaging script emits `major.minor.patch.0` because the fourth package-version component is reserved for Microsoft Store use. Each of the first three components must fit the MSIX range `0..65535`, and the major component must be nonzero for Store submission.

Increment the application version before publishing an update. Partner Center rejects a package version that does not advance appropriately.

## Local Windows packaging

Requirements:

- Flutter and Dart matching the project;
- Visual Studio Windows desktop toolchain;
- Windows SDK containing MakeAppx and SignTool;
- the committed package identity matching Partner Center;
- a publisher PFX only for sideload mode.

Build the payload first:

```powershell
flutter pub get
bash scripts/prebuild.sh
flutter build windows --release
```

Create and validate the unsigned Store package:

```powershell
.\scripts\package_windows_msix.ps1 -Mode Store
```

Create and validate a signed sideload package:

```powershell
.\scripts\package_windows_msix.ps1 `
  -Mode Sideload `
  -CertificatePath "C:\secure\publisher.pfx" `
  -CertificatePassword "PFX_PASSWORD"
```

Outputs are written below `build\\windows\\msix\\store` and `build\\windows\\msix\\sideload`.

## Validation gates

The packaging script fails when:

- an identity value is blank;
- the project version cannot become a four-component MSIX version;
- the PFX is missing, lacks a private key, or has a different publisher subject;
- the MSIX is not created;
- manifest identity, publisher, or version differs from the requested values;
- the OAuth protocol declaration is absent;
- the executable, Flutter runtime, or Flutter assets are absent;
- a Store package is unexpectedly signed; or
- a sideload package has no embedded signature.

Before submitting, install the sideload package on Windows and validate launch, microphone access, OAuth cold start, OAuth callback while already running, local storage, update, and uninstall. The Store package itself should then be uploaded to Partner Center for certification.
