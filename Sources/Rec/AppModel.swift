import AppKit
import RecCore
import ScreenCaptureKit

struct WindowItem: Identifiable {
    let window: SCWindow
    let appName: String
    let icon: NSImage?

    var id: CGWindowID { window.windowID }
    var title: String { window.title.flatMap { $0.isEmpty ? nil : $0 } ?? appName }
}

@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case countdown(Int)
        case recording(since: Date)
        case saving
    }

    @Published var preset: VideoPreset { didSet { defaults.set(preset.id, forKey: "preset") } }
    @Published var windows: [WindowItem] = []
    @Published var selection: CGWindowID? { didSet { selectionChanged() } }
    @Published var screenGranted = Permissions.screenRecording
    @Published var accessibilityGranted = Permissions.accessibility
    @Published var phase: Phase = .idle
    @Published var status: String?
    @Published var lastRecording: URL?
    @Published var thumbnails: [CGWindowID: NSImage] = [:]
    /// Live frame of the selected window in Quartz coordinates.
    @Published var selectedFrame: CGRect?

    /// Seconds of countdown before recording starts; 0 turns it off.
    @Published var countdownSeconds: Int { didSet { defaults.set(countdownSeconds, forKey: "countdownSeconds") } }
    @Published var captureAudio: Bool { didSet { defaults.set(captureAudio, forKey: "captureAudio") } }
    @Published var showsCursor: Bool { didSet { defaults.set(showsCursor, forKey: "showsCursor") } }
    @Published var fitBeforeRecording: Bool { didSet { defaults.set(fitBeforeRecording, forKey: "fitBeforeRecording") } }
    @Published var useRetina2x: Bool { didSet { defaults.set(useRetina2x, forKey: "useRetina2x") } }
    @Published var cropToFill: Bool { didSet { defaults.set(cropToFill, forKey: "cropToFill") } }

    private let defaults = UserDefaults.standard
    private let recorder = Recorder()
    private let countdownHUD = CountdownHUD()
    private lazy var recordingBar = RecordingBar(model: self)
    private lazy var menuBarStop = MenuBarStop(model: self)
    /// Rec's windows ordered out while recording, to bring back afterwards.
    private var steppedAside: [NSWindow] = []
    private var pollTimer: Timer?
    private var previewTimer: Timer?

    var selectedItem: WindowItem? { windows.first { $0.id == selection } }
    var isBusy: Bool { phase != .idle }

    init() {
        defaults.register(defaults: [
            "countdownSeconds": 3,
            "captureAudio": false,
            "showsCursor": true,
            "fitBeforeRecording": true,
            "useRetina2x": true,
            "cropToFill": true,
        ])
        let presetID = defaults.string(forKey: "preset")
        preset = VideoPreset.all.first { $0.id == presetID } ?? .youtubeHD
        countdownSeconds = defaults.integer(forKey: "countdownSeconds")
        captureAudio = defaults.bool(forKey: "captureAudio")
        showsCursor = defaults.bool(forKey: "showsCursor")
        fitBeforeRecording = defaults.bool(forKey: "fitBeforeRecording")
        useRetina2x = defaults.bool(forKey: "useRetina2x")
        cropToFill = defaults.bool(forKey: "cropToFill")

        recorder.onStreamError = { [weak self] error in
            Task { @MainActor in self?.recordingFailed(error) }
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollPermissions() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isBusy else { return }
                await self.refreshWindows()
            }
        }
        Task { await refreshWindows() }
    }

    // MARK: Permissions

    private func pollPermissions() {
        let screen = Permissions.screenRecording
        let ax = Permissions.accessibility
        if screen != screenGranted {
            screenGranted = screen
            if screen { Task { await refreshWindows() } }
        }
        if ax != accessibilityGranted { accessibilityGranted = ax }
    }

    func requestScreenRecording() {
        if !Permissions.requestScreenRecording() {
            Permissions.openScreenRecordingSettings()
        }
    }

    func requestAccessibility() {
        if !Permissions.requestAccessibility() {
            Permissions.openAccessibilitySettings()
        }
    }

    // MARK: Windows

    func refreshWindows() async {
        guard Permissions.screenRecording else { return }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            let ownPID = ProcessInfo.processInfo.processIdentifier
            windows = content.windows
                .filter { w in
                    guard let app = w.owningApplication else { return false }
                    return w.windowLayer == 0 && w.isOnScreen
                        && app.processID != ownPID
                        && w.frame.width >= 120 && w.frame.height >= 80
                }
                .map { w in
                    let app = w.owningApplication!
                    let running = NSRunningApplication(processIdentifier: app.processID)
                    return WindowItem(window: w, appName: app.applicationName, icon: running?.icon)
                }
                .sorted { ($0.appName, $0.title) < ($1.appName, $1.title) }
            if let selection, !windows.contains(where: { $0.id == selection }) {
                self.selection = nil
            }
            let ids = Set(windows.map(\.id))
            thumbnails = thumbnails.filter { ids.contains($0.key) }
            for item in windows {
                await captureThumbnail(item)
            }
        } catch {
            status = error.localizedDescription
        }
    }

    private func captureThumbnail(_ item: WindowItem) async {
        let frame = item.id == selection ? (selectedFrame ?? item.window.frame) : item.window.frame
        let scale = min(1, 640 / max(frame.width, frame.height))
        let config = SCStreamConfiguration()
        config.width = max(1, Int(frame.width * scale * 2))
        config.height = max(1, Int(frame.height * scale * 2))
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        let filter = SCContentFilter(desktopIndependentWindow: item.window)
        if let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) {
            thumbnails[item.id] = NSImage(cgImage: image, size: NSSize(width: image.width / 2, height: image.height / 2))
        }
    }

    /// Keeps the selected window's frame and thumbnail live for the output preview.
    private func selectionChanged() {
        previewTimer?.invalidate()
        previewTimer = nil
        selectedFrame = selection.flatMap(Self.liveFrame)
        guard selection != nil else { return }
        previewTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.updatePreview() }
        }
        Task { await updatePreview() }
    }

    private func updatePreview() async {
        guard !isBusy, let item = selectedItem else { return }
        selectedFrame = Self.liveFrame(item.id) ?? item.window.frame
        await captureThumbnail(item)
    }

    private static func liveFrame(_ id: CGWindowID) -> CGRect? {
        guard let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as? [[String: Any]],
              let bounds = info.first?[kCGWindowBounds as String] as? NSDictionary
        else { return nil }
        return CGRect(dictionaryRepresentation: bounds as CFDictionary)
    }

    // MARK: Fit

    /// Whether the selected window, as it is now, already has the preset's aspect ratio.
    var selectionMatchesPreset: Bool {
        selectedFrame.map { Geometry.aspectMatches($0.size, preset.pixelSize) } ?? false
    }

    func fitWindow() {
        guard let item = selectedItem else { return }
        if !Permissions.accessibility {
            requestAccessibility()
            return
        }
        do {
            let result = try WindowResizer.fit(item.window, to: preset, retina: useRetina2x)
            selectedFrame = result.actual
            let size = "\(Int(result.actual.width))×\(Int(result.actual.height)) pt"
            status = result.matchesAspect
                ? "Resized to \(size)."
                : mismatchMessage(app: item.appName, size: result.actual.size)
            Task { await updatePreview() }
        } catch {
            status = error.localizedDescription
        }
    }

    private func mismatchMessage(app: String, size: CGSize) -> String {
        let limit = "\(app) won't resize to \(preset.ratioLabel) on this screen (stays \(Int(size.width))×\(Int(size.height)) pt)"
        return cropToFill ? "\(limit); the video will be cropped to fill." : "\(limit); the video will have black bars."
    }

    // MARK: Recording

    func startRecording() {
        guard phase == .idle, let item = selectedItem else { return }
        var frame = Self.liveFrame(item.id) ?? item.window.frame
        if fitBeforeRecording && Permissions.accessibility,
           let result = try? WindowResizer.fit(item.window, to: preset, retina: useRetina2x) {
            frame = result.actual
        }
        let mismatched = !Geometry.aspectMatches(frame.size, preset.pixelSize)
        let crop = cropToFill && mismatched ? Geometry.crop(frame.size, toAspect: preset.aspectRatio) : nil
        let warning = mismatched ? mismatchMessage(app: item.appName, size: frame.size) : nil

        recordingBar.show(near: frame)
        hideMainWindow()
        WindowResizer.raise(item.window)

        Task {
            if countdownSeconds > 0 {
                for n in stride(from: countdownSeconds, through: 1, by: -1) {
                    phase = .countdown(n)
                    countdownHUD.show(n, warning: warning, over: frame) {
                        self.cancelCountdown()
                    }
                    try? await Task.sleep(for: .seconds(1))
                    if phase == .idle {
                        countdownHUD.hide()
                        return
                    }
                }
                countdownHUD.hide()
            }
            let url = Self.makeOutputURL(preset: preset, app: item.appName)
            do {
                try await recorder.start(window: item.window, frame: frame, preset: preset, crop: crop, captureAudio: captureAudio, showsCursor: showsCursor, to: url)
                phase = .recording(since: Date())
                menuBarStop.show()
                status = warning
            } catch {
                recordingFailed(error)
            }
        }
    }

    func cancelCountdown() {
        guard case .countdown = phase else { return }
        phase = .idle
        showMainWindow()
        countdownHUD.hide()
        recordingBar.hide()
        menuBarStop.hide()
    }

    func stopRecording() {
        guard case .recording = phase else { return }
        phase = .saving
        Task {
            do {
                let url = try await recorder.stop()
                phase = .idle
                lastRecording = url
                status = nil
            } catch {
                recordingFailed(error)
            }
            showMainWindow()
            recordingBar.hide()
            menuBarStop.hide()
        }
    }

    private func recordingFailed(_ error: Error) {
        guard phase != .idle else { return }
        phase = .idle
        Log.error("recording failed: \(Log.describe(error))")
        if let partial = recorder.outputURL.flatMap(Recorder.existing) {
            lastRecording = partial
            status = "Recording stopped early: \(error.localizedDescription) What was recorded so far was saved."
        } else {
            status = "Recording failed: \(error.localizedDescription) Details are in \(Log.fileURL.path)."
        }
        showMainWindow()
        countdownHUD.hide()
        recordingBar.hide()
        menuBarStop.hide()
    }

    // The main window steps aside while recording; the floating bar and the
    // countdown badge are panels, which `canBecomeMain` leaves alone.
    private func hideMainWindow() {
        steppedAside = NSApp.windows.filter { $0.canBecomeMain && $0.isVisible }
        steppedAside.forEach { $0.orderOut(nil) }
    }

    private func showMainWindow() {
        NSApp.activate()
        // `activate()` is only a request since macOS 14, so a failure while another app is
        // in front would otherwise leave rec's window, and its error, behind that app.
        // A hidden window reports `canBecomeMain == false`, hence the list kept on hiding.
        let windows = steppedAside.isEmpty ? NSApp.windows.filter(\.canBecomeMain) : steppedAside
        steppedAside = []
        for window in windows {
            window.orderFrontRegardless()
            window.makeKey()
        }
    }

    // MARK: Files

    static var recordingsFolder: URL {
        FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0].appendingPathComponent("Rec", isDirectory: true)
    }

    func openRecordingsFolder() {
        let dir = Self.recordingsFolder
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }

    func openLastRecording() {
        if let lastRecording { NSWorkspace.shared.open(lastRecording) }
    }

    func revealLastRecording() {
        if let lastRecording { NSWorkspace.shared.activateFileViewerSelecting([lastRecording]) }
    }

    private static func makeOutputURL(preset: VideoPreset, app: String) -> URL {
        let dir = recordingsFolder
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let safeApp = app.replacingOccurrences(of: "/", with: "-")
        return dir.appendingPathComponent("\(safeApp) \(preset.id) \(formatter.string(from: Date())).mp4")
    }
}
