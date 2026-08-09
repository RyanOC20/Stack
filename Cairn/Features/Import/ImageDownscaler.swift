import AppKit
import Foundation

/// Downscales and recompresses large source images before AI ingestion so the upload
/// stays well under the Edge Function's size cap and doesn't waste model tokens. PNG is
/// preferred to keep text crisp; JPEG is a fallback when PNG is still too large.
enum ImageDownscaler {
    /// Longest-edge pixel cap — enough resolution to read assignment text, small enough
    /// to bound the payload.
    static let maxDimension: CGFloat = 2000
    /// Target byte ceiling for the processed image (comfortably below the server's cap).
    static let maxBytes = 4 * 1024 * 1024

    /// Returns processed image bytes and their media type. Falls back to the original
    /// data/type when the image can't be decoded or is already small enough.
    static func prepare(data: Data, mediaType: String) -> (data: Data, mediaType: String) {
        guard let source = NSBitmapImageRep(data: data) else {
            return (data, mediaType)
        }

        let scaled = scaledDown(source)
        let rep = scaled ?? source

        // Already within bounds and not resized: keep the original bytes/type.
        if scaled == nil, data.count <= maxBytes {
            return (data, mediaType)
        }

        if let png = rep.representation(using: .png, properties: [:]), png.count <= maxBytes {
            return (png, "image/png")
        }
        for quality in [0.8, 0.6, 0.4] {
            if let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: quality]),
               jpeg.count <= maxBytes
            {
                return (jpeg, "image/jpeg")
            }
        }
        // Last resort: lowest-quality JPEG. The server still enforces a hard cap.
        if let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.3]) {
            return (jpeg, "image/jpeg")
        }
        return (data, mediaType)
    }

    /// Scales the rep so its longest edge is at most `maxDimension`. Returns nil when no
    /// scaling is needed or the redraw fails.
    private static func scaledDown(_ rep: NSBitmapImageRep) -> NSBitmapImageRep? {
        let width = CGFloat(rep.pixelsWide)
        let height = CGFloat(rep.pixelsHigh)
        let longest = max(width, height)
        guard longest > maxDimension else { return nil }

        let scale = maxDimension / longest
        let newWidth = max(1, Int((width * scale).rounded()))
        let newHeight = max(1, Int((height * scale).rounded()))

        guard let scaledRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: newWidth,
            pixelsHigh: newHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        scaledRep.size = NSSize(width: newWidth, height: newHeight)

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let context = NSGraphicsContext(bitmapImageRep: scaledRep) else {
            return nil
        }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        rep.draw(
            in: NSRect(x: 0, y: 0, width: newWidth, height: newHeight),
            from: NSRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh),
            operation: .copy,
            fraction: 1.0,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high.rawValue]
        )
        context.flushGraphics()
        return scaledRep
    }
}
