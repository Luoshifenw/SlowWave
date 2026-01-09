import Foundation

enum StoryGeneratorError: Error {
    case missingConfig
    case invalidResponse
}

final class StoryGenerator {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func generateStory(from userHint: String, completion: @escaping (Result<String, Error>) -> Void) {
        let baseURL = VolcConfig.arkBaseURL
        let apiKey = VolcConfig.arkApiKey
        let model = VolcConfig.arkModel

        guard !baseURL.isEmpty, !apiKey.isEmpty, !model.isEmpty else {
            completion(.failure(StoryGeneratorError.missingConfig))
            return
        }

        guard let url = URL(string: baseURL) else {
            print("Ark base URL invalid: \(baseURL)")
            completion(.failure(StoryGeneratorError.missingConfig))
            return
        }

        let systemPrompt = """
        你是助眠陪伴者。输出一段中文长篇、舒缓、无冲突、无悬念的叙述。
        约 8-12 分钟长度；语气低缓、平稳、温柔；不提问；不分析；不做建议。
        以环境描写和旅途感为主，允许少量重复，避免情绪波动。
        """

        let userContent = userHint.isEmpty ? "给我一段安静的夜间旅途描述。" : "偏好提示：\(userHint)"

        let payload: [String: Any] = [
            "model": model,
            "thinking": ["type": "disabled"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        let task = session.dataTask(with: request) { data, response, error in
            if let error {
                print("Ark request error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            guard let data else {
                print("Ark response empty.")
                completion(.failure(StoryGeneratorError.invalidResponse))
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("Ark HTTP \(http.statusCode): \(body)")
            }
            guard let text = StoryGenerator.parseContent(from: data) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("Ark parse failed: \(body)")
                completion(.failure(StoryGeneratorError.invalidResponse))
                return
            }
            completion(.success(text))
        }
        task.resume()
    }

    private static func parseContent(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []),
            let dict = json as? [String: Any],
            let choices = dict["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            return nil
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
