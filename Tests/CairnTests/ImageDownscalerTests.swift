import AppKit
@testable import Cairn
import XCTest

final class ImageDownscalerTests: XCTestCase {
    /// Builds opaque PNG data at the given pixel size.
    private func makePNG(width: Int, height: Int) throws -> Data {
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        rep.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()
        return try XCTUnwrap(rep.representation(using: .png, properties: [:]))
    }

    func testDownscalesOversizedImageWithinDimensionCap() throws {
        let original = try makePNG(width: 4000, height: 3000)

        let prepared = ImageDownscaler.prepare(data: original, mediaType: "image/png")

        let rep = try XCTUnwrap(NSBitmapImageRep(data: prepared.data))
        XCTAssertLessThanOrEqual(rep.pixelsWide, Int(ImageDownscaler.maxDimension))
        XCTAssertLessThanOrEqual(rep.pixelsHigh, Int(ImageDownscaler.maxDimension))
        XCTAssertLessThanOrEqual(prepared.data.count, ImageDownscaler.maxBytes)
    }

    func testLeavesSmallImageUnchanged() throws {
        let original = try makePNG(width: 800, height: 600)

        let prepared = ImageDownscaler.prepare(data: original, mediaType: "image/png")

        XCTAssertEqual(prepared.data, original, "A small image should pass through untouched")
        XCTAssertEqual(prepared.mediaType, "image/png")
    }

    func testUndecodableDataFallsBackToOriginal() {
        let junk = Data([0x00, 0x01, 0x02, 0x03])

        let prepared = ImageDownscaler.prepare(data: junk, mediaType: "image/png")

        XCTAssertEqual(prepared.data, junk)
        XCTAssertEqual(prepared.mediaType, "image/png")
    }
}
