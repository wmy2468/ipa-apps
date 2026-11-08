import Foundation

let kCategories = ["餐饮", "交通", "购物", "日用", "娱乐", "医疗", "住房", "通讯", "人情", "其他"]
let kAccounts = ["微信", "支付宝", "现金"]

struct Txn: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var amount: Double
    var merchant: String
    var note: String
    var category: String
    var account: String
    var createdAt: Date
    var image: String?

    init(
        id: UUID = UUID(),
        date: Date,
        amount: Double,
        merchant: String,
        note: String,
        category: String,
        account: String = "现金",
        createdAt: Date = Date(),
        image: String? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.merchant = merchant
        self.note = note
        self.category = category
        self.account = account
        self.createdAt = createdAt
        self.image = image
    }

    enum CodingKeys: String, CodingKey {
        case id, date, amount, merchant, note, category, account, createdAt, image
    }

    // 旧数据没有 account 字段，读进来时落到「现金」
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        amount = try c.decode(Double.self, forKey: .amount)
        merchant = try c.decodeIfPresent(String.self, forKey: .merchant) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "其他"
        let saved = try c.decodeIfPresent(String.self, forKey: .account) ?? ""
        account = kAccounts.contains(saved) ? saved : "现金"
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? date
        image = try c.decodeIfPresent(String.self, forKey: .image)
    }

    var isIncome: Bool { amount < 0 }
}

struct Recognized {
    var amount: Double
    var merchant: String
    var date: Date?
    var category: String
    var account: String
    var note: String
}
