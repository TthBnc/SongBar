# SongBar Product Requirements Document

## 1. Product Summary

SongBar is a minimal macOS menu bar application that shows the currently playing Spotify track directly in the system menu bar.

The menu bar item displays the current artist and song title as text. When the user clicks the menu bar item, SongBar opens a native macOS popover panel with playback controls, album artwork, track progress, an "Open in Spotify" action, a share/copy URL action, and a Quit button.

SongBar is intended to be open source, lightweight, privacy-conscious, and useful primarily for people who already use the Spotify desktop app on macOS.

## 2. Product Name

The product name is **SongBar**.

The app must not use "Spotify" in the product name, bundle display name, app icon, repository name, or primary branding.

The app may describe itself as supporting Spotify in the README, documentation, and app copy where necessary.

Recommended short description:

> SongBar is a minimal macOS menu bar now-playing app for Spotify.

## 3. Target Platform

SongBar is a native macOS application.

The first version targets macOS only.

The first version is built in Swift.

The first version is distributed outside the Mac App Store unless App Store compatibility is explicitly evaluated later.

The first version assumes the user has the Spotify desktop app installed on macOS.

The first version does not support Windows, Linux, iOS, iPadOS, Android, web browsers, or Spotify Connect devices independently of the local Spotify app.

## 4. Primary User

The primary user is a macOS Spotify user who wants to see the currently playing artist and song title without switching to Spotify.

The primary user keeps many windows open and wants a persistent, low-friction now-playing display in the menu bar.

The primary user values a small utility app over a full music dashboard.

The primary user is comfortable granting macOS permission for SongBar to control Spotify.

## 5. Core Problem

Spotify does not provide a built-in macOS menu bar text item that continuously displays the currently playing artist and song title.

Users who want to glance at the current track must switch to Spotify, open a notification, use media controls, or use a third-party app.

SongBar solves this by placing the current artist and song title in the macOS menu bar and exposing common playback actions in one click.

## 6. Product Goals

SongBar must show the currently playing artist and song title in the macOS menu bar.

SongBar must open a native macOS panel when the menu bar item is clicked.

SongBar must show album artwork in the panel when artwork is available.

SongBar must show play/pause state.

SongBar must provide play/pause control.

SongBar must provide previous track and next track controls.

SongBar must show current playback progress.

SongBar must provide a progress slider that shows where the user is in the current song.

SongBar must allow the user to seek within the current song by interacting with the progress slider.

SongBar must provide a button to open Spotify quickly.

SongBar must provide a button to open the currently playing song in Spotify when a current song URL is available.

SongBar must provide a share/copy URL action for the currently playing song when a current song URL is available.

SongBar must provide a Quit button at the bottom of the panel.

SongBar must run without showing a Dock icon.

SongBar must be lightweight enough to run continuously in the background.

SongBar must be open-source friendly, with no private service dependency required for the first version.

## 7. Non-Goals For Version 1

SongBar will not implement Spotify OAuth login in version 1.

SongBar will not use the Spotify Web API in version 1 unless Apple Events prove insufficient during implementation.

SongBar will not control remote Spotify Connect devices independently of the local Spotify app in version 1.

SongBar will not include playlist browsing in version 1.

SongBar will not include search in version 1.

SongBar will not include lyrics in version 1.

SongBar will not include queue management in version 1.

SongBar will not include volume control in version 1 unless it falls out naturally from the local Spotify scripting interface and does not expand scope.

SongBar will not include account management in version 1.

SongBar will not include analytics or telemetry in version 1.

SongBar will not include auto-update infrastructure in version 1 unless packaging work explicitly adds it later.

SongBar will not include support for Apple Music in version 1.

SongBar will not use Spotify trademarks, colors, logos, or visual identity as app branding.

## 8. Integration Strategy

Version 1 should integrate with the locally installed Spotify macOS application using Apple Events.

The user will not log in to SongBar directly.

The user must be logged in to the Spotify desktop app.

SongBar will ask macOS for permission to control Spotify through the standard Automation permission prompt.

SongBar must include `NSAppleEventsUsageDescription` in its app information property list.

If the app uses Hardened Runtime, SongBar must include the Apple Events automation entitlement.

If the app is sandboxed, SongBar must verify whether additional Apple Events entitlements or temporary exceptions are required for reliable Spotify control.

The first implementation should prefer Apple Events or Scripting Bridge over Spotify OAuth because the required data is exposed by the local Spotify app.

## 9. Spotify Desktop Data Requirements

SongBar must attempt to read the following values from the local Spotify app:

- Current track name
- Current track artist
- Current track album name, if available
- Current player state
- Current player position in seconds
- Current track duration in seconds
- Current track artwork URL
- Current track Spotify URL or URI

SongBar must tolerate missing data.

SongBar must not crash if Spotify is not installed.

SongBar must not crash if Spotify is installed but not running.

SongBar must not crash if Spotify is running but no song is playing.

SongBar must not crash if Spotify returns a track with missing artwork.

SongBar must not crash if Spotify returns a local file without a public Spotify URL.

SongBar must not crash if Spotify automation permission is denied.

## 10. Menu Bar Behavior

SongBar must create one persistent system menu bar item.

The menu bar item must display text.

The default menu bar text format is:

`Artist - Song Title`

If the player is paused, SongBar should still display the last known current track.

If the player is paused, SongBar should visually indicate paused state in a compact way.

The preferred paused format is:

`Paused: Artist - Song Title`

If no track is available, the menu bar item should display:

`SongBar`

If Spotify is not running, the menu bar item should display:

`SongBar`

If Spotify is installed but closed, clicking the menu bar item should still open the panel and offer an "Open Spotify" action.

If the artist and song title are too long, SongBar must truncate the menu bar title rather than consuming excessive menu bar space.

The default maximum menu bar title length should be configurable in code.

The recommended default maximum visible title is 48 characters.

SongBar must update the menu bar title when the current track changes.

SongBar must update the menu bar title when playback changes between playing and paused.

SongBar should not animate the menu bar text.

SongBar should not show album artwork in the menu bar in version 1.

SongBar should not use Spotify's logo in the menu bar.

## 11. Panel Behavior

Clicking the menu bar item must open a native macOS popover-style panel.

Clicking outside the panel should dismiss the panel.

Clicking the menu bar item while the panel is open should close the panel.

The panel must be compact enough to feel like a menu bar utility.

The panel must not look like a full Spotify clone.

The panel must show the current song title.

The panel must show the current artist.

The panel should show the current album name when available.

The panel must show album artwork when an artwork URL is available.

The panel must show a placeholder artwork area when artwork is unavailable.

The panel must show play/pause, previous, and next controls.

The panel must show current playback time.

The panel must show total track duration.

The panel must show a slider representing current playback progress.

The panel must allow seeking by moving the slider.

The panel must include an "Open Spotify" action.

The panel must include an "Open Track" action when a current track URL is available.

The panel must include a "Copy Link" or "Share" action when a shareable URL is available.

The panel must include a Quit button at the bottom.

The Quit button must terminate SongBar, not Spotify.

The panel must remain usable when Spotify is not running.

The panel must remain usable when Spotify automation permission is denied.

## 12. Panel Layout Requirements

The panel should use a single-column layout for version 1.

The recommended panel width is 300-340 points.

The recommended panel content padding is 14-18 points.

Album artwork should appear near the top of the panel.

Album artwork should be square.

Album artwork should have a recommended size between 96 and 160 points.

The song title should appear below or beside the artwork depending on final UI implementation.

The artist name should appear directly near the song title.

Playback controls should appear below the track metadata.

The progress slider should appear below the playback controls or between metadata and controls.

Open/copy actions should appear below the playback area.

The Quit button must be visually separated from playback controls and placed at the bottom.

The UI should use native macOS controls where practical.

The UI should support light mode and dark mode.

The UI should be legible on Retina displays.

The UI should not use Spotify's green color as the primary brand color.

The UI should not use Spotify's logo or icon.

## 13. Playback Controls

SongBar must provide a play/pause button.

The play/pause button must reflect the current playback state.

When Spotify is playing, the button must perform pause or play/pause.

When Spotify is paused, the button must perform play or play/pause.

SongBar must provide a next track button.

SongBar must provide a previous track button.

SongBar must disable or gracefully no-op playback controls when Spotify is not running.

SongBar must disable or gracefully no-op playback controls when automation permission is unavailable.

SongBar must update the displayed state after a playback command is issued.

SongBar should optimistically refresh playback state immediately after issuing a playback command.

SongBar must not queue multiple duplicate commands if the user clicks rapidly.

## 14. Progress Slider And Seeking

SongBar must display the current playback position.

SongBar must display the current track duration.

SongBar must update playback position while the track is playing.

The progress slider must reflect the current playback position as a percentage of total duration.

The slider must be disabled if duration is unavailable or zero.

The slider must be disabled if Spotify is not running.

The slider must be disabled if automation permission is unavailable.

When the user drags the slider, SongBar should pause automatic slider updates until the drag ends.

When the user releases the slider, SongBar must send a seek command to Spotify.

The seek command must use seconds for the local Spotify Apple Events implementation.

SongBar must clamp seek positions between 0 and the current track duration.

## 15. Artwork Requirements

SongBar must show artwork in the panel when Spotify provides an artwork URL.

SongBar must download artwork from the artwork URL for display.

SongBar must cache artwork in memory for the currently playing track.

SongBar may use a small disk cache later, but disk caching is not required in version 1.

SongBar must clear or replace artwork when the track changes.

SongBar must show a neutral placeholder when artwork is unavailable or fails to load.

SongBar must not crop artwork in a way that changes its meaning.

SongBar must not overlay the app logo on Spotify artwork.

SongBar must not modify Spotify artwork beyond resizing it for display.

SongBar must provide a link back to Spotify for the current track when a URL is available.

## 16. Open And Share Requirements

SongBar must provide an action to open the Spotify application.

If Spotify is closed, the "Open Spotify" action must launch Spotify.

If Spotify is already open, the "Open Spotify" action should activate Spotify.

SongBar must provide an action to open the current track in Spotify when a track URL or URI is available.

SongBar must convert Spotify track URIs into public Spotify URLs for sharing when possible.

Example conversion:

`spotify:track:TRACK_ID` becomes `https://open.spotify.com/track/TRACK_ID`

SongBar must copy the share URL to the clipboard when the user chooses the copy/share URL action.

SongBar should provide brief UI feedback after copying a URL.

SongBar must disable the current-track open/share actions when no current-track URL is available.

## 17. Permissions And Privacy

SongBar must not require the user to enter Spotify credentials.

SongBar must not collect analytics in version 1.

SongBar must not send now-playing data to any server owned by the SongBar project.

SongBar must not store track history in version 1.

SongBar must not persist listened tracks in version 1.

SongBar may temporarily keep the current track metadata in memory to render the UI.

SongBar may download album artwork from Spotify-provided artwork URLs.

SongBar must explain why it requests Automation permission.

Recommended `NSAppleEventsUsageDescription`:

`SongBar needs permission to read the current track and control playback in Spotify.`

SongBar must provide a clear error state if the user denies Automation permission.

The error state should tell the user that permission can be changed in macOS System Settings under Privacy & Security > Automation.

## 18. Error States

SongBar must handle Spotify not installed.

Recommended message:

`Spotify is not installed.`

SongBar must handle Spotify installed but not running.

Recommended message:

`Spotify is not open.`

SongBar must handle Spotify running with no active track.

Recommended message:

`Nothing is playing.`

SongBar must handle Automation permission denied.

Recommended message:

`SongBar does not have permission to control Spotify.`

SongBar must handle artwork load failure.

Artwork load failure must not block playback controls.

SongBar must handle malformed Spotify URLs.

Malformed Spotify URLs must disable open/share actions for the current track.

SongBar must handle Apple Events command failures.

Command failures should be surfaced as subtle panel feedback, not as blocking alerts unless necessary.

## 19. App Lifecycle

SongBar must launch as a menu bar app.

SongBar must not show a normal main window on launch.

SongBar must not show a Dock icon.

SongBar must keep running until the user chooses Quit or macOS terminates it.

SongBar must cleanly stop timers or polling tasks on quit.

SongBar must close its panel before termination if the panel is open.

SongBar must not quit Spotify when SongBar quits.

## 20. Polling And State Refresh

SongBar must refresh playback state on an interval.

The recommended default polling interval is 1 second while Spotify is playing.

The recommended default polling interval is 2-5 seconds while Spotify is paused or unavailable.

SongBar should refresh immediately when the panel opens.

SongBar should refresh immediately after playback commands.

SongBar should avoid unnecessary artwork downloads by detecting whether the track changed.

SongBar should avoid high CPU usage.

SongBar should avoid high memory usage.

SongBar should perform Apple Events calls off the main UI rendering path when practical.

UI updates must occur on the main actor.

## 21. Technical Architecture

SongBar should use AppKit for the menu bar item and popover.

SongBar should use SwiftUI for the popover content view.

SongBar should use `NSStatusItem` for the menu bar item.

SongBar should use `NSPopover` for the clickable native panel.

SongBar should use `NSHostingController` to host SwiftUI panel content inside the popover.

SongBar should have a `NowPlaying` model.

SongBar should have a `PlaybackState` enum.

SongBar should have a `SpotifyClient` protocol.

SongBar should have a local `AppleEventsSpotifyClient` implementation.

SongBar should have a `NowPlayingViewModel` or equivalent observable state object.

SongBar should isolate Spotify scripting code from UI code.

SongBar should isolate artwork loading from Spotify scripting code.

SongBar should isolate URL conversion logic from UI code.

SongBar should be structured so a future Spotify Web API client could be added without rewriting the UI.

## 22. Suggested Swift Types

The `PlaybackState` enum should represent at least:

- playing
- paused
- stopped
- unavailable
- unknown

The `NowPlaying` model should represent at least:

- title
- artist
- album
- playbackState
- position
- duration
- artworkURL
- spotifyURI
- shareURL

The `SpotifyClient` protocol should expose at least:

- fetchNowPlaying()
- playPause()
- nextTrack()
- previousTrack()
- seek(to:)
- openSpotify()
- openCurrentTrack()

The artwork loader should expose at least:

- loadArtwork(from:)
- cancelCurrentLoad()
- clearCache()

## 23. Data Formatting

Menu bar text must use the format:

`Artist - Song Title`

If the artist is missing, menu bar text should use:

`Song Title`

If the song title is missing, menu bar text should use:

`SongBar`

Track time must be formatted as `m:ss`.

Examples:

- `0:05`
- `2:41`
- `12:03`

The share URL should be a public `https://open.spotify.com/track/...` URL when possible.

Internal Spotify URIs may be used for opening Spotify but should not be the preferred copied share format.

## 24. Accessibility Requirements

The menu bar item must have an accessibility label.

The accessibility label should include the current track when available.

Playback buttons must have accessibility labels.

Artwork must have an accessibility label.

Slider must have an accessibility label.

The Quit button must have an accessibility label.

The UI must be keyboard navigable where native controls allow it.

The UI must have sufficient contrast in light mode and dark mode.

## 25. Branding Requirements

The app name is SongBar.

The app icon must not use Spotify's logo.

The app icon must not imitate Spotify's logo.

The app icon must not rely on Spotify's green as the primary visual identifier.

The app may use a generic music/menu-bar concept.

The README may say SongBar works with Spotify.

The README should include a trademark disclaimer.

Recommended disclaimer:

`SongBar is an independent open-source project and is not affiliated with, endorsed by, or sponsored by Spotify. Spotify is a trademark of Spotify AB.`

## 26. Distribution Requirements

Version 1 should support local development through Xcode.

Version 1 should support manual app archive export.

The project should eventually support a GitHub release with a signed and notarized `.dmg` or `.zip`.

Homebrew distribution is optional after the first stable release.

Mac App Store distribution is not required for version 1.

If distributed publicly, the app should be code signed and notarized where practical.

## 27. Open Source Requirements

The repository should include a clear README.

The repository should include a license.

The recommended license is MIT unless there is a reason to choose another permissive license.

The repository should include contribution guidance.

The repository should include build instructions.

The repository should include troubleshooting instructions for macOS Automation permission.

The repository should document that Spotify desktop app must be installed.

The repository should document that SongBar does not require Spotify credentials.

## 28. Acceptance Criteria

SongBar is acceptable for version 1 when all of the following are true:

- Launching SongBar creates a visible menu bar item.
- SongBar does not show a Dock icon.
- When Spotify is playing a track, the menu bar item shows artist and song title.
- When Spotify is paused, SongBar reflects paused state.
- Clicking the menu bar item opens a native popover panel.
- The panel shows song title, artist, playback state, progress, and duration.
- The panel shows album artwork when artwork is available.
- The play/pause button controls Spotify.
- The previous button controls Spotify.
- The next button controls Spotify.
- The slider seeks within the current song.
- The Open Spotify button launches or activates Spotify.
- The Open Track button opens the current track in Spotify when a track URL is available.
- The Copy Link or Share button copies a public Spotify track URL when available.
- The Quit button quits SongBar.
- SongBar handles Spotify closed without crashing.
- SongBar handles no current track without crashing.
- SongBar handles denied Automation permission without crashing.
- SongBar handles missing artwork without crashing.

## 29. Testing Requirements

Manual testing must cover Spotify playing.

Manual testing must cover Spotify paused.

Manual testing must cover Spotify closed.

Manual testing must cover Spotify not installed if practical.

Manual testing must cover Automation permission granted.

Manual testing must cover Automation permission denied.

Manual testing must cover a track with artwork.

Manual testing must cover a track without artwork if practical.

Manual testing must cover a local file if practical.

Manual testing must cover long artist and song names.

Manual testing must cover light mode.

Manual testing must cover dark mode.

Manual testing must cover quitting from the panel.

Automated unit tests should cover URL conversion.

Automated unit tests should cover time formatting.

Automated unit tests should cover menu bar title formatting.

Automated unit tests should cover seek value clamping.

Automated unit tests should cover state mapping from Spotify responses.

## 30. Version 1 Milestones

Milestone 1: Project foundation

- Create native macOS Swift app project.
- Configure menu bar-only lifecycle.
- Add `NSStatusItem`.
- Add click-to-open `NSPopover`.
- Add Quit button.

Milestone 2: Spotify local integration

- Add Apple Events or Scripting Bridge integration.
- Read current track metadata.
- Read player state.
- Read player position and duration.
- Add permission usage description.
- Handle unavailable Spotify states.

Milestone 3: Menu bar display

- Format artist and song title.
- Update title on interval.
- Truncate long titles.
- Show fallback title.

Milestone 4: Panel UI

- Build SwiftUI popover content.
- Show metadata.
- Show artwork.
- Show progress and duration.
- Add playback controls.

Milestone 5: Actions

- Implement play/pause.
- Implement previous track.
- Implement next track.
- Implement seek.
- Implement open Spotify.
- Implement open current track.
- Implement copy/share URL.

Milestone 6: Polish and release prep

- Add error states.
- Add dark mode and light mode QA.
- Add README.
- Add license.
- Add troubleshooting docs.
- Add basic tests.
- Prepare first unsigned development release.

## 31. Future Enhancements

Future versions may add Spotify Web API login.

Future versions may add support for remote Spotify Connect devices.

Future versions may add Apple Music support.

Future versions may add Last.fm scrobbling.

Future versions may add global keyboard shortcuts.

Future versions may add custom menu bar formatting.

Future versions may add user preferences.

Future versions may add launch at login.

Future versions may add auto-update support.

Future versions may add a compact icon-only mode.

Future versions may add Homebrew distribution.

Future versions may add signed and notarized release builds.

## 32. Key Product Decisions

SongBar will not require Spotify login in version 1.

SongBar will rely on the local Spotify desktop app in version 1.

SongBar will use a text menu bar item in version 1.

SongBar will show artwork in the panel, not in the menu bar, in version 1.

SongBar will use a native popover panel rather than a custom floating window in version 1.

SongBar will keep the scope intentionally small for version 1.

SongBar will prioritize reliability, low resource usage, and clear behavior over advanced music features.

