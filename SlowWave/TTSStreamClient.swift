import Foundation

enum TTSStreamError: Error {
    case missingConfig(String)
    case invalidURL
    case serverError(String)
    case invalidMessage
}

extension TTSStreamError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingConfig(let detail):
            return "TTS config missing: \(detail)"
        case .invalidURL:
            return "TTS stream URL is invalid"
        case .serverError(let message):
            return "TTS server error: \(message)"
        case .invalidMessage:
            return "TTS stream message invalid"
        }
    }
}

final class TTSStreamClient {
    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var isClosed = false

    private var pendingText: String?
    private var onAudioChunk: ((Data) -> Void)?
    private var onComplete: ((Result<Void, Error>) -> Void)?
    private var sessionID: String?
    private var hasFinished = false

    init(session: URLSession = .shared) {
        self.session = session
    }

    func synthesize(
        text: String,
        onAudioChunk: @escaping (Data) -> Void,
        onComplete: @escaping (Result<Void, Error>) -> Void
    ) {
        let appID = VolcConfig.appID
        let accessToken = VolcConfig.accessToken
        let voiceType = VolcConfig.ttsVoiceType
        let resourceID = VolcConfig.ttsResourceID
        let endpoint = VolcConfig.ttsStreamEndpoint
        var missing: [String] = []
        if appID.isEmpty { missing.append("VOLC_APP_ID") }
        if accessToken.isEmpty { missing.append("VOLC_ACCESS_TOKEN") }
        if voiceType.isEmpty { missing.append("VOLC_TTS_VOICE_TYPE") }
        if resourceID.isEmpty { missing.append("VOLC_TTS_RESOURCE_ID") }
        if endpoint.isEmpty { missing.append("VOLC_TTS_STREAM_*") }
        if !missing.isEmpty {
            onComplete(.failure(TTSStreamError.missingConfig(missing.joined(separator: ", "))))
            return
        }

        guard let url = URL(string: endpoint) else {
            onComplete(.failure(TTSStreamError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.setValue(appID, forHTTPHeaderField: "X-Api-App-Key")
        request.setValue(accessToken, forHTTPHeaderField: "X-Api-Access-Key")
        request.setValue(resourceID, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Connect-Id")

        let task = session.webSocketTask(with: request)
        self.task = task
        self.isClosed = false
        self.pendingText = text
        self.onAudioChunk = onAudioChunk
        self.onComplete = onComplete
        self.sessionID = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        self.hasFinished = false

        task.resume()
        print("TTS bidirectional start connection")
        sendStartConnection()
        receiveLoop()
    }

    func close() {
        isClosed = true
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func receiveLoop() {
        guard let task, !isClosed else { return }
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.finishOnce(.failure(error))
            case .success(let message):
                switch message {
                case .data(let data):
                    if let parsed = self.parseBidirectionalMessage(data) {
                        self.handleServerMessage(parsed)
                    } else {
                        self.receiveLoop()
                        return
                    }
                case .string(let text):
                    if !text.isEmpty {
                        self.finishOnce(.failure(TTSStreamError.serverError(text)))
                        return
                    }
                    self.receiveLoop()
                    return
                @unknown default:
                    self.finishOnce(.failure(TTSStreamError.invalidMessage))
                }
                self.receiveLoop()
            }
        }
    }

    private func handleServerMessage(_ message: StreamMessage) {
        switch message {
        case .audio(let chunk):
            if !chunk.isEmpty {
                onAudioChunk?(chunk)
                print("TTS audio chunk: \(chunk.count) bytes")
            }
        case .event(let event, let payload):
            if !payload.isEmpty {
                print("TTS event \(event): \(payload)")
            } else {
                print("TTS event \(event)")
            }
            switch event {
            case 50:
                sendStartSession()
            case 51:
                finishOnce(.failure(TTSStreamError.serverError(payload.isEmpty ? "connection failed" : payload)))
            case 150:
                sendTaskRequest()
                sendFinishSession()
            case 152:
                sendFinishConnection()
                finishOnce(.success(()))
            case 153:
                finishOnce(.failure(TTSStreamError.serverError(payload.isEmpty ? "session failed" : payload)))
            default:
                break
            }
        case .error(let detail):
            finishOnce(.failure(TTSStreamError.serverError(detail)))
        }
    }

    private func sendStartConnection() {
        let payload = Data("{}".utf8)
        send(frame: buildFrame(event: 1, sessionID: nil, payload: payload))
    }

    private func sendStartSession() {
        guard let sessionID else { return }
        let voiceType = VolcConfig.ttsVoiceType
        guard !voiceType.isEmpty else {
            finishOnce(.failure(TTSStreamError.missingConfig("VOLC_TTS_VOICE_TYPE")))
            return
        }

        var audioParams: [String: Any] = [
            "format": "pcm",
            "sample_rate": 24000
        ]
        if let speechRate = ttsRateValue(VolcConfig.ttsSpeechRate) {
            audioParams["speech_rate"] = speechRate
        }
        if let loudnessRate = ttsRateValue(VolcConfig.ttsLoudnessRate) {
            audioParams["loudness_rate"] = loudnessRate
        }
        if !VolcConfig.ttsEmotion.isEmpty {
            audioParams["emotion"] = VolcConfig.ttsEmotion
        }

        let request: [String: Any] = [
            "user": [
                "uid": VolcConfig.uid
            ],
            "req_params": [
                "speaker": voiceType,
                "audio_params": audioParams,
                "additions": ""
            ]
        ]
        let payload = jsonPayload(request)
        send(frame: buildFrame(event: 100, sessionID: sessionID, payload: payload))
        print("TTS start session")
    }

    private func sendTaskRequest() {
        guard let sessionID, let text = pendingText, !text.isEmpty else { return }
        let request: [String: Any] = [
            "req_params": [
                "text": text
            ]
        ]
        let payload = jsonPayload(request)
        send(frame: buildFrame(event: 200, sessionID: sessionID, payload: payload))
        print("TTS task request")
    }

    private func sendFinishSession() {
        guard let sessionID else { return }
        let payload = Data("{}".utf8)
        send(frame: buildFrame(event: 102, sessionID: sessionID, payload: payload))
        print("TTS finish session")
    }

    private func sendFinishConnection() {
        let payload = Data("{}".utf8)
        send(frame: buildFrame(event: 2, sessionID: nil, payload: payload))
        print("TTS finish connection")
    }

    private func send(frame: Data?) {
        guard let task, let frame, !isClosed else { return }
        task.send(.data(frame)) { _ in }
    }

    private func buildFrame(event: Int32, sessionID: String?, payload: Data) -> Data {
        var data = Data()
        let header: [UInt8] = [
            0x11,
            0x14,
            0x10,
            0x00
        ]
        data.append(contentsOf: header)
        var eventValue = event.bigEndian
        data.append(Data(bytes: &eventValue, count: 4))

        if let sessionID {
            let sessionData = Data(sessionID.utf8)
            var sessionLength = UInt32(sessionData.count).bigEndian
            data.append(Data(bytes: &sessionLength, count: 4))
            data.append(sessionData)
        }

        var payloadLength = UInt32(payload.count).bigEndian
        data.append(Data(bytes: &payloadLength, count: 4))
        data.append(payload)
        return data
    }

    private func jsonPayload(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object, options: [])) ?? Data("{}".utf8)
    }

    private func ttsRateValue(_ rate: Double?) -> Int? {
        guard let rate else { return nil }
        if (-50.0...100.0).contains(rate) {
            return Int(rate.rounded())
        }
        if (0.1...2.0).contains(rate) {
            return Int(((rate - 1.0) * 100.0).rounded())
        }
        return nil
    }

    private func finishOnce(_ result: Result<Void, Error>) {
        guard !hasFinished else { return }
        hasFinished = true
        onComplete?(result)
        close()
    }

    private enum StreamMessage {
        case audio(Data)
        case event(Int32, String)
        case error(String)
    }

    private func parseBidirectionalMessage(_ data: Data) -> StreamMessage? {
        guard data.count >= 8 else { return nil }
        let header = [UInt8](data.prefix(4))
        let messageType = (header[1] & 0xF0) >> 4

        switch messageType {
        case 0x2, 0xB:
            guard let event = readInt32(data, offset: 4) else { return nil }
            guard let sessionIdLength = readUInt32(data, offset: 8) else { return nil }
            var cursor = 12 + Int(sessionIdLength)
            guard let payloadLength = readUInt32(data, offset: cursor) else { return nil }
            cursor += 4
            guard data.count >= cursor + Int(payloadLength) else { return nil }
            let payload = data.subdata(in: cursor..<cursor + Int(payloadLength))
            if event == 352 {
                return .audio(payload)
            }
            return nil
        case 0x9:
            guard let event = readInt32(data, offset: 4) else { return nil }
            guard let idLength = readUInt32(data, offset: 8) else { return nil }
            var cursor = 12 + Int(idLength)
            guard let payloadLength = readUInt32(data, offset: cursor) else { return nil }
            cursor += 4
            let payload: String
            if payloadLength == 0 {
                payload = ""
            } else if data.count >= cursor + Int(payloadLength) {
                payload = String(data: data.subdata(in: cursor..<cursor + Int(payloadLength)), encoding: .utf8) ?? ""
            } else {
                return nil
            }
            return .event(event, payload)
        case 0xF:
            guard let errorCode = readUInt32(data, offset: 4) else { return nil }
            let payload = String(data: data.suffix(from: 8), encoding: .utf8) ?? ""
            return .error("code=\(errorCode) \(payload)")
        default:
            return nil
        }
    }

    private func readUInt32(_ data: Data, offset: Int) -> UInt32? {
        guard data.count >= offset + 4 else { return nil }
        return data[offset..<offset + 4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }

    private func readInt32(_ data: Data, offset: Int) -> Int32? {
        guard let value = readUInt32(data, offset: offset) else { return nil }
        return Int32(bitPattern: value)
    }
}
