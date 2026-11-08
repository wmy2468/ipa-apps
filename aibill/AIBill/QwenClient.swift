import Foundation
import UIKit

enum QwenError: LocalizedError {
    case noKey
    case badImage
    case emptyReply
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .noKey: return "还没有填写 API Key，请到「设置」里粘贴阿里云百炼的 DashScope Key。"
        case .badImage: return "图片压缩失败，换一张试试。"
        case .emptyReply: return "模型没有返回内容。"
        case .http(let code, let body): return "接口返回 \(code)：\(body)"
        }
    }
}

struct QwenClient {
    static let endpoint = URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")!
    static let model = "qwen-vl-plus"

    static var systemPrompt: String {
        """
        你是记账助手。看图片（小票、账单、支付截图、菜单等）提取一笔消费，只输出一个 JSON 对象，不要解释、不要 markdown 代码块。
        格式：{"amount": 数字, "merchant": "商户名", "date": "YYYY-MM-DD", "category": "分类", "account": "付款账户", "note": "一句话备注"}
        规则：
        - amount 用正数表示支出，收入用负数；实在看不出金额就填 0。
        - date 看不出来就填空字符串。
        - category 只能从这些里选：\(kCategories.joined(separator: "、"))。
        - account 只能从这些里选：\(kAccounts.joined(separator: "、"))；能从支付方式看出来就填，看不出来填空字符串。
        - merchant 尽量填图片里的商家全名，没有就填空字符串。
        - note 不超过 20 字，写买了什么。
        """
    }

    static func recognize(image: UIImage, apiKey: String) async throws -> Recognized {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw QwenError.noKey }
        guard let jpeg = image.preparingForOCR().jpegData(compressionQuality: 0.8) else { throw QwenError.badImage }

        let imagePart: [String: Any] = [
            "type": "image_url",
            "image_url": ["url": "data:image/jpeg;base64," + jpeg.base64EncodedString()],
        ]
        let textPart: [String: Any] = [
            "type": "text",
            "text": "识别这张图里的一笔消费，按要求的 JSON 输出。",
        ]
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": [imagePart, textPart]],
        ]
        let payload: [String: Any] = [
            "model": model,
            "temperature": 0.1,
            "messages": messages,
        ]

        var req = URLRequest(url: endpoint, timeoutInterval: 90)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw QwenError.emptyReply }
        guard (200..<300).contains(http.statusCode) else {
            let body = String((String(data: data, encoding: .utf8) ?? "").prefix(300))
            throw QwenError.http(http.statusCode, body)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
            throw QwenError.emptyReply
        }
        return parse(text)
    }

    static func parse(_ text: String) -> Recognized {
        let jsonText: String
        if let s = text.firstIndex(of: "{"), let e = text.lastIndex(of: "}"), s < e {
            jsonText = String(text[s...e])
        } else {
            jsonText = text
        }

        guard let data = jsonText.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return Recognized(amount: 0, merchant: "", date: nil, category: "其他", account: "现金",
                              note: String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40)))
        }

        let amount = number(obj["amount"]) ?? 0
        let merchant = str(obj["merchant"])
        let note = str(obj["note"])
        return Recognized(
            amount: amount,
            merchant: merchant,
            date: parseDate(str(obj["date"])),
            category: normalizeCategory(str(obj["category"]), merchant: merchant, note: note),
            account: normalizeAccount(str(obj["account"]), hay: merchant + note),
            note: note
        )
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    private static func number(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let s = v as? String {
            let cleaned = s
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: "¥", with: "")
                .replacingOccurrences(of: "￥", with: "")
                .trimmingCharacters(in: .whitespaces)
            return Double(cleaned)
        }
        return nil
    }

    private static func str(_ v: Any?) -> String {
        (v as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func parseDate(_ s: String) -> Date? {
        guard !s.isEmpty else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        if let d = f.date(from: s) { return d }
        f.dateFormat = "yyyy/M/d"
        return f.date(from: s)
    }

    static func normalizeAccount(_ raw: String, hay: String) -> String {
        if kAccounts.contains(raw) { return raw }
        if hay.contains("支付宝") || hay.contains("花呗") || hay.contains("余额宝") { return "支付宝" }
        if hay.contains("微信") { return "微信" }
        if hay.contains("现金") { return "现金" }
        let last = UserDefaults.standard.string(forKey: "aibill.lastAccount") ?? ""
        return kAccounts.contains(last) ? last : kAccounts[0]
    }

    static func normalizeCategory(_ raw: String, merchant: String, note: String) -> String {
        if kCategories.contains(raw) { return raw }
        let hay = raw + merchant + note
        let dict: [(String, [String])] = [
            ("餐饮", ["餐", "饭", "食", "咖啡", "奶茶", "美团", "饿了么", "火锅", "烧烤", "肯德基", "麦当劳", "星巴克"]),
            ("交通", ["打车", "地铁", "公交", "加油", "停车", "滴滴", "高铁", "机票", "出租"]),
            ("购物", ["淘宝", "京东", "拼多多", "商城", "超市", "便利店", "衣服", "鞋"]),
            ("日用", ["日用", "矿泉水", "纸巾", "洗衣", "清洁"]),
            ("娱乐", ["电影", "游戏", "门票", "会员", "视频", "KTV"]),
            ("医疗", ["医院", "药", "诊所", "体检"]),
            ("住房", ["房租", "物业", "水费", "电费", "燃气"]),
            ("通讯", ["话费", "流量", "宽带", "充值"]),
            ("人情", ["红包", "礼金", "转账"]),
        ]
        for (cat, words) in dict where words.contains(where: { hay.contains($0) }) {
            return cat
        }
        return "其他"
    }
}
