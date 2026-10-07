import CoreGraphics
import Foundation

/// Personnage adapté sur le squelette de Clawd : sa propre silhouette, ses yeux, ses bras et ses jambes (ou pas de
/// bras du tout), mais les clips et les accessoires de Clawd. Chaque calque de Clawd est remplacé par celui du
/// personnage (voir `replacements`) ; ce qui n'a pas d'équivalent (livre, Terminal, étincelles…) est agrandi de
/// `propScale` et recalé de `propOffset` dans le canevas du personnage, plus grand et plus détaillé.
///
/// Lettres propres aux personnages : `a` à `f`, `w`, plus celles de Clawd (`K` contour, `H` `O` `S`, `E` yeux).
struct AvatarSkin {
    var width = 16
    var height = 16
    var pixelScale: CGFloat = 1
    var propScale = 1
    var propOffset = (x: 0, y: 0)
    /// Corps complet (tête comprise), aux dimensions du canevas.
    let body: [String]
    /// Autres images du corps, qui se relaient avec `body` en continu à `flickerFPS` (flammes) ; vide = corps fixe.
    var bodyFlicker: [[String]] = []
    var flickerFPS: Double = 8
    /// Ombre au sol, aux dimensions du canevas.
    let shadow: [String]
    /// Yeux ouverts et fermés, calques du canevas ; décalés d'un pixel quand Clawd regarde ailleurs.
    let eyesOpen: [String]
    let eyesClosed: [String]
    /// Bras gauche baissé, posé en colonne `armX` à partir de la ligne `armRow` ; le droit est son miroir.
    /// Levé, il est retourné juste au-dessus de l'épaule. `nil` = pas de bras.
    var arm: [String]? = nil
    var armX = 0
    var armRow = 0
    /// Faux si les bras ne se lèvent pas : ils restent baissés dans toutes les poses.
    var raises = true
    /// Jambes, calque du canevas ; les poses écartées / serrées / pied levé en sont déduites.
    var legs: [String]? = nil
    /// Les petits qu'il appelle pour déléguer (calque du canevas) ; `nil` = les mini-Clawd, recolorés.
    var minis: [String]? = nil
    /// Gestes propres au personnage, tirés au sort au repos avec ceux de Clawd (Calcifer qui mange).
    var gestures: [Gesture] = []
    let colors: [Character: PixelColor]

    /// Geste propre : une suite de poses, chacune = des calques posés sur le corps (qui continue de scintiller).
    struct Gesture {
        let name: String
        let fps: Double
        let poses: [Pose]
        /// Poids au tirage, normal puis somnolent (voir `AvatarRepertoire.idle`).
        var weight: Double = 6
        var drowsy: Double = 2

        struct Pose {
            /// Par-dessus le corps : yeux, bouche, nourriture…
            let layers: [[String]]
            /// Derrière le corps (grandes flammes de joie).
            var under: [[String]] = []
            /// Par-dessus tout, mais immobiles quand le corps est décalé (la bûche qu'il serre en glissant).
            var fixed: [[String]] = []
            /// Décalage du corps, en pixels du canevas (comme un saut : l'ombre et `fixed` restent en place).
            var dx = 0
            var dy = 0
            var hold = 1
        }
    }

    // MARK: Calques dérivés

    private func grid(_ rows: [String]) -> PixelGrid {
        PixelGrid(rows, palette: AvatarPalette.standard)
    }
    private var empty: PixelGrid { grid(Sketch(width, height).rows) }

    private func arm(left: Bool, up: Bool, row: Int? = nil) -> PixelGrid {
        guard let arm else { return empty }
        let lines = (up && raises) ? Array(arm.reversed()) : arm
        let top = row ?? ((up && raises) ? armRow - lines.count : armRow)
        var sketch = Sketch(width, height)
        sketch.stamp(lines, x: armX, y: top)
        return grid((left ? sketch : sketch.mirrored).outlined.rows)
    }

    private func pair(row: Int) -> PixelGrid {
        PixelGrid.layered([arm(left: true, up: false, row: row), arm(left: false, up: false, row: row)])
    }

    /// Moitié gauche ou droite des jambes, décalée.
    private func leg(left: Bool, dx: Int = 0, dy: Int = 0) -> PixelGrid {
        guard let legs else { return empty }
        let half = legs.map { line in
            String(line.enumerated().map { (i, c) in (i < width / 2) == left ? c : "." })
        }
        return grid(half).placed(width: width, height: height, dx: dx, dy: dy)
    }

    private func legs(left: (dx: Int, dy: Int) = (0, 0), right: (dx: Int, dy: Int) = (0, 0)) -> PixelGrid {
        PixelGrid.layered([leg(left: true, dx: left.dx, dy: left.dy), leg(left: false, dx: right.dx, dy: right.dy)])
    }

    private func eyes(dx: Int = 0, dy: Int = 0, closed: Bool = false) -> PixelGrid {
        grid(closed ? eyesClosed : eyesOpen).placed(width: width, height: height, dx: dx, dy: dy)
    }

    /// Calque de Clawd → calque du personnage.
    private var replacements: [[String]: PixelGrid] {
        typealias A = AvatarSprites
        var map: [[String]: PixelGrid] = [
            A.Body.trunk.rows: grid(body),
            A.Arms.leftDown.rows: arm(left: true, up: false),
            A.Arms.rightDown.rows: arm(left: false, up: false),
            A.Arms.leftUp.rows: arm(left: true, up: true),
            A.Arms.rightUp.rows: arm(left: false, up: true),
            A.Arms.rightTilted.rows: raises ? arm(left: false, up: false, row: armRow - 4) : arm(left: false, up: false),
            A.Arms.pushHigh.rows: pair(row: raises ? armRow - 2 : armRow),
            A.Arms.pushLow.rows: pair(row: armRow),
            A.ToolLimbs.holdLeft.rows: arm(left: true, up: false),
            A.ToolLimbs.holdRight.rows: arm(left: false, up: false),
            A.Legs.stand.rows: legs(),
            A.Legs.apart.rows: legs(left: (-2, 0), right: (2, 0)),
            A.Legs.together.rows: legs(left: (1, 0), right: (-1, 0)),
            A.ToolLimbs.legsTap.rows: legs(right: (0, -2)),
            // Les yeux : ouverts, fermés (joie, effort, sommeil), ou décalés d'un pixel vers où il regarde.
            A.Eyes.open.rows: eyes(),
            A.Eyes.happy.rows: eyes(closed: true),
            A.Eyes.strain.rows: eyes(closed: true),
            A.ToolEyes.up.rows: eyes(dy: -1),
            A.ToolEyes.upLeft.rows: eyes(dx: -1, dy: -1),
            A.IdleEyes.closed.rows: eyes(closed: true),
            A.IdleEyes.half.rows: eyes(closed: true),
            A.IdleEyes.left.rows: eyes(dx: -1),
            A.IdleEyes.right.rows: eyes(dx: 1),
            A.IdleEyes.downRight.rows: eyes(dx: 1, dy: 1),
            A.IdleProps.mouthSmall.rows: empty,
            A.IdleProps.mouthBig.rows: empty,
        ]
        if let minis {
            map[A.Props.minis.rows] = grid(minis)
            map[A.Props.minisHop.rows] = grid(minis).placed(width: width, height: height, dx: 0, dy: -propScale)
        }
        for shift in -1...1 { map[A.ToolEyes.peek(shift).rows] = eyes(dx: shift) }
        // Mains posées sur le laptop : celles de Clawd n'ont pas la bonne couleur, l'écran qui éclaire suffit.
        for l in [false, true] { for r in [false, true] { map[A.Props.hands(leftDown: l, rightDown: r).rows] = empty } }
        return map
    }

    /// Calque de Clawd sans équivalent (accessoire, effet) : agrandi et recalé dans le canevas.
    private func prop(_ layer: PixelGrid) -> PixelGrid {
        var sketch = Sketch(layer.width * propScale, layer.height * propScale)
        sketch.stamp(layer.rows, x: 0, y: 0, scale: propScale)
        return PixelGrid(sketch.rows, palette: layer.palette)
            .placed(width: width, height: height, dx: propOffset.x, dy: propOffset.y)
    }

    // MARK: Répertoire

    var repertoire: AvatarRepertoire {
        let palette = AvatarPalette.standard.merging(colors) { _, skin in skin }
        let replacements = replacements
        let trunk = AvatarSprites.Body.trunk.rows
        let bodies = ([body] + bodyFlicker).map(grid)
        var cache: [ObjectIdentifier: [CGImage]] = [:]

        func dress(_ frame: SpriteFrame) -> SpriteFrame {
            guard !frame.layers.isEmpty else { return frame }
            let key = ObjectIdentifier(frame.image)
            let images = cache[key] ?? bodies.map { body in
                let layers = frame.layers.map { $0.rows == trunk ? body : replacements[$0.rows] ?? prop($0) }
                return PixelGrid(PixelGrid.layered(layers).rows, palette: palette).makeImage()
            }
            cache[key] = images
            // Les sauts de Clawd sont en pixels de Clawd.
            return SpriteFrame(image: images[0], dx: frame.dx * propScale, dy: frame.dy * propScale, hold: frame.hold,
                               flicker: images.count > 1 ? images : [])
        }
        func pose(_ pose: Gesture.Pose) -> SpriteFrame {
            let images = bodies.map { body in
                // L'image entière sera décalée de (dx, dy) : `fixed` l'est d'autant à l'envers pour rester en place.
                let fixed = pose.fixed.map { grid($0).placed(width: width, height: height, dx: -pose.dx, dy: -pose.dy) }
                let layers = pose.under.map(grid) + [body] + pose.layers.map(grid) + fixed
                return PixelGrid(PixelGrid.layered(layers).rows, palette: palette).makeImage()
            }
            return SpriteFrame(image: images[0], dx: pose.dx, dy: pose.dy, hold: pose.hold,
                               flicker: images.count > 1 ? images : [])
        }
        func dress(_ clip: SpriteClip) -> SpriteClip {
            SpriteClip(name: clip.name, frames: clip.frames.map(dress), fps: clip.fps, loops: clip.loops, quote: clip.quote)
        }

        // Tout est habillé une fois pour toutes : `rest` et `activityClip` sont lus à chaque image.
        let clawd = AvatarRepertoire.clawd
        let rests = Dictionary(uniqueKeysWithValues: AvatarMood.gallery.map { ($0, dress(clawd.rest($0))) })
        let activities = Dictionary(uniqueKeysWithValues: AvatarActivity.allCases.map { ($0, dress(clawd.activityClip($0))) })
        let stand = dress(clawd.stand)
        return AvatarRepertoire(
            width: width, height: height, pixelScale: pixelScale,
            shadow: PixelGrid(shadow, palette: palette).makeImage(),
            flickerFPS: bodyFlicker.isEmpty ? nil : flickerFPS,
            stand: stand,
            sleeping: dress(clawd.sleeping),
            rest: { rests[$0] ?? stand },
            activityClip: { activities[$0]! },
            hop: dress(clawd.hop), wave: dress(clawd.wave), cheer: dress(clawd.cheer),
            raiseHand: dress(clawd.raiseHand), push: dress(clawd.push),
            fallAsleep: dress(clawd.fallAsleep), snore: dress(clawd.snore), wake: dress(clawd.wake),
            idle: clawd.idle.map { (dress($0.clip), $0.weight, $0.drowsy) }
                + gestures.map { (SpriteClip(name: $0.name, frames: $0.poses.map(pose), fps: $0.fps), $0.weight, $0.drowsy) },
            wonder: clawd.wonder.map(dress)
        )
    }
}

/// Brouillon de pixels modifiable, pour composer un personnage à partir de textures (voir `MinecraftSkins`).
struct Sketch {
    private var px: [[Character]]

    init(_ width: Int, _ height: Int) {
        px = Array(repeating: Array(repeating: ".", count: width), count: height)
    }

    var rows: [String] { px.map { String($0) } }

    /// Pose `lines` en (x, y), chaque pixel agrandi `scale` fois ; `.` reste transparent, ce qui déborde est rogné.
    mutating func stamp(_ lines: [String], x: Int, y: Int, scale: Int = 1) {
        for (j, line) in lines.enumerated() {
            for (i, ch) in line.enumerated() where ch != "." {
                for dy in 0..<scale {
                    for dx in 0..<scale {
                        let tx = x + i * scale + dx, ty = y + j * scale + dy
                        if px.indices.contains(ty), px[ty].indices.contains(tx) { px[ty][tx] = ch }
                    }
                }
            }
        }
    }

    var mirrored: Sketch {
        var copy = self
        copy.px = px.map { Array($0.reversed()) }
        return copy
    }

    /// Contour `K` d'un pixel autour de tout ce qui est dessiné (lisible sur le noir du notch).
    var outlined: Sketch {
        var copy = self
        for y in px.indices {
            for x in px[y].indices where px[y][x] == "." {
                let around = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
                if around.contains(where: { px.indices.contains($0.1) && px[$0.1].indices.contains($0.0) && px[$0.1][$0.0] != "." }) {
                    copy.px[y][x] = "K"
                }
            }
        }
        return copy
    }
}
