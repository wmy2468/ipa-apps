import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @AppStorage("nagInterval") private var nagInterval = 5
    @AppStorage("nagCount") private var nagCount = 5
    @AppStorage("advanceDays") private var advanceDays = 3
    @AppStorage("snoozeMinutes") private var snoozeMinutes = 10
    @AppStorage("soundOn") private var soundOn = true
    @AppStorage("keepAlive") private var keepAlive = false

    @State private var authStatus = "未知"
    @State private var pending = 0
    @State private var lastSchedule = "-"


    private let limit = 64

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("状态")
                        Spacer()
                        Text(authStatus)
                            .foregroundColor(authStatus == "已允许" ? .green : .secondary)
                    }
                    Button("测试一下（5 秒后响）") {
                        Notifier.shared.testNotification()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { refresh() }
                    }
                    if authStatus == "已拒绝" {
                        Button("去系统设置打开通知") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundColor(.red)
                    }
                } header: {
                    Text("通知权限")
                } footer: {
                    Text("必须允许通知，催促才能在 App 之外响起来。")
                }

                Section {
                    Stepper("默认提醒间隔：每 \(nagInterval) 分钟", value: $nagInterval, in: 1...60)
                    Stepper("最多催 \(nagCount) 次", value: $nagCount, in: 0...20)
                    Stepper("「延后」默认 \(snoozeMinutes) 分钟", value: $snoozeMinutes, in: 1...120)
                    Toggle("提示音", isOn: $soundOn)
                } header: {
                    Text("催办力度")
                } footer: {
                    Text("没点「完成」的任务会一直按这个间隔催下去；改完会自动重排。")
                }

                Section {
                    Stepper("过期前 \(advanceDays) 天开始提醒", value: $advanceDays, in: 0...30)
                } header: {
                    Text("提前提醒")
                } footer: {
                    Text("从过期前这么多天开始，每天上午 9 点、晚上 8 点各提醒一次，一直到过期当天。设 0 关闭。")
                }

                Section {
                    Toggle("后台常驻（推荐）", isOn: $keepAlive)
                    HStack {
                        Text("待发通知数量")
                        Spacer()
                        Text("\(pending) / \(limit)").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("最后一次排期")
                        Spacer()
                        Text(lastSchedule).foregroundColor(.secondary)
                    }
                } footer: {
                    Text("开启后 App 会在后台保持运行、按秒精确计时，催促无限延续；代价是略耗电。关闭后改用系统预排通知（受 64 条上限约束），更省电，App 被杀掉也能响。")
                }

                Section {
                    Button("重新申请通知权限") {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                            refresh()
                        }
                    }
                    Button("立即重排全部提醒") {
                        store.reschedule()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { refresh() }
                    }
                }

                Section("数据") {
                    Text("任务保存在 App 本机（Documents/lists.json）。卸载 App 会一起丢，重要内容记得手动备份。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("关于") {
                    HStack { Text("版本"); Spacer(); Text("1.2.0").foregroundColor(.secondary) }
                    Text("为 TrollStore 打造的免签名应用 · 不联网、不上传任何数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
            .onAppear { refresh() }
            .onChange(of: nagInterval) { _ in rescheduleAll() }
            .onChange(of: nagCount) { _ in rescheduleAll() }
            .onChange(of: advanceDays) { _ in rescheduleAll() }
            .onChange(of: soundOn) { _ in rescheduleAll() }
        }
    }

    private func rescheduleAll() {
        store.reschedule()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { refresh() }
        Notifier.shared.setup()
    }

    private func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let text: String
            switch s.authorizationStatus {
            case .authorized: text = "已允许"
            case .denied: text = "已拒绝"
            case .notDetermined: text = "未申请"
            case .provisional: text = "临时允许"
            case .ephemeral: text = "临时"
            @unknown default: text = "未知"
            }
            UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
                DispatchQueue.main.async {
                    authStatus = text
                    pending = reqs.count
                    if let d = UserDefaults.standard.object(forKey: "lastScheduleAt") as? Date {
                        let f = DateFormatter()
                        f.dateFormat = "HH:mm:ss"
                        lastSchedule = f.string(from: d)
                    }
                }
            }
        }
    }
}
