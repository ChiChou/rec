import AppKit
import RecCore
import SwiftUI

/// A badge centered over the target window during the countdown, with a warning when the
/// window could not take the video's aspect ratio and a button to cancel. Only the target
/// window is captured, so the badge never appears in the video.
@MainActor
final class CountdownHUD {
    private var panel: NSPanel?
    private var state: CountdownState?

    /// `frame` is in Quartz (top-left origin) coordinates.
    func show(_ number: Int, warning: String?, over frame: CGRect, onCancel: @escaping () -> Void) {
        let size = CGSize(width: warning == nil ? 200 : 300, height: warning == nil ? 250 : 330)
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let target = Geometry.centered(size, in: Geometry.flip(frame, primaryScreenHeight: primaryHeight))

        if let panel, let state {
            panel.setFrame(target, display: true)
            state.tick(number)
            return
        }

        let state = CountdownState(number: number, warning: warning)
        let panel = FloatingPanel(contentRect: target, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = FirstMouseHostingView(rootView: CountdownBadge(state: state, onCancel: onCancel))
        panel.orderFrontRegardless()
        self.panel = panel
        self.state = state
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        state = nil
    }
}

@MainActor
final class CountdownState: ObservableObject {
    @Published var number: Int
    let warning: String?

    init(number: Int, warning: String?) {
        self.number = number
        self.warning = warning
    }

    func tick(_ number: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { self.number = number }
    }
}

struct CountdownBadge: View {
    @ObservedObject var state: CountdownState
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("\(state.number)")
                .font(Theme.font(84, .heavy).monospacedDigit())
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText(countsDown: true))
                .id(state.number)
                .transition(.scale(scale: 1.6).combined(with: .opacity))
                .frame(height: 100)
            if let warning = state.warning {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.warn)
                    Text(warning)
                        .font(Theme.font(11.5, .medium))
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button("Cancel", action: onCancel)
                .buttonStyle(BigButtonStyle(fill: Theme.card, foreground: Theme.text))
                .keyboardShortcut(.cancelAction)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.opacity(0.92), in: RoundedRectangle(cornerRadius: 28))
        .environment(\.colorScheme, .dark)
    }
}
