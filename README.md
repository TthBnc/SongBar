# SongBar

A minimal macOS menu bar now-playing app for Spotify.

SongBar puts the current artist and song title in your menu bar, and opens a compact native panel with playback controls, album artwork, a progress slider, and quick links to open or share the current track.

## Status

Early development. See [`docs/SongBar-PRD.md`](docs/SongBar-PRD.md) for the full product specification.

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

Build and run the `SongBar` scheme.

## First-run permission

The first time SongBar tries to read or control Spotify, macOS will prompt you to grant Automation permission. Allow it.

If you accidentally deny, re-enable it in **System Settings → Privacy & Security → Automation**, find SongBar, and toggle Spotify on.

See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) for more.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

MIT — see [`LICENSE`](LICENSE).

## Trademark

SongBar is an independent open-source project and is not affiliated with, endorsed by, or sponsored by Spotify. Spotify is a trademark of Spotify AB.
