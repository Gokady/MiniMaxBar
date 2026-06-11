# Build and Release Guide

This document is the handoff guide for agents working on MiniMaxBar releases.
Do not guess from the Releases page alone; verify the workflow run, release
assets, and Sparkle appcast.

## Current Pipeline

There are two workflows:

```text
.github/workflows/build.yml    -> CI Build
.github/workflows/release.yml  -> Release
```

The normal automated path is:

```text
push to main
  -> CI Build
  -> Release through workflow_run after CI success
  -> GitHub Release with MiniMaxBar.zip, MiniMaxBar.dmg, appcast.xml
  -> Sparkle reads releases/latest/download/appcast.xml
```

`CI Build` proves the app can build. `Release` publishes durable assets on the
GitHub Releases page. Do not confuse short-lived Actions artifacts with Release
assets.

## Agent Quick Start

Run these before changing release automation:

```bash
git status --short --branch
gh workflow list --repo Gokady/MiniMaxBar
gh run list --repo Gokady/MiniMaxBar --limit 10 \
  --json databaseId,workflowName,status,conclusion,event,headSha,url,createdAt
gh release view --repo Gokady/MiniMaxBar --json tagName,name,url,assets,publishedAt
curl -sL https://github.com/Gokady/MiniMaxBar/releases/latest/download/appcast.xml | sed -n '1,40p'
```

Optional local skill helper:

```bash
/Users/wuke/.codex/skills/github-release-automation/scripts/gh-release-audit.sh Gokady/MiniMaxBar
```

Use the `github-release-automation` Codex skill for future Actions/Releases work.
It is installed at:

```text
/Users/wuke/.codex/skills/github-release-automation
```

## Workflow Triggers

### CI Build

File:

```text
.github/workflows/build.yml
```

Triggers:

- manual `workflow_dispatch`
- push to `main`
- pull request targeting `main`

What it verifies:

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

That artifact is only for build inspection. It is not a GitHub Release asset
and will not be used by Sparkle.

Manual run:

```bash
gh workflow run "CI Build" --repo Gokady/MiniMaxBar --ref main
gh run list --repo Gokady/MiniMaxBar --workflow "CI Build" --limit 5
gh run watch <run-id> --repo Gokady/MiniMaxBar --exit-status
```

### Release

File:

```text
.github/workflows/release.yml
```

Triggers:

- automatic `workflow_run` after successful `CI Build` on direct `main` push
- push of `v*` tag
- manual `workflow_dispatch` with a version

What it creates:

```text
MiniMaxBar.zip
MiniMaxBar.dmg
appcast.xml
```

`MiniMaxBar.zip` is used by Sparkle. `MiniMaxBar.dmg` is for manual install.
`appcast.xml` is the Sparkle feed.

Manual run:

```bash
gh workflow run "Release" --repo Gokady/MiniMaxBar --ref main \
  -f version=0.1.3 \
  -f release_notes="Manual release"
gh run list --repo Gokady/MiniMaxBar --workflow "Release" --limit 5
gh run watch <run-id> --repo Gokady/MiniMaxBar --exit-status
```

Tag release:

```bash
git status --short --branch
git tag v0.1.3
git push origin v0.1.3
```

Automatic push release:

```bash
git status --short --branch
git push origin main
```

Then watch:

```bash
gh run list --repo Gokady/MiniMaxBar --branch main --limit 10
```

The `Release` workflow finds the latest GitHub Release tag and increments the
patch version. Example:

```text
v0.1.1 -> v0.1.2
```

It also checks for existing release/tag collisions before publishing.

## Version Sources

During release builds, `.github/workflows/release.yml` writes the version into
`Resources/Info.plist` inside the workflow workspace:

```text
CFBundleShortVersionString = X.Y.Z
CFBundleVersion = git rev-list --count HEAD
MARKETING_VERSION = X.Y.Z
```

For local builds, `build.sh` copies the checked-in `Resources/Info.plist` into
`dist/MiniMaxBar.app`.

Current public release at the time this guide was updated:

```text
v0.1.2
```

## Sparkle Key Setup

Sparkle requires:

- public key in `Resources/Info.plist`
- matching private key in GitHub Actions Secret `SPARKLE_PRIVATE_KEY`

Current public key:

```text
p3lDlci7WlYjX6JlA4C/JeOr8jZtjUVgjyIsJSOgyeI=
```

Verify local key:

```bash
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account Goka-MiniMaxBar -p
```

Set GitHub Secret from this Mac:

```bash
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account Goka-MiniMaxBar -x /tmp/minimaxbar_sparkle_private_key.txt
gh secret set SPARKLE_PRIVATE_KEY --repo Gokady/MiniMaxBar < /tmp/minimaxbar_sparkle_private_key.txt
rm /tmp/minimaxbar_sparkle_private_key.txt
```

Never commit the private key. `sparkle:edSignature` in appcast.xml is a public
signature for the archive, not the private key.

## Sparkle Appcast Verification

The app should use the stable latest feed:

```text
https://github.com/Gokady/MiniMaxBar/releases/latest/download/appcast.xml
```

Verify latest appcast:

```bash
curl -I -L https://github.com/Gokady/MiniMaxBar/releases/latest/download/appcast.xml
curl -sL https://github.com/Gokady/MiniMaxBar/releases/latest/download/appcast.xml | sed -n '1,40p'
```

The enclosure URL must include the concrete release tag:

```text
https://github.com/Gokady/MiniMaxBar/releases/download/v0.1.2/MiniMaxBar.zip
```

If it shows this broken shape, fix `--download-url-prefix`:

```text
https://github.com/Gokady/MiniMaxBar/releases/download/MiniMaxBar.zip
```

The correct prefix includes the trailing slash:

```bash
DOWNLOAD_URL="https://github.com/Gokady/MiniMaxBar/releases/download/v${VERSION}/"
```

## Local Build

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

## Release Verification Checklist

After any release, run:

```bash
gh release view --repo Gokady/MiniMaxBar --json tagName,name,url,assets,publishedAt,isDraft,isPrerelease
curl -sL https://github.com/Gokady/MiniMaxBar/releases/latest/download/appcast.xml | sed -n '1,40p'
```

Expected release assets:

```text
MiniMaxBar.zip
MiniMaxBar.dmg
appcast.xml
```

Expected workflow sequence for a normal push:

```text
CI Build: success
Release: success, event=workflow_run
GitHub Release: new latest version
appcast.xml: enclosure points to the same version's MiniMaxBar.zip
```

## Common Pitfalls

- Releases page empty: check `CI Build` first, then `Release`.
- CI succeeded but no Release: check `workflow_run` filters and `permissions: contents: write`.
- Release exists but no zip/dmg/appcast: inspect the release creation step and asset path list.
- `appcast.xml` missing: check `SPARKLE_PRIVATE_KEY`.
- Sparkle cannot fetch update info: check latest Release has `appcast.xml` and the app's feed URL uses `releases/latest/download/appcast.xml`.
- Sparkle downloads fail: inspect `enclosure url`; it must include `/releases/download/vX.Y.Z/MiniMaxBar.zip`.
- Swift tools version unsupported: ensure setup-swift is active and `build.sh` prefers the PATH Swift on GitHub Actions.
- App launches locally but not from bundle: check embedded `Sparkle.framework`, rpath, and code signing.
- Do not restore repository `.gitignore`. Local ignore rules live in `.git/info/exclude`.
