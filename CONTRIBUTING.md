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

See [README.md](README.md#how-it-works) for the source layout. New files require updates to `SongBar.xcodeproj/project.pbxproj` (the file references and the appropriate `PBXSourcesBuildPhase`).

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
