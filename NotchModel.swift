import SwiftUI
import Observation

/// الأوضاع كما تظهر في فيديو Apple بالترتيب.
enum NotchMode: Equatable {
    case idle        // النوتش العادي
    case call        // مكالمة واردة: صورة + اسم + رفض/قبول
    case indicator   // نقطة خضراء (الكاميرا/الميكروفون قيد الاستخدام)
    case recording   // 0:00 على اليسار وموجة خضراء على اليمين
    case music       // يتمدد للأسفل: غلاف + اسم + شريط + أزرار
    case faceID      // رمز Face ID ← حلقة خضراء ← وجه مبتسم
}

enum FaceStage { case glyph, scanning, success }

@MainActor
@Observable
final class NotchModel {
    var mode: NotchMode = .idle
    var faceStage: FaceStage = .glyph
    var callerName = "Michael"

    // أبعاد النوتش (قابلة للمعايرة)
    var notchWidth: CGFloat = 162
    var notchHeight: CGFloat = 33
    var topOffset: CGFloat = 0
    var screenWidth: CGFloat = 390

    let music = MusicService()
    let recorder = RecorderService()

    private var autoTask: Task<Void, Never>?
    private var demoTask: Task<Void, Never>?

    /// تقدير أبعاد النوتش من safe area العلوية.
    func configure(inset: CGFloat, width: CGFloat) {
        screenWidth = width
        switch inset {
        case 59...:   notchWidth = 126; notchHeight = 37; topOffset = 11   // Dynamic Island
        case 44, 48:  notchWidth = 209; notchHeight = 30; topOffset = 0    // X / XS / 11
        default:      notchWidth = 162; notchHeight = 33; topOffset = 0    // 12 / 13 / 14
        }
    }

    // MARK: الأحجام (نسب مأخوذة من لقطات الفيديو)

    var size: CGSize {
        let w = notchWidth, h = notchHeight
        let maxW = screenWidth - 24
        switch mode {
        case .idle:      return CGSize(width: w, height: h)
        case .indicator: return CGSize(width: w + 34, height: h)
        case .recording: return CGSize(width: min(maxW, w * 1.85), height: h + 4)
        case .call:      return CGSize(width: min(maxW, w * 1.85), height: h + 14)
        case .music:     return CGSize(width: min(maxW, w * 1.6),  height: h + 72)
        case .faceID:    return CGSize(width: min(maxW, w * 1.35), height: h + 52)
        }
    }

    var cornerRadius: CGFloat {
        let base: CGFloat
        switch mode {
        case .idle, .indicator: base = 12
        case .recording:        base = 14
        case .call:             base = 16
        case .music, .faceID:   base = 18
        }
        return topOffset > 0 ? base + 8 : base
    }

    // MARK: التحكم

    /// عند اختيار المستخدم يدوياً يتوقف العرض التلقائي.
    func show(_ newMode: NotchMode) {
        demoTask?.cancel()
        present(newMode, simulated: false)
    }

    func toggle() { show(mode == .idle ? .music : .idle) }

    private func present(_ newMode: NotchMode, simulated: Bool) {
        autoTask?.cancel()
        if mode == .recording && newMode != .recording { recorder.stop() }

        switch newMode {
        case .idle, .indicator, .call:
            mode = newMode
        case .music:
            music.start()
            mode = .music
        case .recording:
            if simulated {
                recorder.startSimulated()
                mode = .recording
            } else {
                autoTask = Task { if await recorder.start() { mode = .recording } }
            }
        case .faceID:
            faceStage = .glyph
            mode = .faceID
            autoTask = Task {
                try? await Task.sleep(for: .seconds(1.0))
                guard !Task.isCancelled else { return }
                faceStage = .scanning
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                faceStage = .success
                try? await Task.sleep(for: .seconds(1.3))
                guard !Task.isCancelled else { return }
                mode = .idle
            }
        }
    }

    /// يعيد تسلسل الفيديو كاملاً.
    func playDemo() {
        demoTask?.cancel()
        let steps: [(NotchMode, Double, Bool)] = [
            (.idle, 0.8, false),
            (.call, 2.4, false),
            (.idle, 0.7, false),
            (.indicator, 1.5, false),
            (.recording, 3.2, true),
            (.idle, 0.7, false),
            (.music, 4.2, false),
            (.idle, 0.7, false),
            (.indicator, 1.2, false),
            (.faceID, 4.4, false),
            (.idle, 0.5, false),
        ]
        demoTask = Task {
            for (m, d, sim) in steps {
                guard !Task.isCancelled else { return }
                present(m, simulated: sim)
                try? await Task.sleep(for: .seconds(d))
            }
        }
    }
}
