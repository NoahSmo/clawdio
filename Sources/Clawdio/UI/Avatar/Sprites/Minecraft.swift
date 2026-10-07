/// Personnages Minecraft, en version « chibi » : la tête d'après la vraie texture du jeu (8 × 8 texels, c'est elle qui
/// les rend reconnaissables), un corps court et des jambes en dessous. Un texel = 2 pixels d'un canevas 32 × 30 aux
/// pixels deux fois plus petits que ceux de Clawd : même place à l'écran, deux fois plus de détail. Les accessoires de
/// Clawd sont agrandis ×2 (`AvatarSkin.propScale`) et gardent donc leur taille.
///
/// Repères (pixels du canevas) : tête en (8, 2)–(23, 17), corps lignes 18–21, jambes 22–27, ombre 26–29 ; les yeux
/// de la texture sont un calque à part, pour cligner et regarder de côté.
enum MinecraftSkins {
    private static let width = 32, height = 30
    private static let head = (x: 8, y: 2)

    /// Texels (8 de large) posés sous la tête ou à un autre endroit, agrandis ×2, contour ajouté.
    private static func figure(head texture: [String], body: [String], bodyX: Int = 8) -> [String] {
        var sketch = Sketch(width, height)
        sketch.stamp(texture, x: head.x, y: head.y, scale: 2)
        sketch.stamp(body, x: bodyX, y: 18, scale: 2)
        return sketch.outlined.rows
    }

    /// Jambes (texels sous le corps, ligne 22) : contour sur les côtés et en bas seulement, pour ne pas mordre le corps.
    private static func legs(_ texels: [String]) -> [String] {
        var sketch = Sketch(width, height)
        sketch.stamp(texels, x: 8, y: 22, scale: 2)
        return sketch.outlined.rows.enumerated().map { y, row in y < 22 ? String(repeating: ".", count: width) : row }
    }

    /// Yeux de la texture (rangées de 8 texels), à partir de la ligne `row` de la tête.
    private static func eyes(_ texels: [String], row: Int) -> [String] {
        var sketch = Sketch(width, height)
        sketch.stamp(texels, x: head.x, y: head.y + row * 2, scale: 2)
        return sketch.rows
    }

    /// Mini-têtes posées au sol de part et d'autre : la texture, yeux compris, à 1 pixel par texel (8 × 8).
    private static func minis(_ texture: [String], eyes: [String], row: Int) -> [String] {
        var face = Sketch(8, 8)
        face.stamp(texture, x: 0, y: 0)
        face.stamp(eyes, x: 0, y: row)
        var sketch = Sketch(width, height)
        sketch.stamp(face.rows, x: 0, y: 19)
        sketch.stamp(face.rows, x: width - 8, y: 19)
        return sketch.rows
    }

    private static let shadow: [String] = {
        var sketch = Sketch(width, height)
        sketch.stamp([String(repeating: "s", count: 20)], x: 6, y: 26)
        sketch.stamp([String(repeating: "s", count: 20)], x: 6, y: 27)
        sketch.stamp([String(repeating: "s", count: 16)], x: 8, y: 28)
        sketch.stamp([String(repeating: "s", count: 16)], x: 8, y: 29)
        return sketch.rows
    }()

    private static func skin(
        head: [String], body: [String], bodyX: Int = 8, legs: [String], eyes: (open: [String], closed: [String], row: Int),
        arm: [String]? = nil, armX: Int = 0, raises: Bool = true, colors: [Character: PixelColor]
    ) -> AvatarSkin {
        AvatarSkin(
            width: width, height: height, pixelScale: 0.5, propScale: 2, propOffset: (0, -2),
            body: figure(head: head, body: body, bodyX: bodyX),
            shadow: shadow,
            eyesOpen: Self.eyes(eyes.open, row: eyes.row),
            eyesClosed: Self.eyes(eyes.closed, row: eyes.row),
            arm: arm, armX: armX, armRow: 18, raises: raises,
            legs: Self.legs(legs),
            minis: minis(head, eyes: eyes.open, row: eyes.row),
            colors: colors
        )
    }

    /// Creeper : la célèbre face (yeux carrés, bouche en « T » renversé), vert moucheté, quatre pattes, pas de bras.
    /// Il ne cligne pas : il plisse les yeux (la moitié haute s'efface).
    static let creeper = skin(head: [
        "HHOHHOHH",
        "OHOOSOHO",
        "OOSOOOOO",
        "OSOOOOSO",
        "OOOaaOSO",
        "OSaaaaOO",
        "SOaaaaOO",
        "OOaOOaSO",
    ], body: [
        "OSOOSOOS",
        "SOOSOSOO",
    ], legs: [
        "OSO..SOO",
        "SOS..OSO",
        "ccc..ccc",
    ], eyes: ([".aa..aa.", ".aa..aa."], ["........", ".aa..aa."], 2), colors: [
        "K": PixelColor(0x0F2A0C), "H": PixelColor(0x8EDB7C), "O": PixelColor(0x5CBA47), "S": PixelColor(0x3F8F31),
        "c": PixelColor(0x2C6B22), "a": PixelColor(0x0C1F0A), "E": PixelColor(0x0C1F0A),
    ])

    /// Steve : cheveux bruns, yeux blanc et bleu, nez et bouche, tee-shirt cyan à col en V, pantalon bleu.
    static let steve = skin(head: [
        "HHHHHHHH",
        "HHHHHHHH",
        "HOOOOOOH",
        "OOOOOOOO",
        "OOOOOOOO",
        "OOObbOOO",
        "OObbbbOO",
        "OOOOOOOO",
    ], body: [
        "cccOOccc",
        "cccccccc",
    ], legs: [
        "eeeeeeee",
        "eeeeeeee",
        "ffffffff",
    ], eyes: ([".wE..Ew."], [".SS..SS."], 4), arm: [
        "cccc", "cccc", "cccc", "cccc",
        "OOOO", "OOOO", "OOOO", "SSSS",
    ], armX: 4, colors: [
        "K": PixelColor(0x1E140C), "H": PixelColor(0x3B2615), "O": PixelColor(0xC79A78), "S": PixelColor(0xA0745A),
        "b": PixelColor(0x6E4630), "c": PixelColor(0x25A3A3), "e": PixelColor(0x3A3AA0), "f": PixelColor(0x5A5A5A),
        "w": PixelColor(0xFFFFFF), "E": PixelColor(0x4D3C99),
    ])

    /// Enderman : tête noire aux yeux violets, corps et jambes très fins, longs bras jusqu'au sol.
    static let enderman = skin(head: [
        "HHHHHHHH",
        "OOOSOOOO",
        "OOOOOOSO",
        "OSOOOOOO",
        "OOOOOOOO",
        "OOOOSOOO",
        "OOOOOOOO",
        "OSOOOOOO",
    ], body: [
        "OOOO",
        "OSOO",
    ], bodyX: 12, legs: [
        "..O..O..",
        "..O..O..",
        "..S..S..",
    ], eyes: (["aba..aba"], ["........"], 4), arm: [
        "OO", "OO", "OO", "OO", "OO", "OO", "OO", "OO", "SS",
    ], armX: 9, raises: false, colors: [
        "K": PixelColor(0x5A4A6E), "H": PixelColor(0x2C2C34), "O": PixelColor(0x18181D), "S": PixelColor(0x0E0E12),
        "a": PixelColor(0xCC33FF), "b": PixelColor(0xF2A6FF), "E": PixelColor(0xCC33FF),
    ])

    /// Cochon : tout rose, groin clair à deux narines, yeux noir et blanc sur les côtés, sabots plus sombres.
    static let pig = skin(head: [
        "HHHHHHHH",
        "OOOOOOOO",
        "OOOOOOOO",
        "OOOOOOOO",
        "OOOOOOOO",
        "OOddddOO",
        "OOeddeOO",
        "OOddddOO",
    ], body: [
        "OOOOOOOO",
        "SOOOOOOS",
    ], legs: [
        "OOO..OOO",
        "OOO..OOO",
        "SSS..SSS",
    ], eyes: (["Ew....wE"], ["SS....SS"], 4), colors: [
        "K": PixelColor(0x5E2A2E), "H": PixelColor(0xF7BDBD), "O": PixelColor(0xF09C9C), "S": PixelColor(0xCF7A7C),
        "d": PixelColor(0xF7B6B9), "e": PixelColor(0x7A3A3E), "w": PixelColor(0xFFFFFF), "E": PixelColor(0x1A1010),
    ])
}
