#if DEBUG
import CoreGraphics
import Foundation

/// `Clawdio --export-sprites <fichier.json>` : écrit les sprites de l'avatar (pixels, clips, palette) en JSON
/// puis quitte. Alimente la page de visualisation (`scripts/sprite-viewer.sh`). Debug uniquement.
enum SpriteExport {
    static func run(to path: String) {
        var images: [String: Any] = [:]
        var ids: [ObjectIdentifier: String] = [:]
        func id(_ image: CGImage) -> String {
            if let known = ids[ObjectIdentifier(image)] { return known }
            let new = "i\(ids.count)"
            ids[ObjectIdentifier(image)] = new
            images[new] = ["w": image.width, "h": image.height, "px": pixels(image)]
            return new
        }

        var output: [String: Any] = [
            "size": AvatarSprites.size,
            "exportedAt": ISO8601DateFormatter().string(from: .now),
            "palette": AvatarPalette.standard
                .sorted { String($0.key) < String($1.key) }
                .map { ["key": String($0.key), "hex": hex($0.value)] },
            "shadow": id(AvatarSprites.shadow),
            "rest": Dictionary(uniqueKeysWithValues: AvatarMood.gallery.map { ($0.label, id(AvatarSprites.rest($0).image)) }),
            "clips": AvatarSprites.allClips.map { serialize($0, id) },
            "badges": [
                "w": BadgeSprites.width, "h": BadgeSprites.height,
                "clips": BadgeSprites.allClips.map { serialize($0, id) },
            ],
        ]
        output["images"] = images // rempli par les appels à `id` ci-dessus
        do {
            let data = try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])
            try data.write(to: URL(fileURLWithPath: path))
            print("écrit \(path) (\(images.count) images, \(AvatarSprites.allClips.count) clips)")
        } catch {
            print("échec export : \(error)")
        }
    }

    private static func serialize(_ clip: SpriteClip, _ id: (CGImage) -> String) -> [String: Any] {
        [
            "name": clip.name, "fps": clip.fps, "loops": clip.loops, "duration": clip.duration,
            "frames": clip.frames.map { ["image": id($0.image), "dx": $0.dx, "dy": $0.dy, "hold": $0.hold] },
        ]
    }

    /// Lignes de pixels `rrggbbaa` ("" = transparent), alpha dé-prémultiplié.
    private static func pixels(_ image: CGImage) -> [[String]] {
        let w = image.width, h = image.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return (0..<h).map { y in
            (0..<w).map { x in
                let i = (y * w + x) * 4
                let a = bytes[i + 3]
                guard a > 0 else { return "" }
                func un(_ v: UInt8) -> UInt8 { UInt8(min(255, (UInt16(v) * 255 + UInt16(a) / 2) / UInt16(a))) }
                return String(format: "%02x%02x%02x%02x", un(bytes[i]), un(bytes[i + 1]), un(bytes[i + 2]), a)
            }
        }
    }

    private static func hex(_ c: PixelColor) -> String {
        String(format: "%02x%02x%02x%02x", c.r, c.g, c.b, c.a)
    }
}
#endif
