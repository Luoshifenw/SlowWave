import Foundation

struct VolcConfig {
    static let appID = value(for: "VOLC_APP_ID")
    static let appKey = value(for: "VOLC_APP_KEY")
    static let accessToken = value(for: "VOLC_ACCESS_TOKEN")

    static let uid = Bundle.main.object(forInfoDictionaryKey: "VOLC_UID") as? String ?? UUID().uuidString
    static let botName = Bundle.main.object(forInfoDictionaryKey: "VOLC_BOT_NAME") as? String ?? "豆包"
    static let ttsVoiceType = value(for: "VOLC_TTS_VOICE_TYPE")
    static let ttsSpeechRate = doubleValue(for: "VOLC_TTS_SPEECH_RATE")
    static let ttsLoudnessRate = doubleValue(for: "VOLC_TTS_LOUDNESS_RATE")
    static let ttsEmotion = value(for: "VOLC_TTS_EMOTION")

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
