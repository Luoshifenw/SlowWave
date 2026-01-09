# SlowWave (Sleep Agent)

## 给我看的总结（简明）
- 对话功能正常，白噪音稳定，TTS 已经能发声。
- TTS 2.0 走双向流式（WebSocket），能边收边播。
- 对话引擎 speaker 和 TTS 2.0 音色已分开，避免冲突。
- 已修复 `additions` 参数类型错误，并补上音频帧解析（0xB）。

## 📌 当前状态 (Current Status)
- **工程创建**: ✅ 完成 (Bundle ID: `com.wusu.SlowWave`)
- **代码集成**: ✅ 核心 Swift 文件 (`AppState`, `SpeechEngineManager` 等) 已导入
- **配置管理**: ✅ `Config.xcconfig` 已关联，`Info.plist` 已配置 Key 与音色参数
- **SDK集成**: ✅ 完成 (Pod `SpeechEngineToB` 已安装)
- **资源配置**: ✅ `aec.model` 与 `whitenoise.mp3` 已添加并可播放
- **运行状态**: ✅ 语音对话可用，白噪音稳定
- **内容生成**: ✅ 非流式长内容生成可用（已关闭 deep thinking）
- **TTS 2.0**: ✅ 已切换为双向流式（WebSocket，PCM 边收边播）
- **已知问题**:
  - ⚠️ `speaking_style` 对当前实例无明显生效（需确认模型版本 / TTS 支持）
  - ⚠️ 生成速度偏慢（非流式一次性长文本）
  - ⚠️ 控制台偶发 AudioSession 警告（不影响主流程）
  - ⚠️ TTS 双向流式偶发报 `TTSStreamError error 0`（已增加更明确的错误提示与事件日志）
  - ⚠️ 若再次出现 `speaker id=... not found in given timber`，把 `VOLC_DIALOG_TTS_SPEAKER` 置空或换成对话引擎支持的 speaker

## 📅 下一步计划 (Next Steps)
1. [ ] 确认当前实例版本（是否支持 `speaking_style`/情感/语速等能力）
2. [ ] 语音风格调整：`低声、慢速、温柔、语调平稳、句子短、ASMR、慵懒`
3. [ ] 评估是否切换为流式输出以提升速度
4. [x] 已切换 TTS 为流式（WebSocket 双向流式）
5. [ ] 优化 Play -> Silent -> Guiding 的状态机与中断逻辑
6. [ ] 确认声音风格是否满意（当前是 `zh_female_jitangnv_saturn_bigtts`）
7. [ ] 调整 TTS 参数（语速/音量/情感）达到“低声、慢速、温柔”
8. [ ] 稳定状态机（guiding / play / silent），减少多次启动

## 协作者开发指引（面向开发）
- **工程入口**: 用 `/Users/wusu/Desktop/MyProjects/SlowWave/SlowWave/SlowWave.xcworkspace` 打开。
- **机密配置**:
  - 生效的配置文件是 `/Users/wusu/Desktop/MyProjects/SlowWave/SlowWave/SlowWave/Config.xcconfig`（已在 `.gitignore` 中忽略）。
  - `Info.plist` 读取 Key，并支持 `ARK_BASE_SCHEME/HOST/PATH` 拼接 URL。
  - 不要在 `.xcconfig` 里直接写 `https://`，会被 `//` 注释截断。
- **长内容生成（Ark）**:
  - 入口：`StoryGenerator.swift`
  - 现在是**非流式** + `"thinking": {"type": "disabled"}`
  - URL 由 `VolcConfig` 拼接：`scheme://host/path`
- **TTS 2.0（WebSocket 双向流式）**:
  - 入口：`TTSStreamClient.swift` 与 `NarrationPlayer.swift`
  - PCM 流式音频（24000 Hz，单声道，Int16），边收边播
  - 请求分段（默认 300 字以内），串行合成
  - 认证 Header：`X-Api-App-Key` / `X-Api-Access-Key` / `X-Api-Resource-Id` / `X-Api-Connect-Id`
  - Endpoint 默认：`wss://openspeech.bytedance.com/api/v3/tts/bidirection`
  - `.xcconfig` 中请使用 `VOLC_TTS_STREAM_SCHEME/HOST/PATH` 避免 `//` 被注释
  - 需要配置 `VOLC_TTS_RESOURCE_ID`（建议 `seed-tts-2.0`）
  - 若控制台看到 `TTS audio chunk: ... bytes`，说明已收到音频
- **语音与状态**:
  - `SpeechEngineManager.swift` 负责对话会话创建（`speaker` + `speaking_style` 在 StartSession 中发送）
  - `AppState.swift` 负责状态机（guiding / play / silent）与对白噪音控制
  - 白噪音：`WhiteNoisePlayer.swift` 固定音量 0.35
  - 对话引擎 `speaker` 单独配置：`VOLC_DIALOG_TTS_SPEAKER`，默认为空
- **建议检查项**:
  - `speaking_style` 是否被模型实例支持
  - 是否需要切换到流式输出以缩短等待
  - AudioSession 警告是否影响后台/前台切换

## ✅ 测试流程（给我用）
1. 用 `.xcworkspace` 打开并运行到真机。
2. 启动 App 后确认白噪音立刻播放且音量稳定（0.35）。
3. 对手机说一句话（如“你好”），确认能识别并回复。
4. 看到控制台出现 `Story ready`，表示长内容生成成功。
5. 若出现 `bad URL` / `Ark request error`，检查 `Config.xcconfig` 里的 ARK 配置。

## 🧭 测试流程（协作者详细版）
- **前置**:
  - 只用 `.xcworkspace` 打开工程。
  - 在 `/SlowWave/SlowWave/SlowWave/Config.xcconfig` 中填入真实 Key。
  - 确保 `ARK_BASE_SCHEME/HOST/PATH` 正确，避免 `https://` 注释问题。
- **运行**:
  - 真机运行（模拟器可能影响音频输入/输出）。
  - 观察控制台是否出现 `White noise play started`。
  - 观察是否有 `Story ready:`，并记录耗时。
- **异常排查**:
  - `bad URL`: Base URL 被截断或空值，优先检查 ARK 配置。
  - `speaker is empty`: `VOLC_TTS_VOICE_TYPE` 未正确注入。
  - `speaker id=... not found in given timber`: 对话引擎不支持该音色，改用 `VOLC_DIALOG_TTS_SPEAKER` 或置空。
  - AudioSession 错误偶发：多为系统权限或音频路由变化，非致命。

## 🧩 问题清单（Open Issues）
- `speaking_style` 生效不明显，需要确认实例版本是否支持。
- 非流式长内容生成偏慢，考虑流式或分段生成。
- TTS 流式若无声音，优先检查 `VOLC_TTS_RESOURCE_ID`、`VOLC_TTS_STREAM_*` 与鉴权。
