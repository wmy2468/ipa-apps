import SwiftUI
import UIKit

enum Fmt {
    private static let moneyFmt: NumberFormatter = {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        n.minimumFractionDigits = 2
        n.maximumFractionDigits = 2
        return n
    }()

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f
    }()

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEE"
        return f
    }()

    static func money(_ v: Double) -> String {
        moneyFmt.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }

    static func monthStart(_ offset: Int) -> Date {
        let cal = Calendar.current
        let base = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        return cal.date(byAdding: .month, value: offset, to: base) ?? base
    }

    static func monthTitle(_ offset: Int) -> String {
        monthFmt.string(from: monthStart(offset))
    }

    static func dayTitle(_ d: Date) -> String {
        dayFmt.string(from: d)
    }
}

func catIcon(_ c: String) -> String {
    switch c {
    case "餐饮": return "fork.knife"
    case "交通": return "car.fill"
    case "购物": return "bag.fill"
    case "日用": return "basket.fill"
    case "娱乐": return "gamecontroller.fill"
    case "医疗": return "cross.case.fill"
    case "住房": return "bed.double.fill"
    case "通讯": return "phone.fill"
    case "人情": return "gift.fill"
    default: return "ellipsis.circle.fill"
    }
}

func accountIcon(_ a: String) -> String {
    switch a {
    case "微信": return "message.fill"
    case "支付宝": return "a.circle.fill"
    case "现金": return "banknote.fill"
    default: return "creditcard.fill"
    }
}

struct MonthSwitcher: View {
    @Binding var offset: Int

    var body: some View {
        HStack {
            Button { offset -= 1 } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold))
            }
            Spacer()
            Text(Fmt.monthTitle(offset))
                .font(.headline)
                .monospacedDigit()
            Spacer()
            Button { offset += 1 } label: {
                Image(systemName: "chevron.right").font(.body.weight(.semibold))
            }
            .disabled(offset >= 0)
        }
        .padding(.horizontal, 4)
    }
}

extension UIImage {
    func preparingForOCR(maxSide: CGFloat = 1280) -> UIImage {
        let w = size.width
        let h = size.height
        guard w > 0, h > 0 else { return self }
        let scale = min(1, maxSide / max(w, h))
        let target = CGSize(width: (w * scale).rounded(), height: (h * scale).rounded())
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = 1
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: target, format: fmt).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
