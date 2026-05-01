# SongBar Troubleshooting

## "SongBar does not have permission to control Spotify."

SongBar talks to the local Spotify desktop app over **Automation** (Apple Events). macOS asks for your consent the first time. If you denied, or want to verify the setting:

1. Open **System Settings**.
2. Go to **Privacy & Security → Automation**.
3. Find **SongBar** in the list.
4. Toggle **Spotify** on.

You may need to quit and relaunch SongBar after granting the permission.

If SongBar isn't in the Automation list, click the menu bar icon, attempt any playback action (play/pause, next, etc.), and macOS will trigger the consent prompt — accepting will add SongBar to the list.

## "Spotify is not installed."

Install the Spotify desktop app from <https://www.spotify.com/download>. SongBar does not work with the web player or Spotify Connect devices alone in v1.

## "Spotify is not open."

Launch Spotify (Cmd-Space → "Spotify"), or click **Open Spotify** in the SongBar panel.

## "Nothing is playing."

Spotify is running and reachable but no track is loaded. Pick a track or playlist in Spotify; the SongBar panel updates within a couple of seconds.

## The menu bar text isn't updating

- Confirm the Spotify desktop app is the one playing — SongBar reads only the local app, not the web player or Spotify Connect playback on another device.
- Confirm Automation permission is on (see above).
- Quit and relaunch SongBar.

## The artwork is missing

SongBar pulls artwork from the URL Spotify exposes. A small fraction of tracks (especially local files imported into Spotify) don't have a public artwork URL — SongBar shows a neutral placeholder in that case. This is not a bug.

## The Copy Link / Open Track buttons are disabled

This happens when the current track is a local file (no public Spotify URL). The other controls (play/pause, next, previous, slider, Open Spotify) still work normally.

## Where can I see logs?

SongBar logs to the unified system log under the subsystem `dev.tothbnc.SongBar`. Useful filters:

```sh
log stream --predicate 'subsystem == "dev.tothbnc.SongBar"' --info --debug
```

Most error logs are at `.debug` to avoid noise — pass `--debug` to see them.

## Reset everything

If SongBar gets into a weird state:

1. Quit SongBar from its panel.
2. Optional: revoke Automation permission (System Settings → Privacy & Security → Automation → SongBar → toggle off).
3. Relaunch SongBar. It will re-prompt for Automation when needed.

## Still stuck?

Open an issue at <https://github.com/TthBnc/SongBar/issues> with macOS version, Spotify version, and what you observed.
