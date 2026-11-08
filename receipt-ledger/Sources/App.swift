import SwiftUI

@main
struct ReceiptLedgerApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            ListView()
                .tabItem { Label("明细", systemImage: "list.bullet.rectangle") }
            AddView()
                .tabItem { Label("记一笔", systemImage: "camera.fill") }
            StatsView()
                .tabItem { Label("统计", systemImage: "chart.pie.fill") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .tint(.accentColor)
    }
}

// MARK: - 分类图标与配色

func categoryIcon(_ name: String) -> String {
    switch name {
    case "餐饮": return "fork.knife"
    case "交通": return "car.fill"
    case "购物": return "bag.fill"
    case "超市": return "cart.fill"
    case "居住": return "house.fill"
    case "医疗": return "cross.case.fill"
    case "娱乐": return "gamecontroller.fill"
    case "通讯": return "antenna.radiowaves.left.and.right"
    case "学习": return "book.fill"
    case "工资": return "banknote.fill"
    case "奖金": return "gift.fill"
    case "报销": return "doc.text.fill"
    case "退款": return "arrow.uturn.backward.circle.fill"
    default: return "ellipsis.circle.fill"
    }
}

func categoryColor(_ name: String) -> Color {
    switch name {
    case "餐饮": return .orange
    case "交通": return .blue
    case "购物": return .pink
    case "超市": return .green
    case "居住": return .brown
    case "医疗": return .red
    case "娱乐": return .purple
    case "通讯": return .cyan
    case "学习": return .indigo
    case "工资": return .green
    default: return .gray
    }
}
