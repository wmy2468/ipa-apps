import Foundation
import UIKit
import Combine

final class Store: ObservableObject {
    @Published private(set) var items: [Txn] = []

    private let file: URL
    private let receipts: URL
    private var cache: [String: UIImage] = [:]

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        file = base.appendingPathComponent("txns.json")
        receipts = base.appendingPathComponent("receipts", isDirectory: true)
        try? FileManager.default.createDirectory(at: receipts, withIntermediateDirectories: true)
        load()
    }

    private static func ordered(_ a: Txn, _ b: Txn) -> Bool {
        if a.date != b.date { return a.date > b.date }
        return a.createdAt > b.createdAt
    }

    private func load() {
        guard
            let data = try? Data(contentsOf: file),
            let list = try? decoder.decode([Txn].self, from: data)
        else { return }
        items = list.sorted(by: Store.ordered)
    }

    private func persist() {
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: file, options: .atomic)
    }

    func add(_ t: Txn) {
        items.append(t)
        items.sort(by: Store.ordered)
        persist()
    }

    func update(_ t: Txn) {
        guard let i = items.firstIndex(where: { $0.id == t.id }) else { return }
        items[i] = t
        items.sort(by: Store.ordered)
        persist()
    }

    func delete(_ t: Txn) {
        items.removeAll { $0.id == t.id }
        removeImage(t.image)
        persist()
    }

    func deleteAll() {
        for t in items { removeImage(t.image) }
        items = []
        persist()
    }

    func saveImage(_ data: Data) -> String? {
        let name = UUID().uuidString + ".jpg"
        do {
            try data.write(to: receipts.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    func image(named name: String?) -> UIImage? {
        guard let name, !name.isEmpty else { return nil }
        if let cached = cache[name] { return cached }
        guard let img = UIImage(contentsOfFile: receipts.appendingPathComponent(name).path) else { return nil }
        cache[name] = img
        return img
    }

    func removeImage(_ name: String?) {
        guard let name, !name.isEmpty else { return }
        cache[name] = nil
        try? FileManager.default.removeItem(at: receipts.appendingPathComponent(name))
    }

    var imageBytes: Int {
        guard let list = try? FileManager.default.contentsOfDirectory(
            at: receipts,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        return list.reduce(0) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + size
        }
    }
}
