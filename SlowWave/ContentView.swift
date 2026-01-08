import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.07, blue: 0.1), Color(red: 0.02, green: 0.02, blue: 0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(appState.state.displayText)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .font(.system(size: 14, weight: .medium))

                ListeningIndicatorView(isActive: appState.isListening)
            }
        }
        .onAppear { appState.start() }
        .onDisappear { appState.stop() }
        .onChange(of: scenePhase) { _, newPhase in
            appState.handleScenePhase(newPhase)
        }
    }
}

private struct ListeningIndicatorView: View {
    let isActive: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 120, height: 120)
                .scaleEffect(pulse ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)

            Circle()
                .fill(isActive ? Color.white.opacity(0.7) : Color.white.opacity(0.35))
                .frame(width: 40, height: 40)
        }
        .onAppear { pulse = true }
    }
}

extension SleepState {
    var displayText: String {
        switch self {
        case .guiding:
            return "Listening"
        case .play:
            return "Drifting"
        case .silent:
            return "Quiet"
        }
    }
}
