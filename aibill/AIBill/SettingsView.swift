import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: Store

    @State private var keyInput = ""
    @State private var budgetText = ""
    @State private var shareItem: ShareItem?
    @State private var confirmClear = false
    @State private var tip: String?

    private var maskedKey: String {
        let k = KeyStore.load()
        guard !k.isEmpty else { return "未填写" }
        if k.count <= 8 { return String(repeating: "•", count: k.count) }
        return String(k.prefix(4)) + String(repeating: "•", count: 8) + String(k.suffix(4))
    }

    private var parsedBudget: Double? {
        let cleaned = budgetText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-…", text: $keyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        Button("保存 Key") {
                            let k = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !k.isEmpty else {
                                tip = "Key 不能为空。"
                                return
                            }
                            if KeyStore.save(k) {
                                keyInput = ""
                                tip = "已保存到钥匙串。"
                            } else {
                                tip = "写入钥匙串失败。"
                            }
                        }
                        .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Spacer()

                        if !KeyStore.load().isEmpty {
                            Button("清除", role: .destructive) {
                                KeyStore.clear()
                                tip = "已清除。"
                            }
                        }
                    }

                    LabeledContent("当前", value: maskedKey)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let tip {
                        Text(tip).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("通义千问 API Key")
                } footer: {
                    Text("在阿里云百炼控制台创建 DashScope Key，粘贴到这里。Key 只存在本机钥匙串，不会上传到别处。识别走 qwen-vl-plus，按量计费。")
                }

                Section {
                    HStack {
                        Text("月预算")
                        Spacer()
                        TextField("0", text: $budgetText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                        Text("元").foregroundStyle(.secondary)
                    }

                    HStack {
                        Button("保存预算") {
                            saveBudget()
                        }
                        .disabled(parsedBudget == nil)

                        Spacer()

                        if Budget.isSet {
                            Button("关闭提醒", role: .destructive) {
                                Budget.limit = 0
                                budgetText = ""
                                tip = "预算提醒已关闭。"
                            }
                        }
                    }

                    if Budget.isSet {
                        LabeledContent("本月已花", value: "¥" + Fmt.money(Budget.monthExpense(store.items)))
                    }
                } header: {
                    Text("预算提醒")
                } footer: {
                    Text("花到月预算的 80% 和 100% 时各推一条通知，每月每档只提醒一次。第一次保存需要允许通知权限。")
                }

                Section {
                    LabeledContent("记录条数", value: "\(store.items.count)")
                    LabeledContent("图片占用", value: sizeText)

                    Button {
                        if let url = XLSX.file(from: store.items) {
                            shareItem = ShareItem(url: url)
                        } else {
                            tip = "导出失败。"
                        }
                    } label: {
                        Label("导出 Excel", systemImage: "tablecells")
                    }
                    .disabled(store.items.isEmpty)

                    Button {
                        if let url = CSV.file(from: store.items) {
                            shareItem = ShareItem(url: url)
                        } else {
                            tip = "导出失败。"
                        }
                    } label: {
                        Label("导出 CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(store.items.isEmpty)

                    Button(role: .destructive) {
                        confirmClear = true
                    } label: {
                        Label("清空全部记录", systemImage: "trash")
                    }
                    .disabled(store.items.isEmpty)
                } header: {
                    Text("数据")
                } footer: {
                    Text("Excel 能直接用 WPS / Numbers / Excel 打开，账户、分类都在列里。")
                }

                Section {
                    Link("打开阿里云百炼控制台", destination: URL(string: "https://bailian.console.aliyun.com/")!)
                    LabeledContent("版本", value: appVersion)
                } header: {
                    Text("关于")
                } footer: {
                    Text("数据只存在本机，删掉 App 就没了，重要账目记得导出。")
                }
            }
            .navigationTitle("设置")
            .onAppear {
                if budgetText.isEmpty, Budget.isSet {
                    budgetText = String(format: "%.0f", Budget.limit)
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(url: item.url)
            }
            .alert("清空全部记录？", isPresented: $confirmClear) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) { clearAll() }
            } message: {
                Text("所有账目和票据图片都会被删除，不能恢复。")
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private var sizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(store.imageBytes), countStyle: .file)
    }

    private func saveBudget() {
        guard let value = parsedBudget else {
            tip = "预算要填大于 0 的数字。"
            return
        }
        Budget.limit = value
        Budget.resetAlerts()
        Budget.requestAuthorization()
        Budget.check(store.items)
        budgetText = String(format: "%.0f", value)
        tip = "月预算已设为 ¥\(Fmt.money(value))。"
    }

    private func clearAll() {
        store.deleteAll()
        tip = "已清空。"
    }
}
