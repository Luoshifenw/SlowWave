import Foundation

#if canImport(SpeechEngineToB)
import SpeechEngineToB
#endif

final class SpeechEngineManager: NSObject {
    var onSpeechStart: (() -> Void)?
    var onSpeechEnd: (() -> Void)?
    var onUserInterrupt: (() -> Void)?
    var onTopicReady: (() -> Void)?
    var onEngineStarted: (() -> Void)?

    #if canImport(SpeechEngineToB)
    private var engine: SpeechEngine?
    #endif

    func startListening() {
        #if canImport(SpeechEngineToB)
        if engine == nil {
            SpeechEngine.prepareEnvironment()
            let engine = SpeechEngine()
            engine.createEngine(with: self)
            configure(engine)
            let result = engine.initEngine()
            if result != SENoError {
                print("Speech engine init failed: \(result)")
                return
            }
            self.engine = engine
        }

        _ = engine?.send(SEDirectiveSyncStopEngine)
        let speaker = VolcConfig.ttsVoiceType
        let ttsJSON = speaker.isEmpty ? "" : ",\"tts\":{\"speaker\":\"\(speaker)\"}"
        let startParams = """
        {"dialog":{"bot_name":"\(VolcConfig.botName)","system_role":"助眠陪伴者","speaking_style":"极慢语速、每句停顿2秒、极低声、语调近乎单调、每句不超过6个字"}\(ttsJSON)}
        """
        let result = engine?.send(SEDirectiveStartEngine, data: startParams)
        if let result, result != SENoError {
            print("Speech engine start failed: \(result)")
        }
        onEngineStarted?()
        #else
        print("SpeechEngineToB SDK not linked.")
        #endif
    }

    func stopListening() {
        #if canImport(SpeechEngineToB)
        _ = engine?.send(SEDirectiveSyncStopEngine)
        #endif
    }

    #if canImport(SpeechEngineToB)
    private func configure(_ engine: SpeechEngine) {
        engine.setStringParam(SE_DIALOG_ENGINE, forKey: SE_PARAMS_KEY_ENGINE_NAME_STRING)
        engine.setStringParam(VolcConfig.appID, forKey: SE_PARAMS_KEY_APP_ID_STRING)
        engine.setStringParam(VolcConfig.appKey, forKey: SE_PARAMS_KEY_APP_KEY_STRING)
        engine.setStringParam(VolcConfig.accessToken, forKey: SE_PARAMS_KEY_APP_TOKEN_STRING)
        engine.setStringParam("volc.speech.dialog", forKey: SE_PARAMS_KEY_RESOURCE_ID_STRING)
        engine.setStringParam(VolcConfig.uid, forKey: SE_PARAMS_KEY_UID_STRING)
        engine.setStringParam("wss://openspeech.bytedance.com", forKey: SE_PARAMS_KEY_DIALOG_ADDRESS_STRING)
        engine.setStringParam("/api/v3/realtime/dialogue", forKey: SE_PARAMS_KEY_DIALOG_URI_STRING)
        engine.setBoolParam(true, forKey: SE_PARAMS_KEY_ENABLE_AEC_BOOL)

        if let aecPath = Bundle.main.path(forResource: "aec", ofType: "model") {
            engine.setStringParam(aecPath, forKey: SE_PARAMS_KEY_AEC_MODEL_PATH_STRING)
        } else {
            print("AEC model not found in bundle.")
        }
    }
    #endif
}

#if canImport(SpeechEngineToB)
extension SpeechEngineManager: SpeechEngineDelegate {
    func onMessage(with type: SEMessageType, andData data: Data) {
        DispatchQueue.main.async {
            switch type {
            case SEEventASRInfo:
                self.onSpeechStart?()
                self.onUserInterrupt?()
            case SEEventASREnded:
                self.onSpeechEnd?()
                self.onTopicReady?()
            default:
                break
            }
        }
    }
}
#endif
