import Foundation

final class NarrationPlayer {
    private let ttsClient = TTSStreamClient()
    private let audioPlayer = PcmAudioPlayer()
    private var segments: [String] = []
    private var isStopped = false

    var onPlaybackEnded: (() -> Void)?

    func playStory(text: String) {
        isStopped = false
        segments = splitText(text)
        guard !segments.isEmpty else {
            onPlaybackEnded?()
            return
        }
        playNextSegment()
    }

    func stopImmediately() {
        isStopped = true
        ttsClient.close()
        audioPlayer.stop()
        segments.removeAll()
    }

    private func playNextSegment() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isStopped else { return }
            guard !self.segments.isEmpty else {
                self.onPlaybackEnded?()
                return
            }
            let next = self.segments.removeFirst()
            do {
                try self.audioPlayer.start()
            } catch {
                print("Audio engine start failed: \(error.localizedDescription)")
            }
            self.ttsClient.synthesize(
                text: next,
                onAudioChunk: { [weak self] chunk in
                    self?.audioPlayer.scheduleAudio(chunk)
                },
                onComplete: { [weak self] result in
                    guard let self, !self.isStopped else { return }
                    switch result {
                    case .success:
                        self.audioPlayer.scheduleAudio(Data(), onDrain: { [weak self] in
                            self?.playNextSegment()
                        })
                    case .failure(let error):
                        print("TTS stream failed: \(error.localizedDescription)")
                        self.playNextSegment()
                    }
                }
            )
        }
    }

    private func splitText(_ text: String, maxLength: Int = 300) -> [String] {
        let cleaned = text.replacingOccurrences(of: "\r", with: "\n")
        let separators = CharacterSet(charactersIn: "。！？\n")
        var segments: [String] = []
        var current = ""

        for scalar in cleaned.unicodeScalars {
            let char = Character(scalar)
            current.append(char)
            if separators.contains(scalar) {
                if current.count >= maxLength {
                    segments.append(contentsOf: chunk(current, maxLength: maxLength))
                    current = ""
                } else {
                    segments.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                    current = ""
                }
            }
        }
        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            segments.append(contentsOf: chunk(current, maxLength: maxLength))
        }
        return segments.filter { !$0.isEmpty }
    }

    private func chunk(_ text: String, maxLength: Int) -> [String] {
        var result: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: maxLength, limitedBy: text.endIndex) ?? text.endIndex
            let part = String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !part.isEmpty {
                result.append(part)
            }
            start = end
        }
        return result
    }
}
