import SwiftUI

struct ListView: View {
    @EnvironmentObject private var store: Store
    @State private var editing: Tx?
    @State private var showingAdd = false

    private var groups: [DayGroup] { store.groupedByDay() }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let progress = Budget.progress(spent: store.total(.expense, inMonthOf: Date())),
                   progress >= 0.8 {
                    budgetBanner(progress)
                }
                content
            }
            .navigationTitle("票记")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editing) { tx in
                EditTxView(tx: tx)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingAdd) {
                AddView()
                    .environmentObject(store)
            }
        }
    }

    private var content: some View {
        Group {
            if store.items.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(groups) { group in
                        Section {
                            ForEach(group.items) { tx in
                                Button {
                                    editing = tx
                                } label: {
                                    TxRow(tx: tx)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        store.delete(tx)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text(dayText(group.day))
                                Spacer()
                                Text(dayTotalText(group.items))
                                    .foregroundColor(.secondary)
                            }
                            .font(.footnote)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func budgetBanner(_ progress: Double) -> some View {
        let over = progress >= 1
        let budget = Budget.monthly
        let spent = store.total(.expense, inMonthOf: Date())
        return HStack(spacing: 8) {
            Image(systemName: over ? "exclamationmark.triangle.fill" : "bell.fill")
            Text(over
                 ? "本月已超预算 ¥" + money(spent - budget)
                 : "本月已用 \(Int(progress * 100))% 预算，还剩 ¥" + money(budget - spent))
                .font(.footnote.weight(.medium))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(over ? Color.red.opacity(0.12) : Color.orange.opacity(0.12))
        .foregroundColor(over ? .red : .orange)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 46))
                .foregroundColor(.secondary)
            Text("还没有记录")
                .font(.headline)
            Text("点右上角相机，拍一张小票自动填")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dayText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: date)
    }

    private func dayTotalText(_ list: [Tx]) -> String {
        let income = list.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expense = list.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        var parts: [String] = []
        if expense > 0 { parts.append("-" + money(expense)) }
        if income > 0 { parts.append("+" + money(income)) }
        return parts.joined(separator: "  ")
    }

    private func money(_ v: Double) -> String {
        String(format: v.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f", v)
    }
}

struct TxRow: View {
    let tx: Tx

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(categoryColor(tx.category).opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: categoryIcon(tx.category))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(categoryColor(tx.category))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(tx.merchant.isEmpty ? tx.category : tx.merchant)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(tx.note.isEmpty ? "\(tx.category) · \(tx.account)" : "\(tx.category) · \(tx.account) · \(tx.note)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(tx.type.sign + tx.amountText)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(tx.type == .expense ? .primary : Color.green)
        }
        .padding(.vertical, 4)
    }
}

struct EditTxView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Tx

    init(tx: Tx) {
        _draft = State(initialValue: tx)
    }

    var body: some View {
        NavigationStack {
            Form {
                TxFields(tx: $draft)
            }
            .navigationTitle("编辑")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            store.update(draft)
                            dismiss()
                        }
                    }
                }
        }
    }
}
