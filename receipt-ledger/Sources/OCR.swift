import Foundation
import UIKit
import Vision

struct ParsedReceipt {
    var amount: Double?
    var merchant: String?
    var date: Date?
    var category: String = "其他"
}

enum ReceiptParser {
    private static let numberRegex = try! NSRegularExpression(pattern: #"\d{1,6}(?:[.,]\d{1,2})?"#)
    private static let dateRegex = try! NSRegularExpression(pattern: #"(\d{4})[-/.年](\d{1,2})[-/.月](\d{1,2})"#)
    private static let compactDateRegex = try! NSRegularExpression(pattern: #"(20\d{2})(\d{2})(\d{2})"#)
    private static let clockRegex = try! NSRegularExpression(pattern: #"\d{1,2}:\d{2}(?::\d{2})?"#)

    static func parse(text: String) -> ParsedReceipt {
        var p = ParsedReceipt()
        p.amount = findAmount(text)
        p.merchant = findMerchant(text)
        p.date = findDate(text)
        p.category = Categories.guess(from: text)
        return p
    }

    // MARK: - 金额

    private static func findAmount(_ text: String) -> Double? {
        let keys = ["合计", "实付", "应付", "总计", "金额", "小计", "消费", "收款", "支付"]
        var scored: [(Int, Double)] = []

        for raw in text.components(separatedBy: .newlines) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            // 先把日期、时间抹掉，避免 2026 / 11 / 08 被当成金额
            line = dateRegex.stringByReplacingMatches(in: line, range: NSRange(location: 0, length: (line as NSString).length), withTemplate: " ")
            line = compactDateRegex.stringByReplacingMatches(in: line, range: NSRange(location: 0, length: (line as NSString).length), withTemplate: " ")
            line = clockRegex.stringByReplacingMatches(in: line, range: NSRange(location: 0, length: (line as NSString).length), withTemplate: " ")

            let weight = keys.contains(where: { line.contains($0) }) ? 2 : 0
            let ns = line as NSString
            for m in numberRegex.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
                let s = ns.substring(with: m.range).replacingOccurrences(of: ",", with: ".")
                guard let v = Double(s), v > 0, v < 1_000_000 else { continue }
                scored.append((weight, v))
            }
        }

        let keyed = scored.filter { $0.0 > 0 }.map { $0.1 }
        if let best = keyed.max() { return best }
        return scored.map { $0.1 }.max()
    }

    // MARK: - 商户

    private static func findMerchant(_ text: String) -> String? {
        let bad = ["发票", "收银", "单号", "电话", "日期", "欢迎", "地址", "会员", "优惠", "备注"]
        for raw in text.components(separatedBy: .newlines).prefix(6) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.count >= 2, line.count <= 28 else { continue }
            if bad.contains(where: { line.contains($0) }) { continue }
            let hasWord = line.range(of: #"[\u4e00-\u9fa5A-Za-z]"#, options: .regularExpression) != nil
            if !hasWord { continue }
            if line.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isWhitespace }) { continue }
            return line
        }
        return nil
    }

    // MARK: - 日期

    static func date(from text: String) -> Date? {
        let cal = Calendar.current
        let ns = text as NSString

        if let m = dateRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) {
            let y = Int(ns.substring(with: m.range(at: 1))) ?? 0
            let mo = Int(ns.substring(with: m.range(at: 2))) ?? 0
            let d = Int(ns.substring(with: m.range(at: 3))) ?? 0
            if let date = cal.date(from: DateComponents(year: y, month: mo, day: d)),
               abs(date.timeIntervalSinceNow) < 60 * 60 * 24 * 365 * 2 {
                return date
            }
        }

        if let m = compactDateRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) {
            let y = Int(ns.substring(with: m.range(at: 1))) ?? 0
            let mo = Int(ns.substring(with: m.range(at: 2))) ?? 0
            let d = Int(ns.substring(with: m.range(at: 3))) ?? 0
            if let date = cal.date(from: DateComponents(year: y, month: mo, day: d)),
               abs(date.timeIntervalSinceNow) < 60 * 60 * 24 * 365 * 2 {
                return date
            }
        }
        return nil
    }

    private static func findDate(_ text: String) -> Date? {
        date(from: text)
    }
}

enum OCRService {
    static func recognize(imageData: Data) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: imageData), let cg = image.cgImage else { return "" }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.usesLanguageCorrection = true
            try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
            let observations = request.results ?? []
            return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        }.value
    }
}

// MARK: - 可选：调用兼容 OpenAI 的模型做二次抽取

struct AIConfig {
    var enabled: Bool
    var baseURL: String
    var apiKey: String
    var model: String

    static func load() -> AIConfig {
        let d = UserDefaults.standard
        return AIConfig(
            enabled: d.bool(forKey: "ai.enabled"),
            baseURL: d.string(forKey: "ai.base") ?? "https://api.openai.com/v1",
            apiKey: d.string(forKey: "ai.key") ?? "",
            model: d.string(forKey: "ai.model") ?? "gpt-4o-mini"
        )
    }
}

enum AIRefiner {
    static func refine(ocrText: String, config: AIConfig) async throws -> ParsedReceipt? {
        guard config.enabled, !config.apiKey.isEmpty else { return nil }
        var base = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + "/chat/completions") else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 25
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let system = """
        你是记账助手。下面是小票 OCR 文本，请提取字段并只返回一个 JSON 对象，不要解释：
        {"amount": 数字, "merchant": "商户名", "date": "yyyy-MM-dd", "category": "餐饮|交通|购物|超市|居住|医疗|娱乐|通讯|学习|其他"}
        金额取实付或合计；识别不到就给 null。
        """
        let body: [String: Any] = [
            "model": config.model,
            "temperature": 0,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": String(ocrText.prefix(3000))]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              var content = message["content"] as? String else { return nil }

        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let l = content.range(of: "{"), let r = content.range(of: "}", options: .backwards), l.lowerBound < r.upperBound {
            content = String(content[l.lowerBound..<r.upperBound])
        }
        guard let jsonData = content.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return nil }

        var p = ParsedReceipt()
        if let a = obj["amount"] as? Double { p.amount = a }
        else if let a = obj["amount"] as? NSNumber { p.amount = a.doubleValue }
        else if let a = obj["amount"] as? String { p.amount = Double(a) }
        p.merchant = obj["merchant"] as? String
        p.category = (obj["category"] as? String) ?? "其他"
        if let ds = obj["date"] as? String { p.date = ReceiptParser.date(from: ds) }
        return p
    }
}
