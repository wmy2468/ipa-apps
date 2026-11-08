import SwiftUI
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // 前台也显示提醒
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    // 通知上的按钮
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.identifier
        let parts = id.split(separator: "-")
        // 形如 task-<uuid>-<n> / adv-<uuid>-<ts>
        if parts.count >= 3, parts[0] == "task", let taskID = UUID(uuidString: String(parts[1])) {
            switch response.actionIdentifier {
            case Notifier.actionSnooze:
                let minutes = max(1, UserDefaults.standard.integer(forKey: "snoozeMinutes"))
                Store.shared.snooze(taskID: taskID, minutes: minutes)
            case Notifier.actionDone:
                Store.shared.completeByNotification(taskID: taskID)
            default:
                break
            }
        }
        completionHandler()
    }
}

@main
struct QingdanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = Store.shared
    @AppStorage("keepAlive") private var keepAlive = false

    init() {
        UserDefaults.standard.register(defaults: [
            "nagInterval": 5,
            "nagCount": 5,
            "advanceDays": 3,
            "snoozeMinutes": 10,
            "soundOn": true
        ])
        Notifier.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onAppear {
                    Notifier.shared.requestAuth()
                    if keepAlive { KeepAlive.shared.start() }
                    store.reschedule()
                    observeBackground()
                }
        }
    }

    private func observeBackground() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { _ in
            if UserDefaults.standard.bool(forKey: "keepAlive") {
                KeepAlive.shared.start()
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @AppStorage("keepAlive") private var keepAlive = false

    var body: some View {
        TabView {
            ListsView()
                .tabItem { Label("清单", systemImage: "checklist") }
            CalendarView()
                .tabItem { Label("日历", systemImage: "calendar") }
            CouponsView()
                .tabItem { Label("优惠券", systemImage: "ticket") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .onChange(of: keepAlive) { on in
            if on { KeepAlive.shared.start() } else { KeepAlive.shared.stop() }
        }
    }
}
