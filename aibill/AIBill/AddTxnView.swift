import SwiftUI
import PhotosUI
import UIKit

struct AddTxnView: View {
    enum Mode {
        case manual
        case camera
        case voice
    }

    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    private let txn: Txn?
    private let mode: Mode

    @State private var amountText: String
    @State private var isIncome: Bool
    @State private var merchant: String
    @State private var note: String
    @State private var category: String
    @State private var account: String
    @State private var date: Date

    @State private var image: UIImage?
    @State private var imageDirty = false
    @State private var photoItem: PhotosPickerItem?
    @State private var cameraImage: UIImage?
    @State private var activeSheet: ActiveSheet?
    @State private var recognizing = false
    @State private var hint: String?
    @State private var errorText: String?
    @State private var didBootstrap = false

    private enum ActiveSheet: String, Identifiable {
        case camera
        case voice
        var id: String { rawValue }
    }

    init(txn: Txn? = nil, mode: Mode = .manual, account: String? = nil) {
        self.txn = txn
        self.mode = mode

        let stored = UserDefaults.standard.string(forKey: "aibill.lastAccount") ?? ""
        let fallback = account ?? (kAccounts.contains(stored) ? stored : kAccounts[0])
        let initial = txn.map { kAccounts.contains($0.account) ? $0.account : fallback } ?? fallback

        _amountText = State(initialValue: txn.map { String(format: "%.2f", abs($0.amount)) } ?? "")
        _isIncome = State(initialValue: (txn?.amount ?? 0) < 0)
        _merchant = State(initialValue: txn?.merchant ?? "")
        _note = State(initialValue: txn?.note ?? "")
        _category = State(initialValue: txn?.category ?? "餐饮")
        _account = State(initialValue: initial)
        _date = State(initialValue: txn?.date ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    HStack(spacing: 18) {
                        Button {
                            activeSheet = .camera
                        } label: {
                            Label("拍照", systemImage: "camera.fill")
                        }
                        .buttonStyle(.borderless)

                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("相册", systemImage: "photo.on.rectangle")
                        }

                        Spacer()

                        if image != nil {
                            Button(role: .destructive) {
                                image = nil
                                imageDirty = true
                                photoItem = nil
                                hint = nil
                                errorText = nil
                            } label: {
                                Label("清空", systemImage: "xmark.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .font(.subheadline)

                    if recognizing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("AI 正在识别…").font(.footnote).foregroundStyle(.secondary)
                        }
                    } else if let hint {
                        Text(hint).font(.footnote).foregroundStyle(.secondary)
                    }

                    if let errorText {
                        Text(errorText).font(.footnote).foregroundStyle(.red)
                    }

                    if image != nil && !recognizing {
                        Button {
                            if let img = image { startRecognize(img) }
                        } label: {
                            Label("重新 AI 识别", systemImage: "sparkles")
                        }
                    }
                } header: {
                    Text("票据")
                } footer: {
                    Text("不想拍小票就跳过这栏，直接在下面手填；也可以点金额旁边的麦克风说一句，比如「午饭三十五，微信支付」。")
                }

                Section {
                    HStack {
                        Text("¥").foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .monospacedDigit()

                        Button {
                            activeSheet = .voice
                        } label: {
                            Image(systemName: "mic.fill")
                                .font(.body.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("语音录入")
                    }

                    Picker("类型", selection: $isIncome) {
                        Text("支出").tag(false)
                        Text("收入").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField("商户", text: $merchant)

                    DatePicker("日期", selection: $date, displayedComponents: .date)

                    Picker("分类", selection: $category) {
                        ForEach(kCategories, id: \.self) { c in
                            Label(c, systemImage: catIcon(c)).tag(c)
                        }
                    }

                    Picker("账户", selection: $account) {
                        ForEach(kAccounts, id: \.self) { a in
                            Label(a, systemImage: accountIcon(a)).tag(a)
                        }
                    }

                    TextField("备注（可选）", text: $note)
                }
            }
            .navigationTitle(txn == nil ? "记一笔" : "编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .camera:
                    CameraPicker(image: $cameraImage)
                        .ignoresSafeArea()
                case .voice:
                    VoiceSheet { result in
                        applyVoice(result)
                    }
                }
            }
            .onAppear(perform: bootstrap)
            .onChange(of: photoItem) { item in
                guard let item = item else { return }
                Task { @MainActor in
                    guard
                        let data = try? await item.loadTransferable(type: Data.self),
                        let img = UIImage(data: data)
                    else { return }
                    handle(img)
                }
            }
            .onChange(of: cameraImage) { img in
                guard let img = img else { return }
                cameraImage = nil
                handle(img)
            }
        }
    }

    private func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true

        if image == nil, let name = txn?.image, let img = store.image(named: name) {
            image = img
        }

        guard txn == nil else { return }
        switch mode {
        case .manual:
            break
        case .camera:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { activeSheet = .camera }
        case .voice:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { activeSheet = .voice }
        }
    }

    private func handle(_ img: UIImage) {
        image = img
        imageDirty = true
        startRecognize(img)
    }

    private func startRecognize(_ img: UIImage) {
        errorText = nil
        hint = nil

        let key = KeyStore.load()
        guard !key.isEmpty else {
            hint = "还没填 API Key，先到「设置」里粘贴 DashScope Key，再点「重新 AI 识别」。"
            return
        }

        recognizing = true
        Task { @MainActor in
            do {
                let r = try await QwenClient.recognize(image: img, apiKey: key)
                apply(r)
            } catch {
                errorText = error.localizedDescription
            }
            recognizing = false
        }
    }

    private func apply(_ r: Recognized) {
        if r.amount != 0 {
            amountText = String(format: "%.2f", abs(r.amount))
            isIncome = r.amount < 0
        }
        if !r.merchant.isEmpty { merchant = r.merchant }
        if let d = r.date { date = d }
        if kCategories.contains(r.category) { category = r.category }
        if kAccounts.contains(r.account) { account = r.account }
        if !r.note.isEmpty { note = r.note }

        var parts: [String] = []
        if !r.merchant.isEmpty { parts.append(r.merchant) }
        if r.amount != 0 { parts.append("¥" + Fmt.money(abs(r.amount))) }
        parts.append(r.category)
        parts.append(r.account)
        hint = "已识别：" + parts.joined(separator: " · ") + "，不对就直接改。"
    }

    private func applyVoice(_ r: VoiceParser.Result) {
        if let value = r.amount, value > 0 {
            amountText = String(format: "%.2f", value)
        }
        isIncome = r.isIncome
        if !r.merchant.isEmpty { merchant = r.merchant }
        if kCategories.contains(r.category) { category = r.category }
        if kAccounts.contains(r.account) { account = r.account }
        if !r.note.isEmpty { note = r.note }

        var parts: [String] = []
        if !r.merchant.isEmpty { parts.append(r.merchant) }
        if let value = r.amount, value > 0 { parts.append("¥" + Fmt.money(value)) }
        parts.append(r.category)
        parts.append(r.account)
        hint = "语音已填入：" + parts.joined(separator: " · ") + "，确认后保存。"
    }

    private func save() {
        let cleaned = amountText
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned), value > 0 else {
            errorText = "金额要填一个大于 0 的数字。"
            return
        }

        let signed = isIncome ? -abs(value) : abs(value)
        let cat = kCategories.contains(category) ? category : "其他"
        let acc = kAccounts.contains(account) ? account : "现金"
        let name = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let memo = note.trimmingCharacters(in: .whitespacesAndNewlines)

        var imageName = txn?.image
        if imageDirty {
            if let data = image?.jpegData(compressionQuality: 0.6), let saved = store.saveImage(data) {
                if let old = txn?.image { store.removeImage(old) }
                imageName = saved
            } else {
                if let old = txn?.image { store.removeImage(old) }
                imageName = nil
            }
        }

        if var t = txn {
            t.date = date
            t.amount = signed
            t.merchant = name
            t.note = memo
            t.category = cat
            t.account = acc
            t.image = imageName
            store.update(t)
        } else {
            store.add(Txn(
                date: date,
                amount: signed,
                merchant: name,
                note: memo,
                category: cat,
                account: acc,
                image: imageName
            ))
        }

        UserDefaults.standard.set(acc, forKey: "aibill.lastAccount")
        Budget.check(store.items)
        dismiss()
    }
}
