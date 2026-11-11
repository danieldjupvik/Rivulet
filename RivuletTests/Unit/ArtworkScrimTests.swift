import Testing
import UIKit
@testable import Rivulet

@MainActor
struct ArtworkScrimTests {
    @Test func paletteCacheKeepsDifferentArtworkSeparate() async throws {
        let images = [UIColor.red, .blue].map { color in
            artwork { context in
                context.setFillColor(color.cgColor)
                context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
            }
        }
        var colors: [UIColor] = []
        for image in images {
            #expect(ArtworkScrimPalette.cachedColor(for: image) == nil)
            let result = await ArtworkScrimPalette.color(for: image)
            let color = try #require(result)
            #expect(ArtworkScrimPalette.cachedColor(for: image) === color)
            let repeated = await ArtworkScrimPalette.color(for: image)
            #expect(repeated === color)
            colors.append(color)
        }
        #expect(colors[0] != colors[1])
        #expect(ArtworkScrimPalette.cachedColor(for: images[0]) === colors[0])
    }

    @Test func transparentArtworkHasNoPaletteColor() async {
        let image = artwork { _ in }
        let color = await ArtworkScrimPalette.color(for: image)
        #expect(color == nil)
        #expect(ArtworkScrimPalette.cachedColor(for: image) == nil)
    }

    @Test func palettePreservesTheSelectedColorBeforeRendering() async throws {
        let image = artwork { context in
            context.setFillColor(UIColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
        }
        let view = ArtworkScrimView()
        await configure(view, image: image)
        let actual = try components(view)
        for (value, expected) in zip(actual, [CGFloat(0.7), 0.5, 0.3]) {
            #expect(abs(value - expected) < 0.005)
        }
    }

    @Test(arguments: [false, true])
    func fadeCompositesColorBelowGrayAndLeavesTheTopClear(missingColor: Bool) throws {
        let view = ArtworkScrimView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        view.configure(color: .blue)
        view.layoutIfNeeded()
        view.configure(color: missingColor ? nil : .white)
        view.frame.size = CGSize(width: 40, height: 400)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        let layers = try #require(view.layer.sublayers)
        try #require(layers.allSatisfy { $0.frame == view.bounds })

        var pixels = [UInt8](repeating: 0, count: 40 * 400 * 4)
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(
                data: buffer.baseAddress, width: 40, height: 400,
                bitsPerComponent: 8, bytesPerRow: 40 * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(UIColor.white.cgColor)
            context.fill(view.bounds)
            context.translateBy(x: 0, y: view.bounds.height)
            context.scaleBy(x: 1, y: -1)
            view.layer.render(in: context)
        }
        let gray = 40.0 / 255
        let expectedBottom = 0.036 + (missingColor ? 0 : 0.324) + 0.64 * gray
        for channel in 0..<3 {
            #expect(pixels[(200 * 40 + 20) * 4 + channel] == 255)
            let middle = Double(pixels[(240 * 40 + 20) * 4 + channel]) / 255
            #expect(abs(middle - (1 - 0.0364 * (1 - gray))) < 0.012)
            let bottom = Double(pixels[(399 * 40 + 20) * 4 + channel]) / 255
            #expect(abs(bottom - expectedBottom) < 0.012)
        }
    }

    @Test(arguments: [false, true])
    func foregroundDoesNotDetermineBackdrop(brightBackground: Bool) async throws {
        let background = brightBackground
            ? UIColor(red: 0.7, green: 0.75, blue: 0.8, alpha: 1)
            : UIColor(red: 0.05, green: 0.1, blue: 0.15, alpha: 1)
        let foreground: UIColor = brightBackground ? .black : .white
        let plain = artwork { context in
            context.setFillColor(background.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
        }
        let withForeground = artwork { context in
            context.setFillColor(background.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
            context.setFillColor(foreground.cgColor)
            context.fill(CGRect(x: 0, y: 240, width: 640, height: 120))
        }
        let view = ArtworkScrimView()
        await configure(view, image: plain)
        let expected = try components(view)
        await configure(view, image: withForeground)
        let actual = try components(view)
        for (lhs, rhs) in zip(actual, expected) {
            #expect(abs(lhs - rhs) < 0.015)
        }
    }

    @Test func vividBackdropDoesNotOverpowerASubstantialMutedRegion() async throws {
        let image = artwork { context in
            context.setFillColor(UIColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 1).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
            context.setFillColor(UIColor.blue.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 350, height: 360))
        }
        let view = ArtworkScrimView()
        await configure(view, image: image)
        let color = try components(view)
        #expect(color[2] < 0.25)
        #expect(color[2] > color[0])
    }

    @Test func whiteSkyDoesNotWashOutTheBackdrop() async throws {
        let image = artwork { context in
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
            context.setFillColor(UIColor(red: 0.1, green: 0.12, blue: 0.16, alpha: 1).cgColor)
            context.fill(CGRect(x: 0, y: 240, width: 640, height: 120))
        }
        let view = ArtworkScrimView()
        await configure(view, image: image)
        let color = try components(view)
        #expect(color.allSatisfy { $0 < 0.25 })
        #expect(color[2] > color[0])
    }

    @Test func transparentPixelsDoNotBecomeTheDominantColor() async throws {
        let image = artwork { context in
            context.setFillColor(UIColor.red.cgColor)
            context.fill(CGRect(x: 200, y: 100, width: 200, height: 100))
        }
        let view = ArtworkScrimView()
        await configure(view, image: image)
        let color = try components(view)
        #expect(color[0] > color[1] + 0.3)
        #expect(color[0] > color[2] + 0.3)
    }

    @Test func missingAndTransparentArtworkClearThePreviousColor() async throws {
        let view = ArtworkScrimView()
        let fallback = try components(view)
        let red = artwork { context in
            context.setFillColor(UIColor.red.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
        }
        for empty in [nil, artwork { _ in }] as [UIImage?] {
            await configure(view, image: red)
            await configure(view, image: empty)
            #expect(try components(view) == fallback)
        }
    }

    private func configure(_ view: ArtworkScrimView, image: UIImage?) async {
        let color = if let image { await ArtworkScrimPalette.color(for: image) } else { nil as UIColor? }
        view.configure(color: color)
    }

    private func artwork(draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: CGSize(width: 640, height: 360), format: format).image {
            draw($0.cgContext)
        }
    }

    private func components(_ view: ArtworkScrimView) throws -> [CGFloat] {
        let gradient = try #require(view.layer.sublayers?.compactMap { $0 as? CAGradientLayer }.first)
        let colors = try #require(gradient.colors as? [CGColor])
        let color = UIColor(cgColor: try #require(colors.last))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        #expect(color.getRed(&red, green: &green, blue: &blue, alpha: nil))
        return [red, green, blue]
    }
}
