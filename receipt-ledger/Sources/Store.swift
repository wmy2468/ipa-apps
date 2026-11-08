import Foundation
import Combine

final class Store: ObservableObject {
    @Published var items: [Tx] = [] {
        didSet { if !loading { save() } }
    }

    private var loading = false
    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReceiptLedger", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("transactions.json")
        load()
    }

    private func load() {
        loading = true
        defer { loading = false }
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([Tx].self, from: data) else { return }
        items = list
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func add(_ tx: Tx) {
        items.insert(tx, at: 0)
    }

    func update(_ tx: Tx) {
        if let i = items.firstIndex(where: { $0.id == tx.id }) {
            items[i] = tx
        }
    }

    func delete(_ tx: Tx) {
        items.removeAll { $0.id == tx.id }
    }

    func delete(at offsets: IndexSet, in list: [Tx]) {
        let ids = offsets.map { list[$0].id }
        items.removeAll { ids.contains($0.id) }
    }

    func clearAll() {
        items = []
    }

    // MARK: - 统计

    func items(inMonthOf date: Date) -> [Tx] {
        let cal = Calendar.current
        return items.filter { cal.isDate($0.date, equalTo: date, toGranularity: .month) }
    }

    func total(_ type: TxType, inMonthOf date: Date) -> Double {
        items(inMonthOf: date).filter { $0.type == type }.reduce(0) { $0 + $1.amount }
    }

    func categoryTotals(inMonthOf date: Date) -> [CatStat] {
        let list = items(inMonthOf: date).filter { $0.type == .expense }
        var map: [String: Double] = [:]
        for tx in list { map[tx.category, default: 0] += tx.amount }
        return map.sorted { $0.value > $1.value }.map { CatStat(name: $0.key, value: $0.value) }
    }

    func accountTotals(inMonthOf date: Date) -> [CatStat] {
        let list = items(inMonthOf: date).filter { $0.type == .expense }
        var map: [String: Double] = [:]
        for tx in list { map[tx.account, default: 0] += tx.amount }
        return map.sorted { $0.value > $1.value }.map { CatStat(name: $0.key, value: $0.value) }
    }

    /// 按天分组（倒序）
    func groupedByDay(_ list: [Tx]? = nil) -> [DayGroup] {
        let source = list ?? items
        let cal = Calendar.current
        let groups = Dictionary(grouping: source) { cal.startOfDay(for: $0.date) }
        return groups.map { DayGroup(day: $0.key, items: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.day > $1.day }
    }
}
