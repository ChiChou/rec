import AppKit

/// A stop button in the menu bar while recording, like QuickTime's. The menu bar is not part
/// of the recorded app, so it never appears in the video.
@MainActor
final class MenuBarStop: NSObject {
    private unowned let model: AppModel
    private var item: NSStatusItem?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        guard item == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: "Stop Recording")
            button.toolTip = "Stop Recording"
            button.target = self
            button.action = #selector(stop)
        }
        self.item = item
    }

    func hide() {
        guard let item else { return }
        NSStatusBar.system.removeStatusItem(item)
        self.item = nil
    }

    @objc private func stop() {
        model.stopRecording()
    }
}
