import Foundation

enum CSVExport {
    /// 生成带 BOM 的 UTF-8 CSV，Excel / WPS 直接双击打开不乱码
    static func makeFile(_ items: [Tx]) -> URL? {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        var rows = ["日期,时间,类型,金额,分类,账户,商户,备注"]
        for tx in items.sorted(by: { $0.date > $1.date }) {
            let cols = [
                dayFormatter.string(from: tx.date),
                timeFormatter.string(from: tx.date),
                tx.type.title,
                String(format: "%.2f", tx.amount),
                tx.category,
                tx.account,
                tx.merchant,
                tx.note
            ]
            rows.append(cols.map(escape).joined(separator: ","))
        }

        let csv = rows.joined(separator: "\r\n")
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMdd-HHmm"
        let name = "票记-\(stamp.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)

        var data = Data([0xEF, 0xBB, 0xBF])
        if let body = csv.data(using: .utf8) { data.append(body) }
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
