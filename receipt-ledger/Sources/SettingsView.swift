import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: Store

    @AppStorage("ai.enabled") private var aiEnabled = false
    @AppStorage("ai.base") private var aiBase = "https://api.openai.com/v1"
    @AppStorage("ai.key") private var aiKey = ""
    @AppStorage("ai.model") private var aiModel = "gpt-4o-mini"
    @AppStorage("budget.monthly") private var budget = 0.0
    @AppStorage("accounts.list") private var accountRaw = ""

    @State private var confirmingClear = false
    @State private var newAccount = ""
    @State private var exportURL: URL?
    @State private var showShare = false

    private var accounts: [String] {
        let list = accountRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
        return list.isEmpty ? Accounts.defaults : list
    }

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                budgetSection
                aiSection
                dataSection
                aboutSection
            }
            .navigationTitle("设置")
            .confirmationDialog("确定清空全部记录？", isPresented: $confirmingClear, titleVisibility: .visible) {
                Button("清空", role: .destructive) { store.clearAll() }
                Button("取消", role: .cancel) {}
            }
            .sheet(isPresented: $showShare) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
        .onAppear {
            if accountRaw.isEmpty { accountRaw = Accounts.defaults.joined(separator: ",") }
        }
    }

    // MARK: - 账户

    private var accountSection: some View {
        Section {
            ForEach(accounts, id: \.self) { name in
                HStack {
                    Text(name)
                    Spacer()
                    if accounts.count > 1 {
                        Button {
                            removeAccount(name)
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                TextField("新增账户，如 信用卡", text: $newAccount)
                Button("添加") { addAccount() }
                    .disabled(newAccount.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("账户")
        } footer: {
            Text("记账时从这里选，统计页按账户汇总。")
        }
    }

    private func addAccount() {
        let name = newAccount.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !accounts.contains(name) else { return }
        accountRaw = (accounts + [name]).joined(separator: ",")
        newAccount = ""
    }

    private func removeAccount(_ name: String) {
        accountRaw = accounts.filter { $0 != name }.joined(separator: ",")
    }

    // MARK: - 预算

    private var budgetSection: some View {
        Section {
            HStack {
                Text("月度预算")
                Spacer()
                Text("¥")
                    .foregroundColor(.secondary)
                TextField("不设填 0", value: $budget, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 110)
            }
        } header: {
            Text("预算")
        } footer: {
            Text(budget > 0
                 ? "本月已用 ¥\(Int(store.total(.expense, inMonthOf: Date()))) / ¥\(Int(budget))，超过 80% 会在明细页提醒。"
                 : "填 0 = 不设预算。设了之后明细页和统计页都会显示进度。")
        }
    }

    // MARK: - AI

    private var aiSection: some View {
        Section {
            Toggle("启用 AI 二次识别", isOn: $aiEnabled)
            if aiEnabled {
                TextField("接口地址", text: $aiBase)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField("API Key", text: $aiKey)
                    .textInputAutocapitalization(.never)
                TextField("模型名", text: $aiModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        } header: {
            Text("AI 识别（可选）")
        } footer: {
            Text("默认走 iPhone 本地 OCR，不联网、不花钱。开启后会把识别出的文字（不含图片）发给上面的接口做纠错，接口需兼容 OpenAI 的 /chat/completions。")
        }
    }

    // MARK: - 数据

    private var dataSection: some View {
        Section {
            HStack {
                Text("记录条数")
                Spacer()
                Text("\(store.items.count)")
                    .foregroundColor(.secondary)
            }
            Button {
                if let url = CSVExport.makeFile(store.items) {
                    exportURL = url
                    showShare = true
                }
            } label: {
                Label("导出 Excel（CSV）", systemImage: "square.and.arrow.up")
            }
            .disabled(store.items.isEmpty)

            Button(role: .destructive) {
                confirmingClear = true
            } label: {
                Text("清空全部记录")
            }
        } header: {
            Text("数据")
        } footer: {
            Text("导出的是带 BOM 的 CSV，Excel / WPS 双击打开不乱码。数据只存在本机沙盒，卸载即清空。")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("版本")
                Spacer()
                Text("1.1")
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("识别")
                Spacer()
                Text("Vision OCR + 语音 + 规则解析")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }
        } header: {
            Text("关于")
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
