// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2025-2026 Bain Gurley

import CoreImage
import UIKit

@MainActor
enum ArtworkScrimPalette {
    private nonisolated static let context = CIContext(options: [.workingColorSpace: NSNull()])
    private nonisolated static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let workQueue = DispatchQueue(label: "rivulet.artwork-scrim", qos: .utility)
    // Identity keys avoid retaining artwork beyond the image cache's lifetime.
    private static let colors = NSMapTable<UIImage, UIColor>(
        keyOptions: [.weakMemory, .objectPointerPersonality], valueOptions: .strongMemory)

    static func cachedColor(for image: UIImage) -> UIColor? {
        colors.object(forKey: image)
    }

    static func color(for image: UIImage) async -> UIColor? {
        if let color = cachedColor(for: image) { return color }
        let color = await withCheckedContinuation { continuation in
            workQueue.async {
                continuation.resume(returning: analyze(image))
            }
        }
        if let color { colors.setObject(color, forKey: image) }
        return color
    }

    private nonisolated struct ColorBucket {
        var count = 0
        var sum = SIMD3<Double>.zero

        var mean: SIMD3<Double> { count > 0 ? sum / Double(count) : .zero }

        var score: Double {
            let color = mean
            let chroma = color.max() - color.min()
            let weight = min(1, 64 / max(1, chroma))
            let luminance = (color.x * 0.2126 + color.y * 0.7152 + color.z * 0.0722) / 255
            let highlightWeight = luminance > 0.97 ? 0.01 : 1
            return Double(count) * weight * weight * highlightWeight
        }
    }

    private nonisolated static func analyze(_ image: UIImage) -> UIColor? {
        guard let input = CIImage(image: image), input.extent.width > 0, input.extent.height > 0 else { return nil }
        let width = 64
        let height = 36
        let sample = input
            .transformed(by: CGAffineTransform(translationX: -input.extent.minX, y: -input.extent.minY))
            .transformed(by: CGAffineTransform(scaleX: CGFloat(width) / input.extent.width,
                                              y: CGFloat(height) / input.extent.height))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        context.render(sample, toBitmap: &pixels, rowBytes: width * 4,
                       bounds: CGRect(x: 0, y: 0, width: width, height: height), format: .RGBA8, colorSpace: colorSpace)
        var buckets = Array(repeating: ColorBucket(), count: 512 + 64)
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Int(pixels[offset + 3])
            guard alpha >= 128 else { continue }
            let red = min(255, Int(pixels[offset]) * 255 / alpha)
            let green = min(255, Int(pixels[offset + 1]) * 255 / alpha)
            let blue = min(255, Int(pixels[offset + 2]) * 255 / alpha)
            let fineIndex = (red >> 5) * 64 + (green >> 5) * 8 + (blue >> 5)
            let coarseIndex = 512 + (red >> 6) * 16 + (green >> 6) * 4 + (blue >> 6)
            let color = SIMD3(Double(red), Double(green), Double(blue))
            for index in [fineIndex, coarseIndex] {
                buckets[index].count += 1
                buckets[index].sum += color
            }
        }
        guard let fine = representativeColor(buckets.prefix(512)),
              let coarse = representativeColor(buckets.suffix(64)) else { return nil }
        let color = (fine + coarse) / 2
        return UIColor(red: (color.x * 0.3665 + 26.395) / 255,
                       green: (color.y * 0.3665 + 26.395) / 255,
                       blue: (color.z * 0.3665 + 26.395) / 255, alpha: 1)
    }

    private nonisolated static func representativeColor(_ buckets: ArraySlice<ColorBucket>) -> SIMD3<Double>? {
        let strongest = buckets.filter { $0.count > 0 }
            .map { (mean: $0.mean, score: $0.score, count: $0.count) }
            .sorted { $0.score > $1.score }
            .prefix(3)
        guard let dominant = strongest.first else { return nil }
        let totalCount = buckets.reduce(0) { $0 + $1.count }
        guard dominant.count * 2 < totalCount else { return dominant.mean }
        let totalScore = strongest.reduce(0) { $0 + $1.score }
        let blended = strongest.reduce(SIMD3<Double>.zero) { $0 + $1.mean * $1.score } / totalScore
        return dominant.mean * 0.75 + blended * 0.25
    }
}
