import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var store: Store

    @State private var offset = 0

    private var all: [Txn] { store.items }

    private var cal: Calendar { Calendar.current }
    private var start: Date { Fmt.monthStart(offset) }
    private var end: Date { cal.date(byAdding: .month, value: 1, to: start) ?? start }
    private var shown: [Txn] { all.filter { $0.date >= start && $0.date < end } }
    private var expense: Double { shown.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount } }
    private var income: Double { shown.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) } }

    private var byCategory: [(String, Double)] {
        var sum: [String: Double] = [:]
        for t in shown where t.amount > 0 {
            sum[t.category, default: 0] += t.amount
        }
        return sum.sorted { $0.value > $1.value }
    }

    private var byAccount: [(String, Double, Double)] {
        var exp: [String: Double] = [:]
        var inc: [String: Double] = [:]
        for t in shown {
            if t.amount > 0 {
                exp[t.account, default: 0] += t.amount
            } else if t.amount < 0 {
                inc[t.account, default: 0] += abs(t.amount)
            }
        }
        let names = Set(exp.keys).union(inc.keys)
        return names
            .map { ($0, exp[$0] ?? 0, inc[$0] ?? 0) }
            .sorted { $0.1 > $1.1 }
    }

    private var trend: [(Date, Double)] {
        (0..<6).reversed().map { i in
            let s = Fmt.monthStart(offset - i)
            let e = cal.date(byAdding: .month, value: 1, to: s) ?? s
            let total = all
                .filter { $0.amount > 0 && $0.date >= s && $0.date < e }
                .reduce(0) { $0 + $1.amount }
            return (s, total)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MonthSwitcher(offset: $offset)
                        .padding(.horizontal, 4)

                    HStack(spacing: 12) {
                        bigCard("支出", expense, "arrow.up.right", .orange)
                        bigCard("收入", income, "arrow.down.left", .green)
                    }

                    section("支出排行", subtitle: "共 \(byCategory.count) 个分类") {
                        if byCategory.isEmpty {
                            Text("这个月还没有支出记录。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(byCategory, id: \.0) { item in
                                    categoryRow(item.0, item.1, byCategory.first?.1 ?? 1)
                                }
                            }
                        }
                    }

                    section("账户", subtitle: "本月各账户流水") {
                        if byAccount.isEmpty {
                            Text("这个月还没有账户流水。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            VStack(spacing: 14) {
                                ForEach(byAccount, id: \.0) { item in
                                    accountRow(item.0, item.1, item.2)
                                }
                            }
                        }
                    }

                    section("近 6 个月支出", subtitle: "含当前月份") {
                        trendChart
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("统计")
        }
    }

    private func bigCard(_ name: String, _ value: Double, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(name, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Fmt.money(value))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func categoryRow(_ name: String, _ value: Double, _ maxValue: Double) -> some View {
        let ratio = maxValue > 0 ? min(1, value / maxValue) : 0
        return VStack(spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: catIcon(name))
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 16)
                Text(name).font(.subheadline)
                Spacer()
                Text(Fmt.money(value))
                    .font(.subheadline)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.accentColor.opacity(0.12))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(4, geo.size.width * ratio))
                }
            }
            .frame(height: 6)
        }
    }

    private func accountRow(_ name: String, _ expense: Double, _ income: Double) -> some View {
        HStack(spacing: 10) {
            Image(systemName: accountIcon(name))
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
            Text(name).font(.subheadline)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("-" + Fmt.money(expense))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                if income > 0 {
                    Text("收入 +" + Fmt.money(income))
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .monospacedDigit()
                }
            }
        }
    }

    private var trendChart: some View {
        let maxValue = max(trend.map(\.1).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(trend, id: \.0) { item in
                VStack(spacing: 6) {
                    Text(shortMoney(item.1))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(item.1 > 0 ? 0.85 : 0.15))
                        .frame(height: max(4, 110 * CGFloat(item.1 / maxValue)))
                    Text(monthLabel(item.0))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 160, alignment: .bottom)
        .padding(.top, 6)
    }

    private func monthLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M月"
        return f.string(from: d)
    }

    private func shortMoney(_ v: Double) -> String {
        if v >= 10000 { return String(format: "%.1f万", v / 10000) }
        if v >= 1000 { return String(format: "%.0f", v) }
        return String(format: "%.0f", v)
    }

    private func section<Content: View>(
        _ title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Spacer()
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
