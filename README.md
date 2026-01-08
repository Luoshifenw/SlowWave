# SlowWave (Sleep Agent)

## 📌 当前状态 (Current Status)
- **工程创建**: ✅ 完成 (Bundle ID: `com.wusu.SlowWave`)
- **代码集成**: ✅ 核心 Swift 文件 (`AppState`, `SpeechEngineManager` 等) 已导入
- **配置管理**: ✅ `Config.xcconfig` 已关联，`Info.plist` 已配置 Key 与音色参数
- **SDK集成**: ✅ 完成 (Pod `SpeechEngineToB` 已安装)
- **资源配置**: ✅ `aec.model` 与 `whitenoise.mp3` 已添加并可播放
- **运行状态**: ✅ 已验证可连接并语音交互
- **已知问题**: ⚠️ `speaking_style` 对当前实例无明显生效（需确认模型版本）

## 📅 下一步计划 (Next Steps)
1. [ ] 确认当前实例版本（O/O2/SC/SC2.0），判断是否支持 `speaking_style`
2. [ ] 确认并固定音色（当前用 `zh_female_vv_jupiter_bigtts`）
3. [ ] 接入长内容生成 + TTS（用于 Play 阶段）
4. [ ] 完善状态机与中断逻辑（Play -> Silent -> Guiding）

## 📝 开发备忘
- 必须使用 `.xcworkspace` 打开工程
- `Config.xcconfig` 中的 Key 不要提交
- `speaking_style` 若无效，需切换到支持的模型版本或改用 TTS 2.0
