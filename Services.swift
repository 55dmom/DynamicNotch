import SwiftUI
import Observation
import MediaPlayer
import AVFoundation

func formatTime(_ t: TimeInterval) -> String {
    let s = max(0, Int(t.rounded(.down)))
    return String(format: "%d:%02d", s / 60, s % 60)
}

// MARK: - الموسيقى (مشغّل النظام، مع عرض تجريبي مطابق للفيديو)

@MainActor
@Observable
final class MusicService {
    var title = "Dolgoch tape"
    var artist = "Clark"
    var artwork: UIImage?
    var isPlaying = true
    var progress: Double = 118.0 / 179.0
    var elapsed = "1:58"
    var remaining = "-1:01"

    private let player = MPMusicPlayerController.systemMusicPlayer
    private var poll: Timer?
    private var demoElapsed: TimeInterval = 118
    private let demoTotal: TimeInterval = 179

    func start() {
        if MPMediaLibrary.authorizationStatus() == .notDetermined {
            MPMediaLibrary.requestAuthorization { _ in }
        }
        demoElapsed = 118
        refresh()
        guard poll == nil else { return }
        poll = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func refresh() {
        if let item = player.nowPlayingItem {
            title = item.title ?? "—"
            artist = item.artist ?? ""
            artwork = item.artwork?.image(at: CGSize(width: 120, height: 120))
            let d = item.playbackDuration
            let t = player.currentPlaybackTime
            progress = d > 0 ? min(1, max(0, t / d)) : 0
            elapsed = formatTime(t)
            remaining = "-" + formatTime(d - t)
            isPlaying = player.playbackState == .playing
        } else if isPlaying {
            demoElapsed = min(demoTotal, demoElapsed + 0.5)
            progress = demoElapsed / demoTotal
            elapsed = formatTime(demoElapsed)
            remaining = "-" + formatTime(demoTotal - demoElapsed)
        }
    }

    func toggle() {
        if player.nowPlayingItem != nil {
            let was = player.playbackState == .playing
            if was { player.pause() } else { player.play() }
            isPlaying = !was
        } else {
            isPlaying.toggle()
        }
    }
    func next() { if player.nowPlayingItem != nil { player.skipToNextItem() } }
    func previous() { if player.nowPlayingItem != nil { player.skipToPreviousItem() } }
}

// MARK: - تسجيل الصوت (حقيقي أو محاكى للعرض)

@MainActor
@Observable
final class RecorderService {
    static let barCount = 16
    var levels: [CGFloat] = Array(repeating: 0.12, count: RecorderService.barCount)
    var elapsed: TimeInterval = 0
    var text: String { formatTime(elapsed) }

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var simStart = Date()

    func start() async -> Bool {
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else { return false }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("notch-recording.m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1
        ]
        guard let rec = try? AVAudioRecorder(url: url, settings: settings) else { return false }
        rec.isMeteringEnabled = true
        rec.record()
        recorder = rec
        elapsed = 0
        schedule()
        return true
    }

    func startSimulated() {
        recorder = nil
        elapsed = 0
        simStart = Date()
        schedule()
    }

    private func schedule() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        let level: CGFloat
        if let rec = recorder {
            rec.updateMeters()
            let power = rec.averagePower(forChannel: 0)          // -160 ... 0 dB
            level = CGFloat(max(0.1, min(1, (power + 50) / 50)))
            elapsed = rec.currentTime
        } else {
            elapsed = Date().timeIntervalSince(simStart)
            level = CGFloat(0.25 + 0.7 * Double.random(in: 0...1) * abs(sin(elapsed * 5)))
        }
        levels.removeFirst()
        levels.append(level)
    }

    func stop() {
        meterTimer?.invalidate()
        meterTimer = nil
        if recorder != nil {
            recorder?.stop()
            recorder = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        levels = Array(repeating: 0.12, count: RecorderService.barCount)
    }
}
