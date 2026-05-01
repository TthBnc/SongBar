import Foundation

protocol SpotifyClient: Sendable {
    func fetchNowPlaying() async -> NowPlaying
    func playPause() async
    func nextTrack() async
    func previousTrack() async
    func seek(to seconds: TimeInterval) async
    func openSpotify() async
    func openCurrentTrack() async
}
