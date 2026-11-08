import Foundation

/// 本地自然语言解析：不联网，够用就好
enum NLU {

    struct Result {
        var title: String
        var due: Date?
        var repeatRule: RepeatRule = .none
        var consumed: [String] = []
    }

    private static let cal = Calendar.current

    static func parse(_ raw: String, now: Date = Date()) -> Result? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        var dayOffset: Int? = nil
        var weekday: Int? = nil
        var month: Int? = nil
        var day: Int? = nil
        var hour: Int? = nil
        var minute: Int = 0
        var hasTime = false
        var repeatRule: RepeatRule = .none
        var consumed: [String] = []

        // 重复
        if text.contains("每天") { repeatRule = .daily; consumed.append("每天") }
        else if text.contains("每周") { repeatRule = .weekly; consumed.append("每周") }
        else if text.contains("每个工作日") || text.contains("工作日") {
            repeatRule = .workday; consumed.append("工作日")
        }

        // 相对日
        let rel: [(String, Int)] = [("大后天", 3), ("后天", 2), ("明天", 1), ("明天", 1), ("今天", 0), ("今晚", 0), ("今早", 0), ("明早", 1), ("明晚", 1)]
        for (word, off) in rel where text.contains(word) {
            dayOffset = off
            if word.contains("晚") { hour = 20; hasTime = true }
            if word.contains("早") { hour = 8; hasTime = true }
            consumed.append(word)
            break
        }

        // 周几
        if weekday == nil {
            let weekMap: [(String, Int)] = [
                ("下周一", 9), ("下周二", 10), ("下周三", 11), ("下周四", 12), ("下周五", 13), ("下周六", 14), ("下周日", 8),
                ("周一", 2), ("周二", 3), ("周三", 4), ("周四", 5), ("周五", 6), ("周六", 7), ("周日", 1), ("周天", 1),
                ("星期一", 2), ("星期二", 3), ("星期三", 4), ("星期四", 5), ("星期五", 6), ("星期六", 7), ("星期日", 1)
            ]
            for (word, target) in weekMap where text.contains(word) {
                weekday = target
                consumed.append(word)
                break
            }
        }

        // M月D日 / M/D / M-D
        if let m = firstMatch(text, pattern: #"(\d{1,2})月(\d{1,2})[日号]?"#) {
            month = Int(m[0]); day = Int(m[1])
            consumed.append(m[0] + "月" + m[1] + "日")
        } else if let m = firstMatch(text, pattern: #"\b(\d{1,2})[/-](\d{1,2})\b"#) {
            month = Int(m[0]); day = Int(m[1])
            consumed.append(m[0] + "/" + m[1])
        }

        // 时间：下午3点 / 15:30 / 3点半 / 晚8点
        var pm = false
        if text.contains("下午") || text.contains("晚上") || text.contains("傍晚") { pm = true }
        if text.contains("上午") || text.contains("早上") || text.contains("凌晨") { pm = false }

        if let m = firstMatch(text, pattern: #"(\d{1,2})[:：](\d{2})"#) {
            hour = Int(m[0]); minute = Int(m[1]) ?? 0; hasTime = true
            consumed.append(m[0] + ":" + m[1])
        } else if let m = firstMatch(text, pattern: #"(\d{1,2})点半"#) {
            hour = Int(m[0]); minute = 30; hasTime = true
            consumed.append(m[0] + "点半")
        } else if let m = firstMatch(text, pattern: #"(\d{1,2})点"#) {
            hour = Int(m[0]); minute = 0; hasTime = true
            consumed.append(m[0] + "点")
        }

        if var h = hour, pm, h < 12 { h += 12; hour = h }
        if let h = hour, h == 12 && !pm { hour = 0 }
        if let h = hour, h >= 0, h < 7, !text.contains("凌晨") { hour = h + 12 }

        // 拼日期
        var due: Date? = nil
        if month != nil || day != nil || weekday != nil || dayOffset != nil || hasTime {
            var base = cal.startOfDay(for: now)
            if let mo = month, let d = day {
                var comps = cal.dateComponents([.year], from: now)
                comps.month = mo; comps.day = d
                if let dt = cal.date(from: comps) {
                    base = dt
                    if dt < cal.startOfDay(for: now), let next = cal.date(byAdding: .year, value: 1, to: dt) {
                        base = next
                    }
                }
            } else if let target = weekday {
                let today = cal.component(.weekday, from: now)
                var delta = target - today
                if delta < 0 { delta += 7 }
                if delta == 0 && !hasTime { delta = 7 }
                base = cal.date(byAdding: .day, value: delta, to: cal.startOfDay(for: now)) ?? base
            } else if let off = dayOffset {
                base = cal.date(byAdding: .day, value: off, to: cal.startOfDay(for: now)) ?? base
            }

            let hh = hour ?? (hasTime ? 9 : 9)
            let mm = minute
            due = cal.date(bySettingHour: hh, minute: mm, second: 0, of: base)
            if !hasTime, due != nil {
                // 只给了日期，默认 9:00
                due = cal.date(bySettingHour: 9, minute: 0, second: 0, of: base)
            }
        }

        // 标题：去掉已识别的时间词
        var title = text
        for w in consumed { title = title.replacingOccurrences(of: w, with: " ") }
        for w in ["上午", "下午", "晚上", "早上", "傍晚", "凌晨", "在", "于"] {
            title = title.replacingOccurrences(of: w, with: " ")
        }
        title = title.replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { title = raw }

        return Result(title: title, due: due, repeatRule: repeatRule, consumed: consumed)
    }

    private static func firstMatch(_ text: String, pattern: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        var groups: [String] = []
        for i in 1..<m.numberOfRanges {
            if m.range(at: i).location != NSNotFound {
                groups.append(ns.substring(with: m.range(at: i)))
            }
        }
        return groups.isEmpty ? nil : groups
    }
}
