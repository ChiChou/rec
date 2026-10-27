import CoreGraphics
import Testing
@testable import RecCore

@Test func exactPixelMatchWhenItFits() {
    let size = Geometry.fit(pixelSize: CGSize(width: 1920, height: 1080), backingScale: 2, available: CGSize(width: 1500, height: 900))
    #expect(size == CGSize(width: 960, height: 540))
}

@Test func scalesDownWhenTooLarge() {
    let size = Geometry.fit(pixelSize: CGSize(width: 3840, height: 2160), backingScale: 2, available: CGSize(width: 1470, height: 900))
    #expect(size.width <= 1470 && size.height <= 900)
    #expect(Geometry.aspectMatches(size, CGSize(width: 16, height: 9)))
}

@Test func verticalLimitedByHeight() {
    let size = Geometry.fit(pixelSize: CGSize(width: 1080, height: 1920), backingScale: 2, available: CGSize(width: 1470, height: 900))
    #expect(size.height == 900)
    #expect(Geometry.aspectMatches(size, CGSize(width: 9, height: 16)))
}

@Test func nonRetina() {
    let size = Geometry.fit(pixelSize: CGSize(width: 1280, height: 720), backingScale: 1, available: CGSize(width: 2500, height: 1400))
    #expect(size == CGSize(width: 1280, height: 720))
}

@Test func centering() {
    let r = Geometry.centered(CGSize(width: 100, height: 50), in: CGRect(x: 0, y: 25, width: 1000, height: 500))
    #expect(r == CGRect(x: 450, y: 250, width: 100, height: 50))
}

@Test func flipping() {
    let r = Geometry.flip(CGRect(x: 0, y: 0, width: 1000, height: 870), primaryScreenHeight: 900)
    #expect(r == CGRect(x: 0, y: 30, width: 1000, height: 870))
}

@Test func growRestoresAspect() {
    // A window that cannot be narrower than 1000 pt, asked to be 9:16.
    let size = Geometry.grow(CGSize(width: 1000, height: 960), toAspect: 9.0 / 16.0)
    #expect(size == CGSize(width: 1000, height: 1778))
    let wide = Geometry.grow(CGSize(width: 800, height: 600), toAspect: 16.0 / 9.0)
    #expect(wide == CGSize(width: 1067, height: 600))
}

@Test func cropToVertical() {
    let rect = Geometry.crop(CGSize(width: 1000, height: 960), toAspect: 9.0 / 16.0)
    #expect(rect == CGRect(x: 230, y: 0, width: 540, height: 960))
}

@Test func cropToWide() {
    let rect = Geometry.crop(CGSize(width: 960, height: 960), toAspect: 16.0 / 9.0)
    #expect(rect == CGRect(x: 0, y: 210, width: 960, height: 540))
}

@Test func presetLabels() {
    #expect(VideoPreset.youtube4K.ratioLabel == "16:9")
    #expect(VideoPreset.reelsHD.ratioLabel == "9:16")
    #expect(VideoPreset.reelsHD.isVertical)
    #expect(VideoPreset.all.count == 4)
}
