import AVFoundation
import Combine
import SwiftUI

enum SleepState {
    case guiding
    case play
    case silent
}

enum SleepEvent {
    case userSpeechDetected
    case topicReady
    case playbackEnded
    case userInterrupt
}

final class AppState: ObservableObject {
    @Published private(set) var state: SleepState = .guiding
    @Published private(set) var isListening = false

    private let audioSession = AudioSessionManager()
    private let whiteNoisePlayer = WhiteNoisePlayer()
    private let narrationPlayer = NarrationPlayer()
    private let speechEngine = SpeechEngineManager()
    private let storyGenerator = StoryGenerator()
    private var whiteNoiseVolume: Float = 0.35
    private var lastUserHint = ""

    init() {
        audioSession.onInterruptionEnded = { [weak self] in
            guard let self else { return }
            self.runOnMain {
                self.whiteNoisePlayer.play(volume: self.whiteNoiseVolume)
            }
        }
        audioSession.startObservingInterruptions()

        speechEngine.onEngineStarted = { [weak self] in
            self?.restartWhiteNoiseAfterEngineStart()
        }

        speechEngine.onSpeechStart = { [weak self] in
            self?.runOnMain {
                self?.isListening = true
                self?.transition(.userSpeechDetected)
            }
        }
        speechEngine.onTranscriptUpdated = { [weak self] text in
            self?.runOnMain {
                self?.lastUserHint = text
            }
        }
        speechEngine.onSpeechEnd = { [weak self] in
            self?.runOnMain {
                self?.isListening = false
            }
        }
        speechEngine.onUserInterrupt = { [weak self] in
            self?.runOnMain {
                self?.transition(.userInterrupt)
            }
        }
        speechEngine.onTopicReady = { [weak self] in
            self?.runOnMain {
                self?.transition(.topicReady)
            }
        }

        narrationPlayer.onPlaybackEnded = { [weak self] in
            self?.runOnMain {
                self?.transition(.playbackEnded)
            }
        }
    }

    private func restartWhiteNoiseAfterEngineStart() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            self.whiteNoisePlayer.play(volume: self.whiteNoiseVolume)
        }
    }

    private func generateAndPlayStory() {
        let hint = lastUserHint
        storyGenerator.generateStory(from: hint) { [weak self] result in
            guard let self else { return }
            self.runOnMain {
                switch result {
                case .success(let text):
                    self.narrationPlayer.playStory(text: text)
                case .failure:
                    print("Story generation failed.")
                    self.transition(.playbackEnded)
                }
            }
        }
    }

    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async { block() }
        }
    }

    func start() {
        audioSession.activate(for: .guiding)
        whiteNoiseVolume = 0.35
        whiteNoisePlayer.play(volume: whiteNoiseVolume)
        speechEngine.startListening()
    }

    func stop() {
        speechEngine.stopListening()
        narrationPlayer.stopImmediately()
        whiteNoisePlayer.stop()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            start()
        default:
            stop()
        }
    }

    func transition(_ event: SleepEvent) {
        switch (state, event) {
        case (.guiding, .topicReady):
            state = .play
            audioSession.activate(for: .play)
            whiteNoiseVolume = 0.35
            whiteNoisePlayer.play(volume: whiteNoiseVolume)
            generateAndPlayStory()
        case (.play, .playbackEnded):
            state = .silent
            audioSession.activate(for: .silent)
            whiteNoiseVolume = 0.35
            whiteNoisePlayer.play(volume: whiteNoiseVolume)
        case (.play, .userInterrupt):
            narrationPlayer.stopImmediately()
            state = .guiding
            audioSession.activate(for: .guiding)
            whiteNoiseVolume = 0.35
            whiteNoisePlayer.play(volume: whiteNoiseVolume)
        case (.silent, .userSpeechDetected):
            state = .guiding
            audioSession.activate(for: .guiding)
            whiteNoiseVolume = 0.35
            whiteNoisePlayer.play(volume: whiteNoiseVolume)
        default:
            break
        }
    }
}
