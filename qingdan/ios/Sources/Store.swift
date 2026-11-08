import Foundation
import Combine

final class Store: ObservableObject {
    static let shared = Store()

    @Published var lists: [TodoList] = []
    @Published var coupons: [Coupon] = []

    private let fileURL: URL
    private let couponURL: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("lists.json")
        couponURL = dir.appendingPathComponent("coupons.json")
        load()
        loadCoupons()
    }

    // MARK: - 持久化

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([TodoList].self, from: data) else {
            lists = [TodoList(name: "待办")]
            return
        }
        lists = decoded.isEmpty ? [TodoList(name: "待办")] : decoded
    }

    private func loadCoupons() {
        guard let data = try? Data(contentsOf: couponURL),
              let decoded = try? JSONDecoder().decode([Coupon].self, from: data) else { return }
        coupons = decoded
    }

    func saveCoupons() {
        if let data = try? JSONEncoder().encode(coupons) {
            try? data.write(to: couponURL, options: .atomic)
        }
        reschedule()
    }

    func addCoupon(_ title: String, expireAt: Date, note: String = "") {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        coupons.append(Coupon(title: t, expireAt: expireAt, note: note))
        saveCoupons()
    }

    func deleteCoupon(_ id: UUID) {
        coupons.removeAll { $0.id == id }
        saveCoupons()
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(lists)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("保存失败: \(error)")
        }
        reschedule()
    }

    // MARK: - 清单

    func addList(_ name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        lists.append(TodoList(name: n))
        save()
    }

    func renameList(_ id: UUID, to name: String) {
        guard let i = lists.firstIndex(where: { $0.id == id }) else { return }
        lists[i].name = name
        save()
    }

    func deleteList(_ id: UUID) {
        lists.removeAll { $0.id == id }
        save()
    }

    // MARK: - 任务

    func addTask(listID: UUID, title: String, dueAt: Date?, note: String = "", repeatRule: RepeatRule = .none) {
        guard let i = lists.firstIndex(where: { $0.id == listID }) else { return }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        lists[i].tasks.append(Task(title: t, note: note, dueAt: dueAt, repeatRule: repeatRule))
        save()
    }

    func toggleTask(listID: UUID, taskID: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listID }),
              let ti = lists[li].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        var task = lists[li].tasks[ti]
        task.done.toggle()
        lists[li].tasks[ti] = task

        if task.done {
            Notifier.shared.cancel(taskID: task.id)
            // 重复任务：勾掉的瞬间生成下一期
            if task.repeatRule != .none, let due = task.dueAt,
               let next = task.repeatRule.next(after: due) {
                var n = task
                n.id = UUID()
                n.done = false
                n.dueAt = next
                n.createdAt = Date()
                lists[li].tasks.append(n)
            }
        }
        save()
    }

    func snooze(taskID: UUID, minutes: Int) {
        for li in lists.indices {
            guard let ti = lists[li].tasks.firstIndex(where: { $0.id == taskID }) else { continue }
            let newDue = Date().addingTimeInterval(Double(minutes) * 60)
            lists[li].tasks[ti].dueAt = newDue
            save()
            return
        }
    }

    func completeByNotification(taskID: UUID) {
        for li in lists.indices {
            guard let ti = lists[li].tasks.firstIndex(where: { $0.id == taskID }) else { continue }
            toggleTask(listID: lists[li].id, taskID: taskID)
            return
        }
    }

    func updateTask(listID: UUID, taskID: UUID, title: String, note: String, dueAt: Date?, repeatRule: RepeatRule) {
        guard let li = lists.firstIndex(where: { $0.id == listID }),
              let ti = lists[li].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        lists[li].tasks[ti].title = title
        lists[li].tasks[ti].note = note
        lists[li].tasks[ti].dueAt = dueAt
        lists[li].tasks[ti].repeatRule = repeatRule
        save()
    }

    func deleteTask(listID: UUID, taskID: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[li].tasks.removeAll { $0.id == taskID }
        Notifier.shared.cancel(taskID: taskID)
        save()
    }

    func updateNote(listID: UUID, taskID: UUID, note: String) {
        guard let li = lists.firstIndex(where: { $0.id == listID }),
              let ti = lists[li].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        lists[li].tasks[ti].note = note
        save()
    }

    // MARK: - 提醒

    func allOpenTasks() -> [(list: TodoList, task: Task)] {
        var out: [(TodoList, Task)] = []
        for l in lists {
            for t in l.tasks where !t.done && t.dueAt != nil {
                out.append((l, t))
            }
        }
        return out.sorted { ($0.1.dueAt ?? .distantFuture) < ($1.1.dueAt ?? .distantFuture) }
    }

    func reschedule() {
        let items: [Notifier.Item] = allOpenTasks().compactMap { pair in
            guard let due = pair.task.dueAt else { return nil }
            return Notifier.Item(id: pair.task.id, title: pair.task.title, due: due)
        }
        var all = items
        for c in coupons where !c.used {
            all.append(Notifier.Item(id: c.id, title: "券：" + c.title, due: c.expireAt))
        }
        Notifier.shared.reschedule(tasks: all)
        UserDefaults.standard.set(Date(), forKey: "lastScheduleAt")
    }
}
