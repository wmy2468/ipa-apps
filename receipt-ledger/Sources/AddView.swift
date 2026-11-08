import SwiftUI
import PhotosUI
import UIKit

struct TxFields: View {
    @Binding var tx: Tx

    var body: some View {
        Group {
            Section {
                Picker("类型", selection: $tx.type) {
                    ForEach(TxType.allCases) { t in
                        Text(t.title).tag(t)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                HStack(spacing: 6) {
                    Text("¥")
                        .foregroundColor(.secondary)
                        .font(.title3)
                    TextField("0.00", value: $tx.amount, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 28, weight: .semibold))
                }
                Picker("分类", selection: $tx.category) {
                    ForEach(Categories.list(for: tx.type), id: \.self) { c in
                        Text(c).tag(c)
                    }
                }
                Picker("账户", selection: $tx.account) {
                    ForEach(Accounts.list, id: \.self) { a in
                        Text(a).tag(a)
                    }
                }
                DatePicker("日期", selection: $tx.date, displayedComponents: [.date])
            }

            Section {
                TextField("商户", text: $tx.merchant)
                TextField("备注", text: $tx.note)
            }
        }
        .onChange(of: tx.type) { newValue in
            if !Categories.list(for: newValue).contains(tx.category) {
                tx.category = "其他"
            }
        }
    }
}

struct AddView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var draft = Tx()
    @State private var imageData: Data?
    @State private var isParsing = false
    @State private var message: String?
    @State private var showCamera = false
    @State private var showVoice = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let data = imageData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(maxWidth: .infinity)
                    }

                    HStack(spacing: 12) {
                        Button {
                            showCamera = true
                        } label: {
                            Label("拍照识别", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("相册", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        showVoice = true
                    } label: {
                        Label("语音说一句", systemImage: "mic.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isParsing)

                    if isParsing {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("正在识别小票…")
                                .foregroundColor(.secondary)
                        }
                    }

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                } header: {
                    Text("小票")
                }

                TxFields(tx: $draft)
            }
            .navigationTitle("记一笔")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("清空") { reset() }
                        .disabled(isParsing)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(isParsing)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker { data in
                    imageData = data
                    runOCR(data)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showVoice) {
                VoiceSheet { result in
                    if let a = result.amount { draft.amount = a }
                    draft.type = result.type
                    draft.category = result.category
                    if !result.merchant.isEmpty { draft.merchant = result.merchant }
                    message = result.amount == nil ? "没听出金额，手动补一下" : "语音识别完成，核对一下"
                }
            }
            .onChange(of: photoItem) { item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        imageData = data
                        runOCR(data)
                    }
                }
            }
        }
    }

    private func runOCR(_ data: Data) {
        isParsing = true
        message = nil
        Task {
            do {
                let text = try await OCRService.recognize(imageData: data)
                var parsed = ReceiptParser.parse(text: text)

                let config = AIConfig.load()
                if config.enabled, let ai = try? await AIRefiner.refine(ocrText: text, config: config) {
                    parsed.amount = ai.amount ?? parsed.amount
                    parsed.merchant = ai.merchant ?? parsed.merchant
                    parsed.date = ai.date ?? parsed.date
                    if parsed.category == "其他" { parsed.category = ai.category }
                }

                await MainActor.run {
                    if let a = parsed.amount { draft.amount = a }
                    if let m = parsed.merchant, !m.isEmpty { draft.merchant = m }
                    if let d = parsed.date { draft.date = d }
                    draft.category = parsed.category
                    isParsing = false
                    message = parsed.amount == nil ? "没认出金额，手动补一下" : "识别完成，核对一下再保存"
                }
            } catch {
                await MainActor.run {
                    isParsing = false
                    message = "识别失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func save() {
        guard draft.amount > 0 else {
            message = "金额要大于 0"
            return
        }
        store.add(draft)
        reset()
        dismiss()
    }

    private func reset() {
        draft = Tx()
        imageData = nil
        photoItem = nil
        message = nil
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.85) {
                parent.onImage(data)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
