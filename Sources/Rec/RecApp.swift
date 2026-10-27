import SwiftUI

@main
struct RecApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Rec", id: "main") {
            MainView()
                .environmentObject(model)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1040, height: 700)
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Rec keeps running after its window closes or a recording stops, like QuickTime;
    /// clicking the Dock icon brings the window back.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
