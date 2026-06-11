# Build and Release Guide

This repo has two release paths. Do not mix them up.

## 1. Normal Push: CI Then Auto Release

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

After `CI Build` succeeds on a direct `main` push, `.github/workflows/release.yml`
runs automatically through `workflow_run`.

The release workflow:

- finds the latest GitHub Release tag
- increments the patch version, for example `v0.1.0` -> `v0.1.1`
- writes `CFBundleShortVersionString` and `CFBundleVersion` into
  `Resources/Info.plist` inside the build workspace
- builds `MiniMaxBar.zip`, `MiniMaxBar.dmg`, and `appcast.xml`
- publishes them to GitHub Releases

This means the Releases page, manual downloads, and Sparkle updates are linked
after every successful `main` push.

## 2. Version Tag Or Manual Release

Use this flow when you need an exact version instead of the automatic patch bump:

```bash
git status --short --branch
git tag v0.1.1
git push origin v0.1.1
```

The tag triggers `.github/workflows/release.yml` and publishes that exact
version. You can also run the `Release` workflow manually and provide a version.

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
gh run list --repo Gokady/MiniMaxBar --workflow "Release" --limit 5
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

- A normal push to `main` creates a Release only after `CI Build` succeeds.
- If Releases is empty, check the `CI Build` run first, then the `Release` run.
- If `appcast.xml` is missing, check `SPARKLE_PRIVATE_KEY`.
- If Sparkle says it cannot fetch update info, check that the latest Release
  contains `appcast.xml`.
- If CI says Swift tools version 6.2 is unsupported, `build.sh` is using the
  wrong Swift. It must prefer the setup-swift toolchain on GitHub Actions.
- If the app launches locally but not from a built bundle, check
  `@executable_path/../Frameworks` rpath and embedded `Sparkle.framework`.
- Do not restore repository `.gitignore`. Local ignore rules live in
  `.git/info/exclude`.
