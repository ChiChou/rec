import CoreGraphics

public enum Geometry {
    /// Window size in points so the captured window maps to `pixelSize` as closely as possible.
    /// Uses the exact pixel match when it fits in `available`, otherwise the largest size
    /// with the same aspect ratio that does.
    public static func fit(pixelSize: CGSize, backingScale: CGFloat, available: CGSize) -> CGSize {
        let scale = max(backingScale, 1)
        let ideal = CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
        if ideal.width <= available.width && ideal.height <= available.height {
            return ideal
        }
        let factor = min(available.width / ideal.width, available.height / ideal.height)
        let ratio = pixelSize.width / pixelSize.height
        if ratio >= 1 {
            let w = floor(ideal.width * factor)
            return CGSize(width: w, height: (w / ratio).rounded())
        } else {
            let h = floor(ideal.height * factor)
            return CGSize(width: (h * ratio).rounded(), height: h)
        }
    }

    /// Frame of `size` centered in `container`, with an integral origin.
    public static func centered(_ size: CGSize, in container: CGRect) -> CGRect {
        CGRect(
            x: (container.midX - size.width / 2).rounded(.down),
            y: (container.midY - size.height / 2).rounded(.down),
            width: size.width,
            height: size.height
        )
    }

    /// Converts an AppKit (bottom-left origin) rect to Quartz/AX (top-left origin) coordinates.
    public static func flip(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Smallest size at least as large as `size` in both dimensions with the given aspect ratio.
    public static func grow(_ size: CGSize, toAspect ratio: CGFloat) -> CGSize {
        if size.width / size.height > ratio {
            return CGSize(width: size.width, height: (size.width / ratio).rounded(.up))
        }
        return CGSize(width: (size.height * ratio).rounded(.up), height: size.height)
    }

    /// Largest rect with the given aspect ratio centered inside a box of `size`, in the box's own coordinates.
    public static func crop(_ size: CGSize, toAspect ratio: CGFloat) -> CGRect {
        let cropped: CGSize
        if size.width / size.height > ratio {
            cropped = CGSize(width: (size.height * ratio).rounded(.down), height: size.height)
        } else {
            cropped = CGSize(width: size.width, height: (size.width / ratio).rounded(.down))
        }
        return centered(cropped, in: CGRect(origin: .zero, size: size))
    }

    public static func aspectMatches(_ size: CGSize, _ target: CGSize, tolerance: CGFloat = 0.01) -> Bool {
        guard size.height > 0, target.height > 0 else { return false }
        let a = size.width / size.height
        let b = target.width / target.height
        return abs(a - b) / b <= tolerance
    }
}
