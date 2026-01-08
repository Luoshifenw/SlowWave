import AVFoundation

final class NarrationPlayer {
    private var player: AVAudioPlayer?

    func playStoryPlaceholder() {
        // Placeholder until TTS streaming is wired.
    }

    func stopImmediately() {
        player?.stop()
        player = nil
    }
}
