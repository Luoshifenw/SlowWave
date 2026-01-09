import Foundation

struct VolcConfig {
    static let appID = value(for: "VOLC_APP_ID")
    static let appKey = value(for: "VOLC_APP_KEY")
    static let accessToken = value(for: "VOLC_ACCESS_TOKEN")

    static let uid = Bundle.main.object(forInfoDictionaryKey: "VOLC_UID") as? String ?? UUID().uuidString
    static let botName = Bundle.main.object(forInfoDictionaryKey: "VOLC_BOT_NAME") as? String ?? "豆包"
    static let ttsVoiceType = value(for: "VOLC_TTS_VOICE_TYPE")
    static let dialogTTSSpeaker = value(for: "VOLC_DIALOG_TTS_SPEAKER")
    static let ttsSpeechRate = doubleValue(for: "VOLC_TTS_SPEECH_RATE")
    static let ttsLoudnessRate = doubleValue(for: "VOLC_TTS_LOUDNESS_RATE")
    static let ttsEmotion = value(for: "VOLC_TTS_EMOTION")
    static let ttsResourceID = value(for: "VOLC_TTS_RESOURCE_ID").isEmpty ? "seed-tts-2.0" : value(for: "VOLC_TTS_RESOURCE_ID")
    static let ttsCluster = value(for: "VOLC_TTS_CLUSTER").isEmpty ? "volcano_tts" : value(for: "VOLC_TTS_CLUSTER")
    static let ttsEndpoint = value(for: "VOLC_TTS_ENDPOINT").isEmpty
        ? "https://openspeech.bytedance.com/api/v3/tts/bidirection"
        : value(for: "VOLC_TTS_ENDPOINT")
    static let ttsStreamEndpoint: String = {
        let explicit = value(for: "VOLC_TTS_STREAM_ENDPOINT")
        if !explicit.isEmpty { return explicit }
        let scheme = value(for: "VOLC_TTS_STREAM_SCHEME")
        let host = value(for: "VOLC_TTS_STREAM_HOST")
        let path = value(for: "VOLC_TTS_STREAM_PATH")
        guard !scheme.isEmpty, !host.isEmpty else { return "wss://openspeech.bytedance.com/api/v3/tts/bidirection" }
        let normalizedPath: String
        if path.isEmpty {
            normalizedPath = ""
        } else {
            normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        }
        return "\(scheme)://\(host)\(normalizedPath)"
    }()

    static let ttsSpeedRatio: Double? = {
        if let rate = ttsSpeechRate, (0.1...2.0).contains(rate) {
            return rate
        }
        if let rate = ttsSpeechRate, rate != 0 {
            let normalized = 1.0 + (rate / 100.0)
            return min(2.0, max(0.1, normalized))
        }
        return nil
    }()

    static let ttsLoudnessRatio: Double? = {
        if let rate = ttsLoudnessRate, (0.5...2.0).contains(rate) {
            return rate
        }
        return nil
    }()

    static let arkBaseURL: String = {
        let explicit = value(for: "ARK_BASE_URL")
        if !explicit.isEmpty { return explicit }
        let scheme = value(for: "ARK_BASE_SCHEME")
        let host = value(for: "ARK_BASE_HOST")
        let path = value(for: "ARK_BASE_PATH")
        guard !scheme.isEmpty, !host.isEmpty else { return "" }
        let normalizedPath: String
        if path.isEmpty {
            normalizedPath = ""
        } else {
            normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        }
        return "\(scheme)://\(host)\(normalizedPath)"
    }()
    static let arkModel = value(for: "ARK_MODEL")
    static let arkApiKey = value(for: "ARK_API_KEY")

    private static func value(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return ""
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func doubleValue(for key: String) -> Double? {
        let raw = value(for: key)
        if raw.isEmpty { return nil }
        return Double(raw)
    }
}
