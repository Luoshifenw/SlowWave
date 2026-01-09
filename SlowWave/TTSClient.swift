import Foundation

enum TTSClientError: Error {
    case missingConfig
    case invalidResponse
    case badAudioData
}

final class TTSClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func synthesize(text: String, completion: @escaping (Result<Data, Error>) -> Void) {
        let appID = VolcConfig.appID
        let accessToken = VolcConfig.accessToken
        let voiceType = VolcConfig.ttsVoiceType
        let endpoint = VolcConfig.ttsEndpoint

        guard !appID.isEmpty, !accessToken.isEmpty, !voiceType.isEmpty, !endpoint.isEmpty else {
            completion(.failure(TTSClientError.missingConfig))
            return
        }

        guard let url = URL(string: endpoint) else {
            completion(.failure(TTSClientError.missingConfig))
            return
        }

        let speedRatio = VolcConfig.ttsSpeedRatio
        let loudnessRatio = VolcConfig.ttsLoudnessRatio
        let emotion = VolcConfig.ttsEmotion

        var audio: [String: Any] = [
            "voice_type": voiceType,
            "encoding": "mp3",
            "rate": 24000
        ]
        if let speedRatio { audio["speed_ratio"] = speedRatio }
        if let loudnessRatio { audio["loudness_ratio"] = loudnessRatio }
        if !emotion.isEmpty {
            audio["enable_emotion"] = true
            audio["emotion"] = emotion
        }

        let extraParam = ["disable_markdown_filter": true]
        let extraParamString = (try? JSONSerialization.data(withJSONObject: extraParam, options: []))
            .flatMap { String(data: $0, encoding: .utf8) }

        var requestBody: [String: Any] = [
            "app": [
                "appid": appID,
                "token": accessToken,
                "cluster": VolcConfig.ttsCluster
            ],
            "user": [
                "uid": VolcConfig.uid
            ],
            "audio": audio,
            "request": [
                "reqid": UUID().uuidString,
                "text": text,
                "operation": "query"
            ]
        ]
        if let extraParamString {
            var request = requestBody["request"] as? [String: Any] ?? [:]
            request["extra_param"] = extraParamString
            requestBody["request"] = request
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer; \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])

        let task = session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data else {
                completion(.failure(TTSClientError.invalidResponse))
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("TTS HTTP \(http.statusCode): \(body)")
            }
            guard let audioData = TTSClient.parseAudio(from: data) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("TTS parse failed: \(body)")
                completion(.failure(TTSClientError.invalidResponse))
                return
            }
            completion(.success(audioData))
        }
        task.resume()
    }

    private static func parseAudio(from data: Data) -> Data? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []),
            let dict = json as? [String: Any],
            let code = dict["code"] as? Int,
            code == 3000,
            let audioBase64 = dict["data"] as? String,
            let audioData = Data(base64Encoded: audioBase64)
        else {
            return nil
        }
        return audioData
    }
}
