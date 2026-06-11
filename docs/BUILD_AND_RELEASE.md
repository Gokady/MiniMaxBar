# Build and Release Guide

This repo has two separate automation paths. Do not mix them up.

## 1. Normal Push: CI Build Only

Every push to `main` runs `.github/workflows/build.yml`.

It verifies:

- SwiftPM release build
- SwiftPM debug build
- `./build.sh release`
- `.app` bundle structure
- embedded `Sparkle.framework`
- `@executable_path/../Frameworks` rpath
- ad-hoc code signature validity

It uploads an Actions artifact named like:

```text
MiniMaxBar-app-<commit-sha>
```

This artifact is only for CI inspection. It is not a GitHub Release and does
not appear on the Releases page.

## 2. Version Tag: Public Release

Only a `v*` tag creates a GitHub Release.

Use this flow for a public build:

```bash
git status --short --branch
git tag v0.1.1
git push origin v0.1.1
```

The tag triggers `.github/workflows/release.yml`.

It creates:

```text
MiniMaxBar.zip
MiniMaxBar.dmg
appcast.xml
```

`MiniMaxBar.zip` is used by Sparkle. `MiniMaxBar.dmg` is for manual install.
`appcast.xml` is the Sparkle feed.

## 3. Sparkle Key Setup

Sparkle requires the public key in `Resources/Info.plist` and the matching
private key in GitHub Actions Secret `SPARKLE_PRIVATE_KEY`.

Current public key:

```text
p3lDlci7WlYjX6JlA4C/JeOr8jZtjUVgjyIsJSOgyeI=
```

To recreate or verify the local key:

```bash
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account Goka-MiniMaxBar -p
```

To set the GitHub Secret from this Mac:

```bash
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account Goka-MiniMaxBar -x /tmp/minimaxbar_sparkle_private_key.txt
gh secret set SPARKLE_PRIVATE_KEY --repo Gokady/MiniMaxBar < /tmp/minimaxbar_sparkle_private_key.txt
rm /tmp/minimaxbar_sparkle_private_key.txt
```

Never commit the private key. Keep it only in Keychain and GitHub Secrets.

## 4. Local Build

Use `build.sh`, not `swift build` alone, when testing the app bundle:

```bash
./build.sh release
open dist/MiniMaxBar.app
```

`swift build` only produces the raw binary. It does not assemble
`MiniMaxBar.app`, copy resources, embed Sparkle, add rpath, or sign the bundle.

`build.sh` chooses a Swift toolchain that satisfies `Package.swift`
`swift-tools-version: 6.2`. On CI, this must be the Swift installed by
`swift-actions/setup-swift`; using the runner's Xcode Swift may be too old.

## 5. Release Verification

After pushing a tag, watch the release workflow:

```bash
gh run list --repo Gokady/MiniMaxBar --workflow "Manual Release" --limit 5
gh run watch <run-id> --repo Gokady/MiniMaxBar --exit-status
```

Verify the published assets:

```bash
gh release view v0.1.1 --repo Gokady/MiniMaxBar --json tagName,name,assets,url
curl -I -L https://github.com/Gokady/MiniMaxBar/releases/latest/download/appcast.xml
```

Expected assets:

```text
MiniMaxBar.zip
MiniMaxBar.dmg
appcast.xml
```

## 6. Common Pitfalls

- A normal push to `main` will not create a Release. Push a `v*` tag.
- If Releases is empty, check whether a version tag exists on origin.
- If `appcast.xml` is missing, check `SPARKLE_PRIVATE_KEY`.
- If Sparkle says it cannot fetch update info, check that the latest Release
  contains `appcast.xml`.
- If CI says Swift tools version 6.2 is unsupported, `build.sh` is using the
  wrong Swift. It must prefer the setup-swift toolchain on GitHub Actions.
- If the app launches locally but not from a built bundle, check
  `@executable_path/../Frameworks` rpath and embedded `Sparkle.framework`.
- Do not restore repository `.gitignore`. Local ignore rules live in
  `.git/info/exclude`.
