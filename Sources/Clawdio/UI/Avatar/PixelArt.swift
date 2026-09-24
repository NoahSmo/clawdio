import CoreGraphics
import Foundation

/// Couleur d'un pixel (sRGB, 0–255).
struct PixelColor: Hashable {
    var r, g, b, a: UInt8

    /// `0xRRGGBB` + opacité (0…1).
    init(_ hex: UInt32, alpha: Double = 1) {
        r = UInt8((hex >> 16) & 0xFF)
        g = UInt8((hex >> 8) & 0xFF)
        b = UInt8(hex & 0xFF)
        a = UInt8((alpha * 255).rounded())
    }
}

/// Image pixel art décrite en texte : une chaîne par ligne, un caractère par pixel, `.` = transparent.
/// Lisible dans un diff et dessinable sans outil externe ; convertie une seule fois en `CGImage` (voir `makeImage`).
struct PixelGrid {
    let rows: [String]
    let palette: [Character: PixelColor]

    init(_ rows: [String], palette: [Character: PixelColor]) {
        assert(Set(rows.map(\.count)).count <= 1, "PixelGrid : lignes de largeurs différentes")
        self.rows = rows
        self.palette = palette
    }

    var width: Int { rows.first?.count ?? 0 }
    var height: Int { rows.count }

    /// Calque partiel : `lines` posées à partir de la ligne `row`, le reste du canevas `width` × `height` transparent.
    /// Évite de réécrire 16 lignes de points pour un bras ou une paire d'yeux.
    init(at row: Int, _ lines: [String], width: Int = 16, height: Int = 16, palette: [Character: PixelColor]) {
        let empty = String(repeating: ".", count: width)
        var rows = Array(repeating: empty, count: height)
        for (i, line) in lines.enumerated() { rows[row + i] = line }
        self.init(rows, palette: palette)
    }

    /// La même image recopiée dans un canevas `width` × `height`, décalée de (dx, dy) — négatifs compris, ce qui
    /// dépasse est rogné : réutilise un calque dessiné pour un personnage sur un autre, plus grand.
    func placed(width: Int, height: Int, dx: Int, dy: Int) -> PixelGrid {
        var out = Array(repeating: Array(repeating: Character("."), count: width), count: height)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch != "." {
                let tx = x + dx, ty = y + dy
                if (0..<width).contains(tx), (0..<height).contains(ty) { out[ty][tx] = ch }
            }
        }
        return PixelGrid(out.map { String($0) }, palette: palette)
    }

    /// Superpose des calques de même taille : chaque pixel non transparent recouvre ceux des calques précédents.
    static func layered(_ layers: [PixelGrid]) -> PixelGrid {
        guard var rows = layers.first?.rows.map(Array.init) else { return PixelGrid([], palette: [:]) }
        var palette = layers[0].palette
        for layer in layers.dropFirst() {
            assert(layer.width == rows.first?.count && layer.height == rows.count, "PixelGrid : calques de tailles différentes")
            for (y, row) in layer.rows.enumerated() {
                for (x, ch) in row.enumerated() where ch != "." { rows[y][x] = ch }
            }
            palette.merge(layer.palette) { _, new in new }
        }
        return PixelGrid(rows.map { String($0) }, palette: palette)
    }

    func makeImage() -> CGImage {
        let w = width, h = height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch != "." {
                guard let c = palette[ch] else {
                    assertionFailure("PixelGrid : caractère sans couleur « \(ch) »")
                    continue
                }
                // Alpha prémultiplié : le format natif de Core Graphics.
                let i = (y * w + x) * 4
                let a = UInt16(c.a)
                bytes[i] = UInt8(UInt16(c.r) * a / 255)
                bytes[i + 1] = UInt8(UInt16(c.g) * a / 255)
                bytes[i + 2] = UInt8(UInt16(c.b) * a / 255)
                bytes[i + 3] = c.a
            }
        }
        return CGImage(
            width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data(bytes) as CFData)!,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
    }
}
