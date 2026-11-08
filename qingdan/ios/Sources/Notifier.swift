import Foundation
import UserNotifications

/// 通知调度：到期响一次，之后按间隔反复催；支持提前 N 天每日提醒、通知上的「延后/完成」
final class Notifier {
    static let shared = Notifier()

    static let categoryID = "TASK_ACTIONS"
    static let actionSnooze = "SNOOZE"
    static let actionDone = "DONE"

    private let limit = 64          // iOS 单 App 待发通知上限
    private var defaults: UserDefaults { .standard }

    private var nagInterval: Int { max(1, defaults.integer(forKey: "nagInterval")) }
    private var nagCount: Int { max(0, min(20, defaults.integer(forKey: "nagCount"))) }
    private var advanceDays: Int { max(0, min(30, defaults.integer(forKey: "advanceDays"))) }
    private var soundOn: Bool { defaults.object(forKey: "soundOn") as? Bool ?? true }

    // MARK: - 注册

    func setup() {
        let snoozeMin = max(1, defaults.integer(forKey: "snoozeMinutes"))
        let snooze = UNNotificationAction(identifier: Self.actionSnooze,
                                          title: "延后 \(snoozeMin) 分钟",
                                          options: [])
        let done = UNNotificationAction(identifier: Self.actionDone, title: "完成", options: [])
        let cat = UNNotificationCategory(identifier: Self.categoryID,
                                         actions: [snooze, done],
                                         intentIdentifiers: [],
                                         options: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])
    }

    func requestAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func testNotification() {
        let content = UNMutableNotificationContent()
        content.title = "测试提醒"
        content.body = "能看到这条，说明通知没问题"
        content.sound = soundOn ? .default : nil
        content.categoryIdentifier = Self.categoryID
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: content, trigger: trigger))
    }

    // MARK: - 取消

    func cancel(taskID: UUID) {
        var ids = (0...max(nagCount, 0)).map { "task-\(taskID.uuidString)-\($0)" }
        ids.append("adv-\(taskID.uuidString)")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    func pendingCount(_ completion: @escaping (Int) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
            DispatchQueue.main.async { completion(reqs.count) }
        }
    }

    // MARK: - 排期

    struct Item { let id: UUID; let title: String; let due: Date }

    func reschedule(tasks: [Item]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let interval = TimeInterval(60) * TimeInterval(nagInterval)
        let repeats = nagCount
        let now = Date()
        var budget = limit
        let cal = Calendar.current

        for t in tasks {
            guard budget > 0 else { break }

            // 已过期：立刻补一条，避免"过期后一条都不排"
            if t.due <= now {
                schedule(center, id: "task-\(t.id.uuidString)-0", title: t.title,
                         at: now.addingTimeInterval(5), prefix: "已过期")
                budget -= 1
            } else {
                schedule(center, id: "task-\(t.id.uuidString)-0", title: t.title, at: t.due)
                budget -= 1
            }

            // 2) 催办
            if repeats > 0 {
                for n in 1...repeats where budget > 0 {
                    let at = t.due.addingTimeInterval(interval * Double(n))
                    guard at > now else { continue }
                    schedule(center, id: "task-\(t.id.uuidString)-\(n)", title: t.title, at: at)
                    budget -= 1
                }
            }

            // 3) 提前 N 天：每天 9:00 / 20:00 各提醒一次
            if advanceDays > 0, budget > 0 {
                let startDay = cal.startOfDay(for: t.due.addingTimeInterval(-Double(advanceDays) * 86400))
                var day = startDay
                var guardCount = 0
                while day < t.due, guardCount < 40, budget > 0 {
                    guardCount += 1
                    for hour in [9, 20] {
                        guard budget > 0 else { break }
                        guard let at = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { continue }
                        guard at > now, at < t.due else { continue }
                        schedule(center, id: "adv-\(t.id.uuidString)-\(Int(at.timeIntervalSince1970))",
                                 title: t.title, at: at, prefix: "还有 \(advanceDays) 天")
                        budget -= 1
                    }
                    guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                    day = next
                }
            }
        }
    }

    private func schedule(_ center: UNUserNotificationCenter, id: String, title: String, at date: Date, prefix: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = prefix ?? "该做了"
        content.body = title
        content.sound = soundOn ? .default : nil
        content.badge = 1
        content.categoryIdentifier = Self.categoryID

        let seconds = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
