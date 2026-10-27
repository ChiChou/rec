import AppKit
import RecCore
import SwiftUI

/// Floating controls shown above the target window while the main window is out of the way.
/// It is a separate window, so it never appears in the window-only recording.
@MainActor
final class RecordingBar {
    private unowned let model: AppModel
    private var panel: NSPanel?

    init(model: AppModel) {
        self.model = model
    }

    /// `frame` is the target window in Quartz (top-left origin) coordinates.
    func show(near frame: CGRect) {
        let size = CGSize(width: 300, height: 52)
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let window = Geometry.flip(frame, primaryScreenHeight: primaryHeight)
        let screen = NSScreen.screens.first { $0.frame.contains(CGPoint(x: window.midX, y: window.midY)) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? window

        // Sit just above the window if there is room, otherwise at the top of the screen.
        var origin = CGPoint(x: window.midX - size.width / 2, y: window.maxY + 10)
        if origin.y + size.height > visible.maxY {
            origin.y = visible.maxY - size.height - 10
        }
        origin.x = min(max(origin.x, visible.minX + 10), visible.maxX - size.width - 10)

        let panel = panel ?? makePanel()
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = FloatingPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = FirstMouseHostingView(rootView: RecordingBarView().environmentObject(model))
        return panel
    }
}

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Lets buttons in floating panels work on the first click without activating Rec.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private struct RecordingBarView: View {
    @EnvironmentObject var model: AppModel
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 10, height: 10)
                .opacity(pulse ? 0.35 : 1)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: pulse)
                .onAppear { pulse = true }

            switch model.phase {
            case .countdown(let n):
                Text("Starting in \(n)")
                    .font(Theme.font(13, .bold).monospacedDigit())
                Spacer()
                Button("Cancel") { model.cancelCountdown() }
                    .buttonStyle(PillButtonStyle(fill: Theme.cardHover))
            case .recording(let since):
                TimelineView(.periodic(from: since, by: 1)) { context in
                    Text(elapsed(from: since, to: context.date))
                        .font(Theme.font(15, .heavy).monospacedDigit())
                }
                Text(model.preset.name)
                    .font(Theme.font(11))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                Spacer()
                Button {
                    model.stopRecording()
                } label: {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2).fill(.white).frame(width: 8, height: 8)
                        Text("Stop")
                    }
                }
                .buttonStyle(PillButtonStyle(fill: Theme.accent))
            case .saving:
                Text("Saving…").font(Theme.font(13, .bold))
                Spacer()
                ProgressView().controlSize(.small)
            case .idle:
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.opacity(0.94), in: Capsule())
        .foregroundStyle(Theme.text)
        .environment(\.colorScheme, .dark)
    }
}

func elapsed(from start: Date, to now: Date) -> String {
    let s = max(0, Int(now.timeIntervalSince(start)))
    return String(format: "%02d:%02d", s / 60, s % 60)
}
