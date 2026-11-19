import SwiftUI

/// الشكل الأسود الذي يتمدد من مكان النوتش (نفس سلوك فيديو Apple).
struct NotchOverlayView: View {
    var model: NotchModel

    private let spring = Animation.spring(response: 0.5, dampingFraction: 0.78)

    var body: some View {
        let size = model.size

        ZStack(alignment: .top) {
            switch model.mode {
            case .idle:
                Color.clear
            case .call:
                CallView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
            case .indicator:
                IndicatorView()
                    .transition(.opacity)
            case .recording:
                RecordingView(recorder: model.recorder, notchWidth: model.notchWidth)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
            case .music:
                MusicView(music: model.music, topInset: model.notchHeight)
                    .transition(.opacity.combined(with: .scale(scale: 0.88, anchor: .top)))
            case .faceID:
                FaceIDView(stage: model.faceStage, topInset: model.notchHeight)
                    .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(Color.black)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: model.cornerRadius,
                                          bottomTrailingRadius: model.cornerRadius,
                                          style: .continuous))
        .animation(spring, value: model.mode)
        .animation(spring, value: model.notchWidth)
        .animation(spring, value: model.notchHeight)
        .animation(.easeInOut(duration: 0.25), value: model.faceStage)
        .padding(.top, model.topOffset)
        .onTapGesture { model.toggle() }
    }
}

// MARK: - مكالمة واردة

struct CallView: View {
    var model: NotchModel

    var body: some View {
        ZStack {
            HStack {
                Circle()
                    .fill(LinearGradient(colors: [.gray, Color(white: 0.35)], startPoint: .top, endPoint: .bottom))
                    .overlay(Image(systemName: "person.fill").font(.system(size: 11)).foregroundStyle(.white))
                    .frame(width: 22, height: 22)
                Spacer()
                HStack(spacing: 8) {
                    callButton("phone.down.fill", .red)
                    callButton("phone.fill", .green)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: model.notchHeight, alignment: .center)
            .frame(maxHeight: .infinity, alignment: .top)

            Text(model.callerName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 3)
        }
    }

    private func callButton(_ icon: String, _ color: Color) -> some View {
        Button { model.show(.idle) } label: {
            Circle().fill(color).frame(width: 20, height: 20)
                .overlay(Image(systemName: icon).font(.system(size: 9, weight: .bold)).foregroundStyle(.white))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - مؤشر الكاميرا / الميكروفون

struct IndicatorView: View {
    @State private var pulse = false

    var body: some View {
        HStack {
            Spacer()
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .shadow(color: .green.opacity(0.8), radius: pulse ? 5 : 1)
                .padding(.trailing, 10)
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

// MARK: - تسجيل صوت: 0:00 يساراً وموجة خضراء يميناً

struct RecordingView: View {
    var recorder: RecorderService
    var notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Text(recorder.text)
                .font(.system(size: 13, weight: .regular).monospacedDigit())
                .foregroundStyle(Color(red: 0.35, green: 0.95, blue: 0.45))
                .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear.frame(width: notchWidth - 10)

            HStack(spacing: 1.8) {
                ForEach(recorder.levels.indices, id: \.self) { i in
                    Capsule()
                        .fill(Color(red: 0.35, green: 0.95, blue: 0.45))
                        .frame(width: 1.8, height: max(3, recorder.levels[i] * 16))
                }
            }
            .frame(height: 18)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - الموسيقى

struct MusicView: View {
    var music: MusicService
    var topInset: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            Color.clear.frame(height: max(0, topInset - 6))

            HStack(spacing: 8) {
                Group {
                    if let art = music.artwork {
                        Image(uiImage: art).resizable().scaledToFill()
                    } else {
                        LinearGradient(colors: [Color(red: 1, green: 0.15, blue: 0.2), Color(red: 0.25, green: 0, blue: 0.05)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                VStack(alignment: .leading, spacing: 0) {
                    Text(music.title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                    Text(music.artist).font(.system(size: 9)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                }
                Spacer(minLength: 6)
                EqualizerBars(active: music.isPlaying)
            }

            HStack(spacing: 6) {
                Text(music.elapsed).font(.system(size: 8).monospacedDigit()).foregroundStyle(.white.opacity(0.5))
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(.white).frame(width: max(0, g.size.width * music.progress))
                    }
                }
                .frame(height: 3)
                Text(music.remaining).font(.system(size: 8).monospacedDigit()).foregroundStyle(.white.opacity(0.5))
            }

            HStack(spacing: 30) {
                Button { music.previous() } label: { Image(systemName: "backward.fill") }
                Button { music.toggle() } label: { Image(systemName: music.isPlaying ? "pause.fill" : "play.fill") }
                Button { music.next() } label: { Image(systemName: "forward.fill") }
            }
            .font(.system(size: 14))
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

/// موجة حمراء صغيرة بجانب اسم الأغنية.
struct EqualizerBars: View {
    var active: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 1.5) {
                ForEach(0..<9, id: \.self) { i in
                    let h = active ? 4 + 9 * abs(sin(t * 6 + Double(i) * 1.3)) : 3
                    Capsule().fill(Color(red: 1, green: 0.25, blue: 0.3))
                        .frame(width: 1.8, height: h)
                }
            }
            .frame(height: 14)
        }
    }
}

// MARK: - Face ID: رمز ← حلقة خضراء ← وجه مبتسم

struct FaceIDView: View {
    var stage: FaceStage
    var topInset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset - 4)
            ZStack {
                switch stage {
                case .glyph:
                    Image(systemName: "faceid")
                        .font(.system(size: 30, weight: .ultraLight))
                        .foregroundStyle(.white)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                case .scanning:
                    ScanRing()
                        .transition(.opacity)
                case .success:
                    Image(systemName: "face.smiling")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(Color(red: 0.3, green: 0.95, blue: 0.45))
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

/// حلقة خضراء تدور ثلاثية الأبعاد أثناء المسح.
struct ScanRing: View {
    @State private var angle = 0.0

    var body: some View {
        ZStack {
            Ellipse()
                .stroke(Color(red: 0.3, green: 0.95, blue: 0.45), lineWidth: 2)
                .frame(width: 26, height: 26)
                .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0))
            Ellipse()
                .stroke(Color(red: 0.3, green: 0.95, blue: 0.45).opacity(0.5), lineWidth: 1.5)
                .frame(width: 26, height: 26)
                .rotation3DEffect(.degrees(angle + 90), axis: (x: 1, y: 0, z: 0))
        }
        .onAppear {
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { angle = 360 }
        }
    }
}
