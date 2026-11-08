import SwiftUI

struct QuickAddView: View {
    @EnvironmentObject var store: Store
    @Environment(\.presentationMode) var presentation

    @State private var text = ""
    @State private var listIndex = 0
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var ocrText = ""
    @State private var parsing = false

    private var parsed: NLU.Result? { NLU.parse(text) }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("一句话：明天下午3点交房租")
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $text)
                            .frame(minHeight: 90)
                            .opacity(text.isEmpty ? 0.25 : 1)
                    }
                } header: {
                    Text("说一句就行")
                } footer: {
                    Text("支持：明天/后天/周X/下周X、M月D日、上午下午晚上、3点/15:30/3点半、每天/每周/工作日")
                }

                if !text.isEmpty, let p = parsed {
                    Section("识别结果") {
                        HStack {
                            Text("标题")
                            Spacer()
                            Text(p.title).foregroundColor(.secondary).lineLimit(1)
                        }
                        HStack {
                            Text("时间")
                            Spacer()
                            Text(p.due.map { fmt($0) } ?? "不设时间").foregroundColor(.secondary)
                        }
                        if p.repeatRule != .none {
                            HStack {
                                Text("重复")
                                Spacer()
                                Text(p.repeatRule.label).foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showCamera = true
                    } label: {
                        Label("拍照识别", systemImage: "camera")
                    }
                    Button {
                        showLibrary = true
                    } label: {
                        Label("从相册识别", systemImage: "photo")
                    }
                    if parsing {
                        HStack { ProgressView(); Text("识别中…").foregroundColor(.secondary) }
                    }
                    if !ocrText.isEmpty {
                        Text(ocrText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(4)
                    }
                } header: {
                    Text("图片识别（本机 OCR，不联网）")
                }

                Section("存到哪个清单") {
                    Picker("清单", selection: $listIndex) {
                        ForEach(Array(store.lists.enumerated()), id: \.offset) { i, l in
                            Text(l.name).tag(i)
                        }
                    }
                }
            }
            .navigationTitle("快速添加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentation.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(source: .camera) { img in handleImage(img) }
            }
            .sheet(isPresented: $showLibrary) {
                ImagePicker(source: .photoLibrary) { img in handleImage(img) }
            }
        }
    }

    private func handleImage(_ img: UIImage) {
        parsing = true
        OCR.recognize(img) { recognized in
            parsing = false
            ocrText = recognized
            if let line = OCR.bestLineForDate(recognized) {
                text = line
            } else if !recognized.isEmpty {
                text = recognized.split(separator: "\n").prefix(2).joined(separator: " ")
            }
        }
    }

    private func save() {
        guard !store.lists.isEmpty else { return }
        let idx = min(listIndex, store.lists.count - 1)
        let listID = store.lists[idx].id
        let p = parsed
        store.addTask(listID: listID,
                      title: p?.title ?? text,
                      dueAt: p?.due,
                      note: "",
                      repeatRule: p?.repeatRule ?? .none)
        presentation.wrappedValue.dismiss()
    }

    private func fmt(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: d)
    }
}
