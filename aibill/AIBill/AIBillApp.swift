import SwiftUI

@main
struct AIBillApp: App {
    @StateObject private var store = Store()

    init() {
        BudgetNotifier.install()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
