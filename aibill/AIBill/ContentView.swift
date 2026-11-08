import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            LedgerView()
                .tabItem { Label("账本", systemImage: "list.bullet.rectangle") }
            StatsView()
                .tabItem { Label("统计", systemImage: "chart.pie.fill") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
    }
}
