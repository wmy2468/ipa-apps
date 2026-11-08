import Foundation
import UIKit
import Vision

enum OCR {
    /// 识别图片文字（本机 Vision，不联网）
    static func recognize(_ image: UIImage, completion: @escaping (String) -> Void) {
        guard let cg = image.cgImage else { completion(""); return }
        let request = VNRecognizeTextRequest { req, _ in
            let lines = (req.results as? [VNRecognizedTextObservation] ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
            completion(lines.joined(separator: "\n"))
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do { try handler.perform([request]) }
            catch { DispatchQueue.main.async { completion("") } }
        }
    }

    /// 从识别文本里挑出最像"日期时间"的一行，交给 NLU
    static func bestLineForDate(_ text: String) -> String? {
        let lines = text.split(separator: "\n").map(String.init)
        let patterns = [#"\d{1,2}月\d{1,2}[日号]?"#, #"\d{1,2}[:：]\d{2}"#, #"\d{4}[-/]\d{1,2}[-/]\d{1,2}"#]
        for line in lines {
            for p in patterns where line.range(of: p, options: .regularExpression) != nil {
                return line
            }
        }
        return nil
    }
}
