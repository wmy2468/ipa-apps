import Foundation
import UIKit
import SwiftUI

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum CSV {
    static func file(from txns: [Txn]) -> URL? {
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        let time = DateFormatter()
        time.locale = Locale(identifier: "en_US_POSIX")
        time.dateFormat = "HH:mm"

        var lines = ["日期,时间,类型,金额,分类,商户,备注"]
        for t in txns.sorted(by: { $0.date < $1.date }) {
            let fields = [
                day.string(from: t.date),
                time.string(from: t.date),
                t.amount < 0 ? "收入" : "支出",
                String(format: "%.2f", abs(t.amount)),
                t.category,
                t.merchant,
                t.note,
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }

        let csv = "\u{FEFF}" + lines.joined(separator: "\r\n")
        let stamp = day.string(from: Date())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("AIBill-\(stamp).csv")
        guard let data = csv.data(using: .utf8) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func escape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }
}
