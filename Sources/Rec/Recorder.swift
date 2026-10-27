import AVFoundation
import RecCore
import ScreenCaptureKit

enum RecorderError: LocalizedError {
    case noDisplay
    case noApplication

    var errorDescription: String? {
        switch self {
        case .noDisplay: "The window isn't on a display that can be recorded."
        case .noApplication: "Could not find the app that owns the window."
        }
    }
}

/// Records one region of one display, showing only the target app's windows.
///
/// Recording the region rather than the single window keeps the recording going when the app
/// swaps or adds windows (sheets, dialogs, context menus, a separate editor window), which a
/// single-window filter drops. Other apps, including rec's own countdown badge and floating
/// bar, are never captured.
final class Recorder: NSObject, SCStreamDelegate, SCStreamOutput, SCRecordingOutputDelegate {
    private var stream: SCStream?
    private let sampleQueue = DispatchQueue(label: "rec.samples", qos: .utility)
    private var finish: CheckedContinuation<Void, Error>?
    private var stopping = false
    private(set) var outputURL: URL?

    /// Called on any queue when the recording ends without `stop()` being called.
    var onStreamError: ((Error) -> Void)?

    /// `frame` is the window in Quartz (top-left origin) global coordinates.
    /// `crop` is a region of the window in points, relative to its top-left corner.
    func start(window: SCWindow, frame: CGRect, preset: VideoPreset, crop: CGRect?, captureAudio: Bool, showsCursor: Bool, to url: URL) async throws {
        guard let app = window.owningApplication else { throw RecorderError.noApplication }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let center = CGPoint(x: frame.midX, y: frame.midY)
        guard let display = content.displays.first(where: { $0.frame.contains(center) })
            ?? content.displays.max(by: { $0.frame.intersection(frame).area < $1.frame.intersection(frame).area })
        else { throw RecorderError.noDisplay }
        let shareableApp = content.applications.first { $0.processID == app.processID } ?? app

        var region = frame.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
        if let crop {
            region = crop.offsetBy(dx: region.minX, dy: region.minY)
        }
        region = region.intersection(CGRect(origin: .zero, size: display.frame.size)).integral

        let filter = SCContentFilter(display: display, including: [shareableApp], exceptingWindows: [])

        let config = SCStreamConfiguration()
        config.width = preset.width
        config.height = preset.height
        config.sourceRect = region
        config.scalesToFit = true
        config.preservesAspectRatio = true
        config.backgroundColor = .black
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 8
        config.showsCursor = showsCursor
        config.captureResolution = .best
        config.capturesAudio = captureAudio
        config.excludesCurrentProcessAudio = true

        let recording = SCRecordingOutputConfiguration()
        recording.outputURL = url
        recording.outputFileType = .mp4
        recording.videoCodecType = preset.width * preset.height > 1920 * 1080 ? .hevc : .h264

        Log.info("start app=\(shareableApp.applicationName) pid=\(shareableApp.processID) window=\(window.windowID) display=\(display.displayID) region=\(region) preset=\(preset.id) url=\(url.lastPathComponent)")

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        let output = SCRecordingOutput(configuration: recording, delegate: self)
        // SCRecordingOutput does the writing; these no-op outputs only stop
        // ScreenCaptureKit from logging "stream output NOT found" for every frame.
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        if captureAudio {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
        }
        try stream.addRecordingOutput(output)
        stopping = false
        self.outputURL = url
        try await stream.startCapture()
        self.stream = stream
        Log.info("capture started")
    }

    func stop() async throws -> URL? {
        guard let stream else { return outputURL.flatMap(Self.existing) }
        self.stream = nil
        stopping = true
        Log.info("stop requested")
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            finish = c
            Task {
                do {
                    try await stream.stopCapture()
                } catch {
                    self.resume(with: .failure(error))
                }
            }
        }
        Log.info("finished \(outputURL?.lastPathComponent ?? "-")")
        return outputURL
    }

    /// The output file if anything was written to it, for keeping what was recorded before a failure.
    static func existing(_ url: URL) -> URL? {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        return size > 0 ? url : nil
    }

    private func resume(with result: Result<Void, Error>) {
        guard let c = finish else { return }
        finish = nil
        c.resume(with: result)
    }

    private func failed(_ error: Error, source: String) {
        Log.error("\(source): \(Log.describe(error))")
        let wasStopping = finish != nil
        resume(with: .failure(error))
        if !wasStopping {
            stream = nil
            onStreamError?(error)
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {}

    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        Log.info("recording output started")
    }

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Log.info("recording output finished (stopping=\(stopping))")
        if finish != nil {
            resume(with: .success(()))
        } else if !stopping {
            // The file was closed without a stop request; report it rather than leave the UI recording.
            failed(CocoaError(.fileWriteUnknown, userInfo: [NSLocalizedDescriptionKey: "The recording ended unexpectedly."]), source: "recordingOutputDidFinish")
        }
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        failed(error, source: "recordingOutput didFail")
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        failed(error, source: "stream didStop")
    }
}

private extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }
}
