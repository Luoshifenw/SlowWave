import AVFoundation

final class PcmAudioPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let bytesPerFrame: Int
    private var pendingBuffers = 0
    private var isStarted = false
    private var isStopped = false
    private var onDrain: (() -> Void)?

    init(sampleRate: Double = 24000, channels: AVAudioChannelCount = 1) {
        format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: channels, interleaved: true)!
        bytesPerFrame = Int(channels) * MemoryLayout<Int16>.size
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func start() throws {
        guard !isStarted else { return }
        isStopped = false
        try engine.start()
        player.play()
        isStarted = true
    }

    func stop() {
        isStopped = true
        player.stop()
        engine.stop()
        pendingBuffers = 0
        isStarted = false
    }

    func scheduleAudio(_ data: Data, onDrain: (() -> Void)? = nil) {
        guard !isStopped else { return }
        self.onDrain = onDrain
        let frameCount = data.count / bytesPerFrame
        guard frameCount > 0 else {
            if pendingBuffers == 0 {
                DispatchQueue.main.async { [weak self] in
                    self?.onDrain?()
                }
            }
            return
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        data.withUnsafeBytes { rawBuffer in
            guard let src = rawBuffer.baseAddress else { return }
            if let dst = buffer.int16ChannelData {
                memcpy(dst[0], src, data.count)
            }
        }

        pendingBuffers += 1
        player.scheduleBuffer(buffer) { [weak self] in
            guard let self else { return }
            self.pendingBuffers -= 1
            if self.pendingBuffers == 0 {
                DispatchQueue.main.async { [weak self] in
                    self?.onDrain?()
                }
            }
        }
    }
}
