import Foundation
import UserNotifications

enum Budget {
    private static let limitKey = "aibill.monthlyBudget"
    private static let alertPrefix = "aibill.budgetAlert."

    static var limit: Double {
        get { UserDefaults.standard.double(forKey: limitKey) }
        set { UserDefaults.standard.set(newValue, forKey: limitKey) }
    }

    static var isSet: Bool { limit > 0 }

    static func monthExpense(_ items: [Txn], date: Date = Date()) -> Double {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
        let end = cal.date(byAdding: .month, value: 1, to: start) ?? start
        return items
            .filter { $0.amount > 0 && $0.date >= start && $0.date < end }
            .reduce(0) { $0 + $1.amount }
    }

    static func check(_ items: [Txn], date: Date = Date()) {
        let cap = limit
        guard cap > 0 else { return }
        let spent = monthExpense(items, date: date)
        let ratio = spent / cap
        let key = monthKey(date)

        if ratio >= 1 {
            if !alerted(key, 100) {
                mark(key, 100, and: 80)
                notify(
                    title: "本月预算已超支",
                    body: "已花 ¥\(Fmt.money(spent))，超出预算 ¥\(Fmt.money(spent - cap))。"
                )
            }
        } else if ratio >= 0.8, !alerted(key, 80) {
            mark(key, 80)
            notify(
                title: "本月预算快用完了",
                body: "已花 ¥\(Fmt.money(spent))，占预算的 \(Int(ratio * 100))%。"
            )
        }
    }

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func resetAlerts(for date: Date = Date()) {
        let key = monthKey(date)
        UserDefaults.standard.removeObject(forKey: alertPrefix + key + ".80")
        UserDefaults.standard.removeObject(forKey: alertPrefix + key + ".100")
    }

    private static func monthKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f.string(from: date)
    }

    private static func alerted(_ key: String, _ threshold: Int) -> Bool {
        UserDefaults.standard.bool(forKey: alertPrefix + key + ".\(threshold)")
    }

    private static func mark(_ key: String, _ threshold: Int, and other: Int? = nil) {
        UserDefaults.standard.set(true, forKey: alertPrefix + key + ".\(threshold)")
        if let other { UserDefaults.standard.set(true, forKey: alertPrefix + key + ".\(other)") }
    }

    private static func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}

final class BudgetNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = BudgetNotifier()

    static func install() {
        UNUserNotificationCenter.current().delegate = shared
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
