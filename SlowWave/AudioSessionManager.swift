import AVFoundation

enum AudioMode {
    case guiding
    case play
    case silent
}

final class AudioSessionManager {
    private let session = AVAudioSession.sharedInstance()
    var onInterruptionEnded: (() -> Void)?

    private var isObserving = false

    func activate(for mode: AudioMode) {
        do {
            switch mode {
            case .guiding:
                try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .mixWithOthers])
            case .play, .silent:
                try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            }
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
        } catch {
            print("Audio session error: \(error)")
        }
    }

    func startObservingInterruptions() {
        guard !isObserving else { return }
        isObserving = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: session
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        if type == .ended {
            onInterruptionEnded?()
        }
    }
}
