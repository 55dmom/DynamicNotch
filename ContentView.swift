import SwiftUI

@main
struct DynamicNotchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @State private var model = NotchModel()

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // خلفية بنفسجية مثل الفيديو
                LinearGradient(
                    colors: [Color(red: 0.42, green: 0.14, blue: 0.92),
                             Color(red: 0.66, green: 0.40, blue: 0.95),
                             Color(red: 0.55, green: 0.25, blue: 0.85)],
                    startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        Spacer().frame(height: geo.safeAreaInsets.top + 60)

                        Text("dynamic **notch**")
                            .font(.system(size: 30, weight: .regular))
                        Text("اضغط على النوتش أو اختر وضعاً")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.75))
                            .padding(.bottom, 6)

                        ModeButton(title: "تشغيل عرض الفيديو كاملاً", icon: "play.fill", prominent: true) { model.playDemo() }
                        ModeButton(title: "مكالمة واردة", icon: "phone.fill") { model.show(.call) }
                        ModeButton(title: "مؤشر الكاميرا / الميكروفون", icon: "circle.fill") { model.show(.indicator) }
                        ModeButton(title: "تسجيل صوت (ميكروفون حقيقي)", icon: "mic.fill") { model.show(.recording) }
                        ModeButton(title: "الموسيقى", icon: "music.note") { model.show(.music) }
                        ModeButton(title: "Face ID", icon: "faceid") { model.show(.faceID) }
                        ModeButton(title: "إخفاء", icon: "xmark") { model.show(.idle) }

                        calibration
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)

                NotchOverlayView(model: model)
                    .ignoresSafeArea(edges: .top)
            }
            .onAppear {
                model.configure(inset: geo.safeAreaInsets.top, width: geo.size.width)
            }
        }
    }

    /// معايرة: طابق الشكل الأسود مع النوتش الحقيقي بالضبط.
    private var calibration: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("معايرة حجم النوتش").font(.footnote.weight(.semibold))
            HStack {
                Text("العرض").font(.caption).frame(width: 50, alignment: .leading)
                Slider(value: Binding(get: { model.notchWidth }, set: { model.notchWidth = $0 }), in: 100...240)
            }
            HStack {
                Text("الارتفاع").font(.caption).frame(width: 50, alignment: .leading)
                Slider(value: Binding(get: { model.notchHeight }, set: { model.notchHeight = $0 }), in: 24...44)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.top, 12)
    }
}

struct ModeButton: View {
    let title: String
    let icon: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).frame(width: 28)
                Text(title).font(.system(size: 16, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(height: 50)
            .background(prominent ? AnyShapeStyle(Color.white.opacity(0.28)) : AnyShapeStyle(.ultraThinMaterial),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
