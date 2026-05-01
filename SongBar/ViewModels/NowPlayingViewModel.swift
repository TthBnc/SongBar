import Foundation
import Observation
import AppKit

@MainActor
@Observable
final class NowPlayingViewModel {
    var nowPlaying: NowPlaying = .empty
    var artwork: NSImage?
    var menuBarTitle: String = "SongBar"

    func start() {}
    func stop() {}
    func refresh() async {}
    func playPause() async {}
    func next() async {}
    func previous() async {}
    func beginSeekDrag() {}
    func endSeekDrag(at seconds: TimeInterval) async {}
    func openSpotify() async {}
    func openCurrentTrack() async {}
    func copyShareURL() {}
}
