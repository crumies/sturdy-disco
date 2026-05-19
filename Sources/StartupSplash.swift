import SwiftUI

struct StartupSplash: View {
    @State private var scale = 0.84
    @State private var glow = false

    var body: some View {
        ZStack {
            AppBackground()
            Circle()
                .fill(.cyan.opacity(glow ? 0.22 : 0.08))
                .blur(radius: 80)
                .frame(width: glow ? 360 : 220)

            VStack(spacing: 18) {
                AptumLogoImage()
                    .frame(width: 275, height: 95)
                    .scaleEffect(scale)
                    .shadow(color: .cyan.opacity(glow ? 0.45 : 0.15), radius: glow ? 28 : 10)

                Text("Always Progressing Toward Ultimate Mobility")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan.opacity(0.9))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) { scale = 1.0 }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}
