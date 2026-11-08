import Foundation

enum RepeatRule: String, Codable, CaseIterable {
    case none, daily, weekly, workday

    var label: String {
        switch self {
        case .none: return "不重复"
        case .daily: return "每天"
        case .weekly: return "每周"
        case .workday: return "工作日"
        }
    }

    /// 下一次的到期时间
    func next(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .none:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .workday:
            var d = date
            for _ in 0..<10 {
                guard let n = calendar.date(byAdding: .day, value: 1, to: d) else { return nil }
                d = n
                let wd = calendar.component(.weekday, from: d)
                if wd != 1 && wd != 7 { return d }
            }
            return nil
        }
    }
}

struct Task: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var note: String = ""
    var dueAt: Date? = nil
    var done: Bool = false
    var repeatRule: RepeatRule = .none
    var createdAt: Date = Date()

    var isOverdue: Bool {
        guard let due = dueAt, !done else { return false }
        return due < Date()
    }
}

struct TodoList: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var tasks: [Task] = []

    var openCount: Int { tasks.filter { !$0.done }.count }
}

struct Coupon: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var expireAt: Date
    var note: String = ""
    var used: Bool = false

    var daysLeft: Int {
        let cal = Calendar.current
        let a = cal.startOfDay(for: Date())
        let b = cal.startOfDay(for: expireAt)
        return cal.dateComponents([.day], from: a, to: b).day ?? 0
    }
}
