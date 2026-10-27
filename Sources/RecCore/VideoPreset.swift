import CoreGraphics

public struct VideoPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let width: Int
    public let height: Int
    public let symbol: String

    public init(id: String, name: String, width: Int, height: Int, symbol: String) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.symbol = symbol
    }

    public var pixelSize: CGSize { CGSize(width: width, height: height) }
    public var aspectRatio: CGFloat { CGFloat(width) / CGFloat(height) }
    public var isVertical: Bool { height > width }

    public var ratioLabel: String {
        let d = gcd(width, height)
        return "\(width / d):\(height / d)"
    }

    public var sizeLabel: String { "\(width)×\(height)" }

    public static let youtube4K = VideoPreset(id: "youtube-4k", name: "YouTube 4K", width: 3840, height: 2160, symbol: "play.rectangle.fill")
    public static let youtubeHD = VideoPreset(id: "youtube-hd", name: "YouTube HD", width: 1920, height: 1080, symbol: "play.rectangle")
    public static let twitter = VideoPreset(id: "twitter", name: "X / Twitter", width: 1280, height: 720, symbol: "bubble.left")
    public static let reelsHD = VideoPreset(id: "reels-hd", name: "Reels HD", width: 1080, height: 1920, symbol: "iphone")

    public static let all: [VideoPreset] = [youtube4K, youtubeHD, twitter, reelsHD]
}

private func gcd(_ a: Int, _ b: Int) -> Int {
    b == 0 ? a : gcd(b, a % b)
}
