import AVFoundation

final class WhiteNoisePlayer {
    private var player: AVAudioPlayer?

    func play(volume: Float) {
        if player == nil {
            player = makePlayer()
        }
        guard let player else { return }
        player.volume = volume
        player.numberOfLoops = -1
        player.currentTime = 0
        player.prepareToPlay()
        let started = player.play()
        print("White noise play started: \(started), volume: \(volume), isPlaying: \(player.isPlaying)")
    }

    func stop() {
        player?.stop()
        player = nil
    }

    private func makePlayer() -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: "whitenoise", withExtension: "mp3") else {
            print("White noise file not found in bundle.")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            print("White noise player error: \(error)")
            return nil
        }
    }
}
