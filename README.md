# SongBar

A minimal macOS menu bar now-playing app for Spotify.

SongBar puts the current artist and song title in your menu bar. Click it for a compact panel with album art, a progress slider, playback controls, and quick actions to open or share the current track.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-macOS%2014+-blue)

<p align="center">
  <img src="docs/screenshots/panel.png" alt="SongBar in the menu bar with its panel open" width="372">
</p>

## Features

- Album art + artist – song title visible in your menu bar
- Animated equalizer indicator while music plays
- Native popover panel: artwork, progress slider, prev / play / next, share actions
- Adaptive polling — 1 s while playing, 3 s otherwise — so it stays light on battery
- No Dock icon, no login, no analytics, no telemetry
- Talks only to the **local** Spotify desktop app via Apple Events. Your Spotify credentials never leave Spotify.

## Install

1. Download the latest `SongBar-x.y.z.dmg` from the [Releases](https://github.com/TthBnc/SongBar/releases) page.
2. Open the dmg and drag **SongBar** into your **Applications** folder.
3. Open Applications, **right-click SongBar** and choose **Open**. macOS will warn that the developer can't be verified — that's expected for an unsigned open-source app. Click **Open** to confirm.
4. Look for SongBar in your menu bar — top-right of the screen, near the clock.

> Right-click → Open is only needed once. After that you can launch it normally. This is unsigned because we don't yet have an Apple Developer ID; once we do, the warning will go away.

## First-run permission

The first time SongBar tries to read or control Spotify, macOS will prompt you to grant **Automation** permission so SongBar can talk to the Spotify app. Click **Allow**.

If you accidentally deny, re-enable it in **System Settings → Privacy & Security → Automation**, find SongBar in the list, and toggle Spotify on.

See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) if anything goes sideways.

## Requirements

- macOS 14 (Sonoma) or later
- The [Spotify desktop app](https://www.spotify.com/download) installed and signed in

SongBar does not work with the web player or Spotify Connect playback on a remote device — it reads the local desktop app.

## Privacy

- SongBar **doesn't** ask for your Spotify password. It never sees one.
- SongBar **doesn't** send your listening history anywhere. There is no server, no analytics, no telemetry.
- Album artwork is downloaded directly from Spotify's CDN to render the panel — that's the only network traffic the app makes.

## Build from source

```sh
git clone https://github.com/TthBnc/SongBar.git
cd SongBar
open SongBar.xcodeproj
```

Build and run the `SongBar` scheme in Xcode 16 or later.

To run unit tests from the command line:

```sh
xcodebuild -scheme SongBar -configuration Debug -destination 'platform=macOS' test
```

For details on packaging a `.dmg` (signed or unsigned), see [`CONTRIBUTING.md`](CONTRIBUTING.md#packaging-a-dmg).

## Contributing

Bug reports, ideas, and PRs welcome. See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

MIT — see [`LICENSE`](LICENSE).

## Trademark

SongBar is an independent open-source project and is not affiliated with, endorsed by, or sponsored by Spotify. Spotify is a trademark of Spotify AB.
