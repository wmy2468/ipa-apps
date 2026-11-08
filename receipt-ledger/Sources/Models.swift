import Foundation

enum TxType: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }
    var title: String { self == .expense ? "支出" : "收入" }
    var sign: String { self == .expense ? "-" : "+" }
}

struct Tx: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var type: TxType = .expense
    var amount: Double = 0
    var category: String = "其他"
    var account: String = "微信"
    var merchant: String = ""
    var note: String = ""
    var date: Date = Date()
    var createdAt: Date = Date()

    init() {}

    init(type: TxType = .expense,
         amount: Double = 0,
         category: String = "其他",
         account: String = "微信",
         merchant: String = "",
         note: String = "",
         date: Date = Date()) {
        self.type = type
        self.amount = amount
        self.category = category
        self.account = account
        self.merchant = merchant
        self.note = note
        self.date = date
    }

    // 老数据没有 account 字段；缺字段时给默认值，别让整份文件解不出来
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        type = try c.decodeIfPresent(TxType.self, forKey: .type) ?? .expense
        amount = try c.decodeIfPresent(Double.self, forKey: .amount) ?? 0
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "其他"
        account = try c.decodeIfPresent(String.self, forKey: .account) ?? "微信"
        merchant = try c.decodeIfPresent(String.self, forKey: .merchant) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    var amountText: String {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        n.minimumFractionDigits = amount.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        n.maximumFractionDigits = 2
        return n.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
}

struct DayGroup: Identifiable {
    var id: Date { day }
    let day: Date
    let items: [Tx]
}

struct CatStat: Identifiable {
    var id: String { name }
    let name: String
    let value: Double
}

enum Accounts {
    static let storageKey = "accounts.list"
    static let defaults = ["微信", "支付宝", "现金", "银行卡"]

    static var list: [String] {
        get {
            let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
            let saved = raw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
            return saved.isEmpty ? defaults : saved
        }
        set {
            UserDefaults.standard.set(newValue.joined(separator: ","), forKey: storageKey)
        }
    }

    static var firstName: String { list.first ?? "微信" }
}

enum Budget {
    static let storageKey = "budget.monthly"

    static var monthly: Double {
        get { UserDefaults.standard.double(forKey: storageKey) }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }

    /// 没设预算返回 nil
    static func progress(spent: Double) -> Double? {
        let b = monthly
        guard b > 0 else { return nil }
        return spent / b
    }
}

enum Categories {
    static let expense = ["餐饮", "交通", "购物", "超市", "居住", "医疗", "娱乐", "通讯", "学习", "其他"]
    static let income = ["工资", "奖金", "报销", "退款", "其他"]

    static func list(for type: TxType) -> [String] {
        type == .expense ? expense : income
    }

    /// 关键词 → 分类，命中即返回，用于 OCR / 语音自动归类
    static let keywords: [(String, [String])] = [
        ("餐饮", ["餐", "饭", "面", "粉", "粥", "烧烤", "火锅", "麦当劳", "肯德基", "星巴克", "瑞幸", "奶茶", "咖啡", "酒楼", "食府", "小吃", "烘焙", "面包", "早点", "外卖"]),
        ("超市", ["超市", "便利店", "7-11", "全家", "罗森", "美宜佳", "沃尔玛", "永辉", "华润", "盒马", "菜市场", "生鲜"]),
        ("交通", ["地铁", "公交", "滴滴", "打车", "出租车", "高铁", "火车", "机票", "航空", "加油", "停车", "ETC", "单车"]),
        ("购物", ["淘宝", "天猫", "京东", "拼多多", "商城", "百货", "服饰", "优衣库", "商场", "旗舰店", "买了"]),
        ("居住", ["物业", "房租", "水费", "电费", "燃气", "暖气", "家政"]),
        ("医疗", ["医院", "药房", "药店", "诊所", "体检", "口腔", "医疗", "挂号"]),
        ("娱乐", ["电影", "影城", "KTV", "游戏", "健身", "演出", "门票", "会员"]),
        ("通讯", ["话费", "流量", "宽带", "移动", "联通", "电信"]),
        ("学习", ["书店", "图书", "课程", "培训", "教育", "文具"])
    ]

    static func guess(from text: String) -> String {
        for (cat, words) in keywords {
            for w in words where text.localizedCaseInsensitiveContains(w) {
                return cat
            }
        }
        return "其他"
    }
}
