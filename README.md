# SongBar

A minimal macOS menu bar now-playing app for Spotify.

SongBar puts the current artist and song title in your menu bar. Click it to open a compact native panel with playback controls, album artwork, a progress slider, and quick links to open or share the current track.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-macOS%2014+-blue)
![Swift](https://img.shields.io/badge/Swift-5%2B-orange)

## Features

- Always-visible artist – song title in the menu bar (truncated to 48 chars)
- Native popover panel with album artwork, progress slider, and seek
- Play / pause / next / previous controls
- Open Spotify, open the current track, copy a public share link
- Adaptive polling (1 s while playing, 3 s otherwise) for low CPU use
- No Dock icon, no login, no analytics, no telemetry
- No Spotify Web API — talks to your local Spotify desktop app

## Status

Pre-release (v0.1). The product spec lives in [`docs/SongBar-PRD.md`](docs/SongBar-PRD.md).

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 16 or later (only needed to build from source)
- The Spotify desktop app installed and signed in

SongBar talks to your local Spotify desktop app over Apple Events. It does **not** use the Spotify Web API and does **not** ask you for a Spotify login.

## Building from source

```sh
git clone https://github.com/TthBnc/SongBar.git
cd SongBar
open SongBar.xcodeproj
```

Build and run the `SongBar` scheme. The app installs itself in the menu bar; there is no Dock icon.

To run the unit tests from the command line:

```sh
xcodebuild -scheme SongBar -configuration Debug -destination 'platform=macOS' test
```

## First-run permission

The first time SongBar tries to read or control Spotify, macOS will prompt you to grant **Automation** permission. Allow it.

If you accidentally deny, re-enable it in **System Settings → Privacy & Security → Automation**, find SongBar, and toggle Spotify on.

See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) for details.

## How it works

SongBar uses SwiftUI's `MenuBarExtra(.window)` for the menu bar item and panel, and an `actor`-based `AppleEventsSpotifyClient` that drives the local Spotify app via cached `NSAppleScript` instances. A small `ArtworkLoader` actor caches album art in memory. The view model polls Spotify on an adaptive interval and keeps the panel responsive across track changes, paused state, denied permission, and Spotify-not-running.

Source layout:

```
SongBar/
├── SongBarApp.swift           App + MenuBarExtra
├── Models/                    NowPlaying, PlaybackState, SpotifyAvailability
├── Spotify/                   SpotifyClient protocol + Apple Events impl
├── Artwork/                   ArtworkLoader actor
├── ViewModels/                NowPlayingViewModel (@Observable, @MainActor)
├── Views/                     Panel, controls, slider, banners
├── MenuBar/                   Menu bar title formatter
└── Utilities/                 Time formatter
```

## Contributing

Bug reports, ideas, and PRs welcome. See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

MIT — see [`LICENSE`](LICENSE).

## Trademark

SongBar is an independent open-source project and is not affiliated with, endorsed by, or sponsored by Spotify. Spotify is a trademark of Spotify AB.
