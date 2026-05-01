# Contributing to SongBar

Thanks for your interest in SongBar. The project is small on purpose — please read the [PRD](docs/SongBar-PRD.md) before opening a non-trivial PR so we stay aligned on scope.

## Code of conduct

Be kind. Discussion stays focused on the project.

## Reporting bugs

Open a GitHub issue with:

- macOS version (`sw_vers`)
- Spotify desktop app version
- A short description and reproduction steps
- Screenshots if a UI bug

## Sending a pull request

1. Fork the repo and create a branch from `main`.
2. Run the test suite locally:
   ```sh
   xcodebuild -scheme SongBar -configuration Debug -destination 'platform=macOS' test
   ```
   All tests must pass.
3. Match the existing code style (see below).
4. Keep PRs focused. One change per PR is easier to review.
5. Open the PR with a short description of the change and motivation.

## Code style

- Swift 5 mode, macOS 14+ deployment target.
- Prefer SwiftUI primitives; reach for AppKit only when SwiftUI lacks an API.
- Use `@Observable` view models, not `ObservableObject`.
- Mark UI types `@MainActor` where appropriate.
- Keep `SpotifyClient` calls off the main actor — the protocol uses `async` for that reason.
- No file-level docstring blocks. Comments explain *why*, not *what*. Self-documenting names beat comments.
- No Spotify trademarks, logos, or brand colors anywhere in the app or icons.

## Project structure

```
SongBar/
├── SongBarApp.swift           App + MenuBarExtra
├── Models/                    NowPlaying, PlaybackState, SpotifyAvailability
├── Spotify/                   SpotifyClient protocol + Apple Events impl
├── Artwork/                   ArtworkLoader actor + NSImage helpers
├── ViewModels/                NowPlayingViewModel (@Observable, @MainActor)
├── Views/                     Panel, controls, slider, banners
├── MenuBar/                   Menu bar title formatter
└── Utilities/                 Time formatter
```

New files require updates to `SongBar.xcodeproj/project.pbxproj` (the file references and the appropriate `PBXSourcesBuildPhase`).

## Packaging a dmg

To produce a distributable `.dmg`:

```sh
./scripts/build-dmg.sh
# → dist/SongBar-<version>.dmg
```

By default the script ad-hoc signs the app. The dmg installs locally but Gatekeeper warns the first time a user opens it. Right-click the app and choose **Open** to bypass that warning once.

### Signing with a Developer ID

When the project has access to an Apple "Developer ID Application" certificate, set:

```sh
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAM12345)"
./scripts/build-dmg.sh
```

The script enables hardened runtime, signs the app and the dmg with a secure timestamp, and the result opens without a Gatekeeper warning.

### Notarization

To also notarize and staple, store credentials once with `xcrun notarytool` and pass the keychain profile name:

```sh
xcrun notarytool store-credentials "AC_PROFILE" \
    --apple-id "you@example.com" \
    --team-id "TEAM12345" \
    --password "<app-specific password>"

export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAM12345)"
export NOTARY_PROFILE="AC_PROFILE"
./scripts/build-dmg.sh
```

The script submits the dmg, waits for the Apple notary service, and staples the ticket.

### Cutting a release

1. Bump `MARKETING_VERSION` in `SongBar.xcodeproj/project.pbxproj` (currently `0.1.0`).
2. Run `./scripts/build-dmg.sh` (with signing/notarization env vars if available).
3. Tag and push: `git tag v0.1.0 && git push --tags`.
4. Upload via `gh release create v0.1.0 dist/SongBar-0.1.0.dmg --notes "..."`.

## Areas welcome to contributions

- Accessibility audit (VoiceOver labels, keyboard navigation, contrast).
- Light/dark mode polish.
- Manual test pass against edge cases listed in the PRD §29.
- Localization scaffolding.
- App icon design (must avoid Spotify's visual identity — see PRD §25).

## Areas explicitly out of scope for v1

See PRD §7 "Non-Goals For Version 1". TL;DR: no Web API, no login, no Connect device control, no playlists/search/lyrics/queue, no telemetry.

## License

By contributing, you agree your contributions are licensed under the MIT license, the same as the project.
