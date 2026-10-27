import AppKit
import ApplicationServices
import RecCore
import ScreenCaptureKit

enum ResizeError: LocalizedError {
    case accessibilityDenied
    case windowNotFound
    case failed(AXError)

    var errorDescription: String? {
        switch self {
        case .accessibilityDenied: "Accessibility permission is required to resize other apps' windows."
        case .windowNotFound: "Could not find the window through Accessibility."
        case .failed(let code): "The app refused to resize the window (AXError \(code.rawValue))."
        }
    }
}

struct ResizeResult {
    let requested: CGSize
    let actual: CGRect
    let matchesAspect: Bool
}

enum WindowResizer {
    /// Resizes and centers `window` on its screen so its aspect ratio matches `preset`.
    /// With `retina`, one window point maps to two video pixels on a 2× screen; otherwise one to one.
    static func fit(_ window: SCWindow, to preset: VideoPreset, retina: Bool) throws -> ResizeResult {
        guard Permissions.accessibility else { throw ResizeError.accessibilityDenied }
        guard let element = axWindow(for: window) else { throw ResizeError.windowNotFound }

        let screen = screen(containing: window.frame)
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let visible = Geometry.flip(screen.visibleFrame, primaryScreenHeight: primaryHeight).insetBy(dx: 16, dy: 16)

        let size = Geometry.fit(pixelSize: preset.pixelSize, backingScale: retina ? screen.backingScaleFactor : 1, available: visible.size)
        let target = Geometry.centered(size, in: visible)

        // Move first so the new size is not clamped by the screen edge, then move again
        // because some apps reposition themselves after a resize.
        try set(element, position: target.origin)
        try set(element, size: target.size)
        try set(element, position: target.origin)

        var actual = frame(of: element) ?? target
        if !Geometry.aspectMatches(actual.size, preset.pixelSize) {
            // The app enforces a minimum or maximum size. Grow the other dimension to
            // restore the ratio, as long as the window still fits on screen.
            let grown = Geometry.grow(actual.size, toAspect: preset.aspectRatio)
            if grown.width <= visible.width && grown.height <= visible.height {
                let retry = Geometry.centered(grown, in: visible)
                try? set(element, position: retry.origin)
                try? set(element, size: retry.size)
                try? set(element, position: retry.origin)
                actual = frame(of: element) ?? actual
            }
        }
        return ResizeResult(requested: size, actual: actual, matchesAspect: Geometry.aspectMatches(actual.size, preset.pixelSize))
    }

    /// Current frame of `window` in Quartz coordinates, falling back to the frame ScreenCaptureKit reported.
    static func currentFrame(of window: SCWindow) -> CGRect {
        axWindow(for: window).flatMap(frame(of:)) ?? window.frame
    }

    static func raise(_ window: SCWindow) {
        if let pid = window.owningApplication?.processID {
            NSRunningApplication(processIdentifier: pid)?.activate()
        }
        if let element = axWindow(for: window) {
            AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        }
    }

    static func axWindow(for window: SCWindow) -> AXUIElement? {
        guard let pid = window.owningApplication?.processID else { return nil }
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let elements = value as? [AXUIElement] else { return nil }

        func score(_ element: AXUIElement) -> CGFloat {
            guard let f = frame(of: element) else { return .infinity }
            var s = abs(f.minX - window.frame.minX) + abs(f.minY - window.frame.minY)
                + abs(f.width - window.frame.width) + abs(f.height - window.frame.height)
            if let title = window.title, !title.isEmpty, self.title(of: element) != title {
                s += 10_000
            }
            return s
        }
        return elements.min { score($0) < score($1) }
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success
        else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    private static func title(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value)
        return value as? String
    }

    private static func set(_ element: AXUIElement, position: CGPoint) throws {
        var p = position
        let value = AXValueCreate(.cgPoint, &p)!
        let err = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
        if err != .success { throw ResizeError.failed(err) }
    }

    private static func set(_ element: AXUIElement, size: CGSize) throws {
        var s = size
        let value = AXValueCreate(.cgSize, &s)!
        let err = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
        if err != .success { throw ResizeError.failed(err) }
    }

    /// `frame` is in Quartz (top-left origin) coordinates.
    private static func screen(containing frame: CGRect) -> NSScreen {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first {
            Geometry.flip($0.frame, primaryScreenHeight: primaryHeight).contains(center)
        } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}
