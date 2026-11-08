import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var store: Store

    @State private var month = Date()
    @State private var selected = Date()

    private let cal = Calendar.current

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月"
        return f.string(from: month)
    }

    /// 当月 42 格（6 周）
    private var gridDays: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month),
              let firstWeek = cal.dateInterval(of: .weekOfMonth, for: interval.start) else { return [] }
        var days: [Date?] = []
        var d = firstWeek.start
        for _ in 0..<42 {
            if d < interval.start || d >= interval.end { days.append(nil) }
            else { days.append(d) }
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return days
    }

    private var tasksByDay: [Date: [Task]] {
        var map: [Date: [Task]] = [:]
        for l in store.lists {
            for t in l.tasks where !t.done {
                guard let due = t.dueAt else { continue }
                let key = cal.startOfDay(for: due)
                map[key, default: []].append(t)
            }
        }
        return map
    }

    private var selectedTasks: [Task] {
        (tasksByDay[cal.startOfDay(for: selected)] ?? [])
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(monthTitle).font(.headline)
                    Spacer()
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
                HStack {
                    ForEach(weekdays, id: \.self) { w in
                        Text(w).font(.caption2).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                    ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                        if let day = day {
                            dayCell(day)
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }
                .padding(.horizontal, 6)

                Divider().padding(.top, 6)

                List {
                    if selectedTasks.isEmpty {
                        Text("这天没有任务").foregroundColor(.secondary)
                    } else {
                        ForEach(selectedTasks) { t in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(t.title)
                                    if let d = t.dueAt {
                                        Text(timeText(d)).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("日历")
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSel = cal.isDate(day, inSameDayAs: selected)
        let isToday = cal.isDateInToday(day)
        let count = (tasksByDay[cal.startOfDay(for: day)] ?? []).count
        return VStack(spacing: 3) {
            Text("\(cal.component(.day, from: day))")
                .font(.system(size: 15, weight: isToday ? .bold : .regular))
                .foregroundColor(isSel ? .white : (isToday ? .blue : .primary))
            Circle()
                .fill(count > 0 ? Color.blue : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(isSel ? Color.blue.opacity(0.85) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            selected = day
            Haptic.light()
        }
    }

    private func shiftMonth(_ delta: Int) {
        if let m = cal.date(byAdding: .month, value: delta, to: month) { month = m }
    }

    private func timeText(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}

enum Haptic {
    static func light() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.impactOccurred()
    }
}
