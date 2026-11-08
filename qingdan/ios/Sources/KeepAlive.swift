import Foundation
import AVFoundation

/// 后台保活：循环播放静音音频，配合 Info.plist 的 UIBackgroundModes=audio
/// 开启后 App 能留在后台按秒计时，催促可以无限延续；代价是略耗电
final class KeepAlive {
    static let shared = KeepAlive()
    private var player: AVAudioPlayer?

    var isRunning: Bool { player?.isPlaying == true }

    func start() {
        guard !isRunning else { return }
        guard let url = Bundle.main.url(forResource: "silence", withExtension: "wav") else {
            print("找不到 silence.wav")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])

            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 0
            p.prepareToPlay()
            p.play()
            player = p
        } catch {
            print("保活启动失败: \(error)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
