import Foundation
import SwiftUI
import AVFoundation
import Speech

// MARK: - 语音识别

final class SpeechEngine: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var errorText: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audio = AVAudioEngine()
    private var tapInstalled = false

    func start() {
        transcript = ""
        errorText = nil
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self.errorText = "没有语音识别权限，去 设置 → 票记 打开"
                    return
                }
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        guard granted else {
                            self.errorText = "没有麦克风权限，去 设置 → 票记 打开"
                            return
                        }
                        self.begin()
                    }
                }
            }
        }
    }

    private func begin() {
        guard let recognizer, recognizer.isAvailable else {
            errorText = "语音识别暂不可用，稍后再试"
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            request = req

            let input = audio.inputNode
            if tapInstalled {
                input.removeTap(onBus: 0)
                tapInstalled = false
            }
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                req.append(buffer)
            }
            tapInstalled = true
            audio.prepare()
            try audio.start()

            task = recognizer.recognitionTask(with: req) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    DispatchQueue.main.async { self.transcript = text }
                }
                if error != nil || (result?.isFinal ?? false) {
                    DispatchQueue.main.async { self.stop() }
                }
            }
            isRecording = true
        } catch {
            errorText = "麦克风启动失败：\(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        if audio.isRunning { audio.stop() }
        if tapInstalled {
            audio.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - 口语解析

enum VoiceParser {
    struct Result {
        var amount: Double?
        var category: String
        var merchant: String
        var type: TxType
    }

    private static let digits: [Character: Int] = [
        "零": 0, "〇": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
        "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
    ]
    private static let units: [Character: Int] = ["十": 10, "百": 100, "千": 1000, "万": 10000]
    private static let numeralSet = Set("零〇一二两三四五六七八九十百千万")

    static func parse(_ raw: String) -> Result {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalize(text)

        var type: TxType = .expense
        for w in ["收入", "工资", "奖金", "报销", "退款", "进账", "收到", "赚了"] where text.contains(w) {
            type = .income
            break
        }

        let amount = findAmount(normalized)
        let category = Categories.guess(from: text)

        var merchant = text
        for w in ["花了", "花费", "花", "买了", "买", "付了", "支付", "支出", "收入", "块钱", "块", "元", "钱",
                  "今天", "昨天", "刚才", "上午", "下午", "晚上", "中午", "一共", "总共"] {
            merchant = merchant.replacingOccurrences(of: w, with: " ")
        }
        merchant = merchant.replacingOccurrences(of: #"\d+(\.\d+)?"#, with: " ", options: .regularExpression)
        merchant = merchant.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        merchant = merchant.trimmingCharacters(in: .whitespaces)

        return Result(amount: amount, category: category, merchant: merchant, type: type)
    }

    private static func findAmount(_ text: String) -> Double? {
        let pattern = #"\d+(?:\.\d{1,2})?"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        let all = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !all.isEmpty else { return nil }

        var best: Double?
        for m in all {
            let s = ns.substring(with: m.range)
            guard let v = Double(s), v > 0, v < 1_000_000 else { continue }
            let after = ns.substring(from: min(m.range.upperBound + 1, ns.length))
            if after.hasPrefix("块") || after.hasPrefix("元") { return v }
            best = max(best ?? 0, v)
        }
        return best
    }

    /// 把「三十五」「两百」这类中文数字换成阿拉伯数字
    private static func normalize(_ text: String) -> String {
        var out = ""
        var run = ""
        for ch in text {
            if numeralSet.contains(ch) {
                run.append(ch)
            } else {
                if !run.isEmpty {
                    out += String(value(of: run))
                    run = ""
                }
                out.append(ch)
            }
        }
        if !run.isEmpty { out += String(value(of: run)) }
        return out
    }

    private static func value(of s: String) -> Int {
        var total = 0
        var section = 0
        var number = 0
        for ch in s {
            if let d = digits[ch] {
                number = d
            } else if let u = units[ch] {
                if u == 10000 {
                    section = (section + number) * u
                    total += section
                    section = 0
                } else {
                    section += (number == 0 ? 1 : number) * u
                }
                number = 0
            }
        }
        let v = total + section + number
        return v == 0 ? 0 : v
    }
}

// MARK: - 语音录入面板

struct VoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onResult: (VoiceParser.Result) -> Void

    @StateObject private var engine = SpeechEngine()

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: engine.isRecording ? "waveform" : "mic.circle")
                .font(.system(size: 62))
                .foregroundColor(engine.isRecording ? .red : .secondary)

            Text(engine.transcript.isEmpty
                 ? (engine.isRecording ? "说一句话，比如「午饭三十五」" : "点下面的按钮开始")
                 : engine.transcript)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .frame(minHeight: 60)

            if let err = engine.errorText {
                Text(err)
                    .font(.footnote)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            HStack(spacing: 14) {
                Button("取消") {
                    engine.stop()
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button(engine.isRecording ? "说完了" : "开始说话") {
                    if engine.isRecording {
                        engine.stop()
                        let r = VoiceParser.parse(engine.transcript)
                        if r.amount != nil || !r.merchant.isEmpty {
                            onResult(r)
                        }
                        dismiss()
                    } else {
                        engine.start()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(engine.transcript.isEmpty && !engine.isRecording && engine.errorText != nil)
            }
            .padding(.bottom, 28)
        }
        .onAppear { engine.start() }
        .onDisappear { engine.stop() }
    }
}
