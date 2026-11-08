import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject private var store: Store
    @State private var month = Date()

    private var expense: Double { store.total(.expense, inMonthOf: month) }
    private var income: Double { store.total(.income, inMonthOf: month) }
    private var totals: [CatStat] { store.categoryTotals(inMonthOf: month) }
    private var count: Int { store.items(inMonthOf: month).count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    monthBar
                    summaryCard
                    budgetCard
                    categoryCard
                    accountCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("统计")
        }
    }

    private var monthBar: some View {
        HStack {
            Button {
                shift(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthTitle)
                .font(.headline)
            Spacer()
            Button {
                shift(1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.top, 8)
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("支出")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("¥" + money(expense))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("\(count) 笔")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("收入")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("¥" + money(income))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.green)
                Text("结余 ¥" + money(income - expense))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分类占比")
                .font(.subheadline.weight(.semibold))

            if totals.isEmpty {
                Text("本月还没有支出记录")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                Chart(totals) { item in
                    BarMark(
                        x: .value("金额", item.value),
                        y: .value("分类", item.name)
                    )
                    .foregroundStyle(categoryColor(item.name))
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text(money(item.value))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: CGFloat(totals.count) * 36 + 10)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var budgetCard: some View {
        Group {
            if let progress = Budget.progress(spent: expense) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("月度预算")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("¥" + money(expense) + " / ¥" + money(Budget.monthly))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: min(progress, 1))
                        .tint(progress >= 1 ? .red : (progress >= 0.8 ? .orange : .green))
                    Text(progress >= 1
                         ? "已超支 ¥" + money(expense - Budget.monthly)
                         : "还剩 ¥" + money(Budget.monthly - expense) + "，用了 \(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var accountCard: some View {
        let stats = store.accountTotals(inMonthOf: month)
        return VStack(alignment: .leading, spacing: 10) {
            Text("按账户")
                .font(.subheadline.weight(.semibold))

            if stats.isEmpty {
                Text("本月还没有支出记录")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 40)
            } else {
                ForEach(stats) { item in
                    HStack {
                        Text(item.name)
                            .font(.subheadline)
                        Spacer()
                        Text("¥" + money(item.value))
                            .font(.subheadline.weight(.medium))
                        Text("\(Int((item.value / max(expense, 1)) * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 38, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f.string(from: month)
    }

    private func shift(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .month, value: delta, to: month) {
            month = d
        }
    }

    private func money(_ v: Double) -> String {
        String(format: v.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f", v)
    }
}
