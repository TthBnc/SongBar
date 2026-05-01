import Foundation

final class AppleEventsSpotifyClient: SpotifyClient {
    func fetchNowPlaying() async -> NowPlaying { .empty }
    func playPause() async {}
    func nextTrack() async {}
    func previousTrack() async {}
    func seek(to seconds: TimeInterval) async {}
    func openSpotify() async {}
    func openCurrentTrack() async {}
}
