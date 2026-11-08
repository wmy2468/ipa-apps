import SwiftUI
import UIKit

struct LedgerView: View {
    @EnvironmentObject private var store: Store

    @State private var offset = 0
    @State private var filter: String?
    @State private var adding = false
    @State private var entryMode: AddTxnView.Mode = .manual
    @State private var editing: Txn?

    private var cal: Calendar { Calendar.current }
    private var start: Date { Fmt.monthStart(offset) }
    private var end: Date { cal.date(byAdding: .month, value: 1, to: start) ?? start }

    private var shown: [Txn] {
        store.items.filter { t in
            guard t.date >= start, t.date < end else { return false }
            if let filter, t.account != filter { return false }
            return true
        }
    }

    private var expense: Double { shown.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount } }
    private var income: Double { shown.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) } }

    private var days: [(day: Date, items: [Txn])] {
        let grouped = Dictionary(grouping: shown) { cal.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                MonthSwitcher(offset: $offset)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                accountChips
                budgetCard

                List {
                    Section {
                        summary
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if days.isEmpty {
                        Section {
                            Text("这个月还没有记录。点右上角 ＋，手动记一笔、拍张小票或说一句都行。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }

                    ForEach(days, id: \.day) { group in
                        Section {
                            ForEach(group.items) { t in
                                Button {
                                    editing = t
                                } label: {
                                    row(t)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.delete(t)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text(Fmt.dayTitle(group.day))
                                Spacer()
                                if expenseOf(group.items) > 0 {
                                    Text("-" + Fmt.money(expenseOf(group.items)))
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("账本")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            entryMode = .manual
                            adding = true
                        } label: {
                            Label("手动记账", systemImage: "square.and.pencil")
                        }
                        Button {
                            entryMode = .camera
                            adding = true
                        } label: {
                            Label("拍照识别", systemImage: "camera.fill")
                        }
                        Button {
                            entryMode = .voice
                            adding = true
                        } label: {
                            Label("语音记账", systemImage: "mic.fill")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("记一笔")
                }
            }
            .sheet(isPresented: $adding) {
                AddTxnView(mode: entryMode, account: filter)
                    .environmentObject(store)
            }
            .sheet(item: $editing) { t in
                AddTxnView(txn: t)
                    .environmentObject(store)
            }
        }
    }

    private var accountChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, title: "全部")
                ForEach(kAccounts, id: \.self) { a in
                    chip(a, title: a)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(_ value: String?, title: String) -> some View {
        let selected = filter == value
        return Button {
            filter = value
        } label: {
            HStack(spacing: 4) {
                if let value {
                    Image(systemName: accountIcon(value)).font(.caption2)
                }
                Text(title).font(.footnote)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(selected ? Color.accentColor : Color(.secondarySystemBackground))
            )
            .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var budgetCard: some View {
        if Budget.isSet {
            let cap = Budget.limit
            let spent = Budget.monthExpense(store.items, date: start)
            let ratio = cap > 0 ? spent / cap : 0
            let color: Color = ratio >= 1 ? .red : (ratio >= 0.8 ? .orange : .green)

            VStack(spacing: 6) {
                HStack {
                    Label("月预算", systemImage: "target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Fmt.money(spent)) / \(Fmt.money(cap))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(color)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.tertiarySystemFill))
                        Capsule()
                            .fill(color)
                            .frame(width: max(4, geo.size.width * min(1, ratio)))
                    }
                }
                .frame(height: 6)

                if ratio >= 1 {
                    Text("已超出预算 ¥\(Fmt.money(spent - cap))")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal, 16)
        }
    }

    private func expenseOf(_ items: [Txn]) -> Double {
        items.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }

    private var summary: some View {
        HStack(spacing: 0) {
            stat("支出", expense, .primary)
            Divider().frame(height: 30)
            stat("收入", income, .green)
            Divider().frame(height: 30)
            stat("结余", income - expense, .blue)
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func stat(_ name: String, _ value: Double, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(name).font(.caption2).foregroundStyle(.secondary)
            Text(Fmt.money(value))
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ t: Txn) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: catIcon(t.category))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title(t)).font(.subheadline).lineLimit(1)
                Text(subtitle(t)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer(minLength: 8)

            if let img = store.image(named: t.image) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text((t.amount < 0 ? "+" : "-") + Fmt.money(abs(t.amount)))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(t.amount < 0 ? Color.green : Color.primary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func title(_ t: Txn) -> String {
        if !t.merchant.isEmpty { return t.merchant }
        if !t.note.isEmpty { return t.note }
        return t.category
    }

    private func subtitle(_ t: Txn) -> String {
        var parts = [t.category, t.account]
        if !t.note.isEmpty, t.note != t.merchant { parts.append(t.note) }
        return parts.joined(separator: " · ")
    }
}
