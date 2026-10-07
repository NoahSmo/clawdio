/// Personnages du Studio Ghibli, dessinés sur un canevas 32 × 30 aux pixels deux fois plus petits que ceux de Clawd
/// (même place à l'écran, deux fois plus de détail), et animés par les clips de Clawd (voir `AvatarSkin`).
///
/// Repères (pixels du canevas) : yeux vers les lignes 7–11, au-dessus du livre et du laptop tenus devant eux
/// (lignes 12–21) ; pieds jusqu'à la ligne 27 ; ombre 26–29. Pour déléguer, tous appellent des Noiraudes — les boules
/// de suie qui portent le charbon dans « Le Voyage de Chihiro ».
///
/// Dessins générés avec des formes simples (ellipses, contour automatique) puis figés ici en texte.
enum GhibliSkins {
    private static let shadow: [String] = {
        var sketch = Sketch(32, 30)
        sketch.stamp([String(repeating: "s", count: 20), String(repeating: "s", count: 20)], x: 6, y: 26)
        sketch.stamp([String(repeating: "s", count: 16), String(repeating: "s", count: 16)], x: 8, y: 28)
        return sketch.rows
    }()

    /// Deux Noiraudes au sol de part et d'autre (8 × 8), `Q` suie, `I` contour.
    private static let minis: [String] = {
        let soot = [
            ".I.II.I.",
            "IQQQQQQI",
            "IQWQQWQI",
            "IQEQQEQI",
            "IQQQQQQI",
            ".IQQQQI.",
            "..I..I..",
            "..I..I..",
        ]
        var sketch = Sketch(32, 30)
        sketch.stamp(soot, x: 0, y: 20)
        sketch.stamp(soot, x: 24, y: 20)
        return sketch.rows
    }()

    /// Calque du canevas : `lines` posées à partir de la ligne `row`.
    static func layer(_ row: Int, _ lines: [String]) -> [String] {
        var sketch = Sketch(32, 30)
        sketch.stamp(lines, x: 0, y: row)
        return sketch.rows
    }

    private static let sootColors: [Character: PixelColor] = ["Q": PixelColor(0x141416), "I": PixelColor(0x5A5A62)]

    private static func skin(
        body: [String], flicker: [[String]] = [], eyesOpen: [String], eyesClosed: [String], legs: [String]? = nil,
        arm: [String]? = nil, armX: Int = 0, armRow: Int = 0, gestures: [AvatarSkin.Gesture] = [],
        height: Int = 30, shadow: [String]? = nil, colors: [Character: PixelColor]
    ) -> AvatarSkin {
        // Un canevas plus haut garde les accessoires et les Noiraudes à la même distance du bas.
        let extra = height - 30
        var minis = Sketch(32, height)
        minis.stamp(Self.minis, x: 0, y: extra)
        return AvatarSkin(
            width: 32, height: height, pixelScale: 0.5, propScale: 2, propOffset: (0, -2 + extra),
            body: body, bodyFlicker: flicker, shadow: shadow ?? Self.shadow, eyesOpen: eyesOpen, eyesClosed: eyesClosed,
            arm: arm, armX: armX, armRow: armRow, legs: legs, minis: minis.rows, gestures: gestures,
            colors: colors.merging(sootColors) { mine, _ in mine }
        )
    }

    /// Totoro : gros esprit gris de la forêt, oreilles pointues, ventre crème marqué de chevrons, moustaches,
    /// petits bras courts et griffes.
    static let totoro = totoro(["K": PixelColor(0x26272B), "H": PixelColor(0xA9AEB3), "O": PixelColor(0x80868C), "S": PixelColor(0x5E636A), "a": PixelColor(0xECE3CC), "b": PixelColor(0x6A6F75), "E": PixelColor(0x1A1A1A)])

    private static func totoro(_ colors: [Character: PixelColor]) -> AvatarSkin {
        skin(body: layer(0, [
            "..........KHK........KHK........",
            ".........KHHHK......KHHHK.......",
            ".........KHOHK......KHOHK.......",
            "........KHOOOHKKKKKKHOSSHK......",
            "........KHOOOHHHHHHHHOOOHK......",
            "........KKOOOOHHHHHHOOKKK.......",
            ".......KHHOOOOOOOOOOOOHHK.......",
            ".......KHHOOOOOOOOOOOOHHK.......",
            "......KHOOOOOOOOOOOOOOOOHK......",
            "......KHOOOOOOOOOOOOOOOOHK......",
            "......KOOOOOOOOOOOOOOOOOOK......",
            ".....KbbbOOOOOOEEOOOOOObbbK.....",
            "......KOOOOOOOOOEOOOOOOOOK......",
            ".....KbbbOOOOOOOOOOOOOObbbK.....",
            ".....KHOOOOOOaaaaaaOOOOOOHK.....",
            "....KHHOOOOaaaaaaaaaaOOOOHHK....",
            "...KHHOOOaaaaaaabaaaaaaOOOHHK...",
            "...KHOOOaaaabaababaabaaaOOOHK...",
            "...KOOOOaaababaaaaababaaOOOOK...",
            "..KHOOOOaaaaaaaaaaaaaaaaOOOOHK..",
            "...KOOOaaaaaaabaaabaaaaaaOOOK...",
            "...KSOOOaaaaababababaaaaOOOSK...",
            "...KSSOOaaaaaaaaaaaaaaaaOOSSK...",
            "....KSSOaaaaaaaaaaaaaaaaOSSK....",
            ".....KSSSaaaaaaaaaaaaaaSSSK.....",
            "......KSSSSaaaaaaaaaaSSSSK......",
            ".......KKSSSSaaaaaaSSSSKK.......",
            ".........KKKKKKKKKKKKKK.........",
        ]), eyesOpen: layer(8, [
            "............WW.......WW.........",
            "...........WWEW.....WWEW........",
            "...........WWEW.....WWEW........",
            "............WW.......WW.........",
        ]), eyesClosed: layer(10, [
            "...........KKKK.....KKKK........",
        ]), legs: layer(25, [
            "........KOOOOOK..KOOOOOK........",
            "........KOaOaOK..KOaOaOK........",
            "........KKKKKKK..KKKKKKK........",
            ".........KKKKK....KKKKK.........",
        ]), arm: ["OO.", "OOO", "OOO", "OOO", "SOO", "SSO"], armX: 3, armRow: 14, colors: colors)
    }

    /// Chu-Totoro : le Totoro moyen, bleu (mêmes dessins, autres couleurs).
    static let chuTotoro = totoro(["K": PixelColor(0x1C2A44), "H": PixelColor(0x7FA6DA), "O": PixelColor(0x4C79B8), "S": PixelColor(0x355A8E), "a": PixelColor(0xE4ECF6), "b": PixelColor(0x3A5F94), "E": PixelColor(0x1A1A1A)])

    /// Sans-Visage : silhouette noire évasée, masque blanc aux marques violettes, ni bras ni jambes.
    static let noFace = skin(body: layer(1, [
        "............KKKKKKKK............",
        "...........KHHHHHHHHK...........",
        "..........KHOOOOOOOOHK..........",
        ".........KHOOOaaaaOOOHK.........",
        ".........KHOObaaaabOOOK.........",
        "........KHOOaabaabaaOOHK........",
        "........KHOaaaaaaaaaaOOK........",
        "........KHOaaaaaaaaaaOOK........",
        "........KHOaaaaaaaaaaOOK........",
        ".......KHOOaaaaaaaaaaOOHK.......",
        ".......KHOOaabaaaabaaOOOK.......",
        ".......KHOOaabaaaabaaOOOK.......",
        ".......KHOOaabaaaabaaOOOK.......",
        "......KHOOOOaaaaaaaaOOOOHK......",
        "......KHOOOOOaacccaOOOOOOK......",
        "......KHOOOOOOaaaaOOOOOOOK......",
        "......KHOOOOOOOOOOOOOOOOOK......",
        ".....KHOOOOOOOOOOOOOOOOOOHK.....",
        ".....KHOOOOOOOOOOOOOOOOOOOK.....",
        ".....KHOOOOOOOOOOOOOOOOOOOK.....",
        ".....KHOOOOOOOOOOOOOOOOOOOK.....",
        "....KHOOOOOOOOOOOOOOOOOOOOHK....",
        "....KHOOOOOOOOOOOOOOOOOOOOOK....",
        "....KHOOOOOOOOOOOOOOOOOOOOOK....",
        "....KHOOOOOOOOOOOOOOOOOOOOOK....",
        "...KHOOOOOOOOOOOOOOOOOOOOOOHK...",
        "...KHOOOOOOOOOOOOOOOOOOOOOOOK...",
        "....KKKKKKKKKKKKKKKKKKKKKKKK....",
    ]), eyesOpen: layer(8, [
        ".............EE..EE.............",
        ".............EE..EE.............",
    ]), eyesClosed: layer(9, [
        ".............EE..EE.............",
    ]), colors: ["K": PixelColor(0x5C5C6E), "H": PixelColor(0x2E2E38), "O": PixelColor(0x1B1B22), "S": PixelColor(0x101016), "a": PixelColor(0xF1EEE6), "b": PixelColor(0x7B4FA0), "c": PixelColor(0x8E8A86), "E": PixelColor(0x141414)])

    /// Noiraude : boule de suie hérissée, grands yeux blancs, pattes et bras en allumettes.
    static let soot = skin(body: layer(0, [
        "...............K................",
        "............K.KHKK.K............",
        "..........KKHKHKKOKOKK..........",
        "........KKHKHHOHOOOOKOKK........",
        ".......KHKHHOOOOOOOOOOKOK.......",
        "......KKHHOOOOOOOOOOOOOOKK......",
        ".....KHKHOOOOOOOOOOOOOOOKOK.....",
        "......KHOOOOOOOOOOOOOOOOOK......",
        ".....KHOOOOOOOOOOOOOOOOOOOK.....",
        ".....KHOOOOOOOOOOOOOOOOOOOK.....",
        "....KHOOOOOOOOOOOOOOOOOOOOOK....",
        ".....KHOOOOOOOOOOOOOOOOOOOK.....",
        "....KOOOOOOOOOOOOOOOOOOOOOOK....",
        "....KOOOOOOOOOOOOOOOOOOOOOOK....",
        ".....KOOOOOOOOOOOOOOOOOOOOK.....",
        ".....KOOOOOOOOOOOOOOOOOOOOK.....",
        "......KOOOOOOOOOOOOOOOOOOK......",
        ".....KOKOOOOOOOOOOOOOOOOKOK.....",
        "......KKOOOOOOOOOOOOOOOOKK......",
        ".......KOKOOOOOOOOOOOOKOK.......",
        "........KKOKOOOOOOOOKOKK........",
        "..........KKOKOKKOKOKK..........",
        "............K.KKOK.K............",
        "................K...............",
    ]), eyesOpen: layer(6, [
        "..........WWW......WWW..........",
        ".........WWWWW....WWWWW.........",
        ".........WWEEW....WWEEW.........",
        ".........WWEEW....WWEEW.........",
        "..........WWW......WWW..........",
    ]), eyesClosed: layer(9, [
        "..........WWW......WWW..........",
    ]), legs: layer(22, [
        "............KOK...KOK...........",
        "............KOK...KOK...........",
        "............KOK...KOK...........",
        "............KOK...KOK...........",
        "...........KOOK..KOOK...........",
        "............KK....KK............",
    ]), arm: ["O", "O", "O", "O"], armX: 4, armRow: 13, colors: ["K": PixelColor(0x5A5A62), "H": PixelColor(0x2C2C30), "O": PixelColor(0x141416), "S": PixelColor(0x0A0A0C), "E": PixelColor(0x111111)])

    /// Calcifer, comme sur l'affiche du film : grande goutte de feu à la pointe recourbée, deux langues sur les côtés
    /// et des gouttes de flamme qui s'échappent ; rouge dehors, orange, puis un grand visage jaune. Grands yeux ronds
    /// cerclés de sombre, large sourire fermé qui ne s'ouvre que quand il bavarde ou mange (voir `CalciferFood`). Posé
    /// sur une bûche couchée, dessinée avec la lueur au sol dans l'ombre : elle ne bouge pas quand il saute ou glisse.
    /// Canevas plus haut (34) pour la pointe ; quatre images de flammes qui se relaient en continu (`bodyFlicker`).
    static let calcifer = skin(
        body: CalciferFood.layer(0, [
            "................KHK.............",
            "...............KHHK.............",
            "..............KHOOHK........KK..",
            "..............KHOOHK......KKOOK.",
            ".............KHOOOOHK....KHKOOK.",
            ".....K......KHOOOOOHK...KHHOOOOK",
            "....KHK...KKHOOOOOOOHK.KHHHOOOOK",
            "....KHHKKKHHOOOOOOOOOHKHOHKKOOK.",
            "....KHOHHHOOOOOOOOOOOOHOOHK.KK..",
            "....KHOOOOOOOOOOOOOOOOOOOHK.....",
            "..K..KHOOOOOOOOOOOOOOOOOOHK.....",
            ".KOKKHOOOOOaaaaaaaaaaOOOOOHK....",
            ".KOKKHOOOaaaaaaaaaaaaaaOOOHK....",
            "KOOOHOOOaaaaaaaaaaaaaaaaOOOHK...",
            "KOOOHOOaaaaaaaaaaaaaaaaaaOOHK...",
            "KOOOHOOaaaaaaaaaaaaaaaaaaOOHK...",
            ".KOKHOaaaaaabbbbbbbbaaaaaaOHK...",
            "..KKHOaaaaabbbbbbbbbbaaaaaOHK...",
            "....KHOaaabbbbbbbbbbbbaaaOHK....",
            "....KHOaaabbbbbbbbbbbbaaaOHK....",
            ".....KHOaabbbbbbbbbbbbaaOHK.....",
            ".....KHOaabbbbbbbbbbbbaaOHK.....",
            "......KHOaabbbbbbbbbbaaOHK......",
            "......KHOaaabbbbbbbbaaaOHK......",
        ]),
        flicker: [
            CalciferFood.layer(0, [
                "..............KHK...........KOK.",
                "..............KHK..........KOOOK",
                ".............KHOHK.........KOOOK",
                ".............KHOOHK........KOOOK",
                "....K.......KHOOOHK.........KOK.",
                "...KHKK....KHOOOOOHK......K..K..",
                "....KHHK..KKHOOOOOOHKK..KKHK....",
                "..K.KHOHKKHHOOOOOOOOHHKKHHHK....",
                ".KOKKHOOHHOOOOOOOOOOOOHHOOHK....",
                ".KOKKHOOOOOOOOOOOOOOOOOOOOHK....",
                "KOOOKHOOOOOOOOOOOOOOOOOOOHK.....",
                "KOOOKHOOOOOaaaaaaaaaaOOOOOHK....",
                "KOOOKHOOOaaaaaaaaaaaaaaOOOHK....",
                ".KOKHOOOaaaaaaaaaaaaaaaaOOOHK...",
                "..KKHOOaaaaaaaaaaaaaaaaaaOOHK...",
                "...KHOOaaaaaaaaaaaaaaaaaaOOHK...",
                "...KHOaaaaaabbbbbbbbaaaaaaOHK...",
                "...KHOaaaaabbbbbbbbbbaaaaaOHK...",
                "....KHOaaabbbbbbbbbbbbaaaOHK....",
                "....KHOaaabbbbbbbbbbbbaaaOHK....",
                ".....KHOaabbbbbbbbbbbbaaOHK.....",
                ".....KHOaabbbbbbbbbbbbaaOHK.....",
                "......KHOaabbbbbbbbbbaaOHK......",
                "......KHOaaabbbbbbbbaaaOHK......",
            ]),
            CalciferFood.layer(0, [
                "..............K.................",
                ".............KHK................",
                ".............KHHK...............",
                ".....K......KHOOHK..............",
                "....KHK.....KHOOHK..............",
                "..KKKHHK...KHOOOOHKK........KK..",
                ".KOOKHHHK.KHOOOOOOHHKK...KKKOOK.",
                ".KOOKHOOHKHOOOOOOOOOHHKKKHHKOOK.",
                ".KOOKHOOOHOOOOOOOOOOOOHHHHKKOOK.",
                "KOOOOHOOOOOOOOOOOOOOOOOOOHKOOOOK",
                ".KOOKKHOOOOOOOOOOOOOOOOOOHKKOOK.",
                "..KKKHOOOOOaaaaaaaaaaOOOOOHKKK..",
                "....KHOOOaaaaaaaaaaaaaaOOOHK....",
                "...KHOOOaaaaaaaaaaaaaaaaOOOHK...",
                "...KHOOaaaaaaaaaaaaaaaaaaOOHK...",
                "...KHOOaaaaaaaaaaaaaaaaaaOOHK...",
                "...KHOaaaaaabbbbbbbbaaaaaaOHK...",
                "...KHOaaaaabbbbbbbbbbaaaaaOHK...",
                "....KHOaaabbbbbbbbbbbbaaaOHK....",
                "....KHOaaabbbbbbbbbbbbaaaOHK....",
                ".....KHOaabbbbbbbbbbbbaaOHK.....",
                ".....KHOaabbbbbbbbbbbbaaOHK.....",
                "......KHOaabbbbbbbbbbaaOHK......",
                "......KHOaaabbbbbbbbaaaOHK......",
            ]),
            CalciferFood.layer(0, [
                "...............KHK..............",
                "...............KHK..............",
                "..KK..........KHOHK.............",
                ".KOOK........KHOOHK.............",
                ".KOOK.K......KHOOOHK.....K......",
                "KOOOOKHK....KHOOOOOHK...KHK.....",
                "KOOOOKHHK.KKHOOOOOOHKK.KHHK.....",
                ".KOOKKHOHKHHOOOOOOOOHHKHOHK.....",
                "..KK.KHOOHOOOOOOOOOOOOHOOHK..K..",
                ".....KHOOOOOOOOOOOOOOOOOOHK.KOK.",
                ".....KHOOOOOOOOOOOOOOOOOOHK.KOK.",
                "....KHOOOOOaaaaaaaaaaOOOOOHKOOOK",
                "....KHOOOaaaaaaaaaaaaaaOOOHKOOOK",
                "...KHOOOaaaaaaaaaaaaaaaaOOOHOOOK",
                "...KHOOaaaaaaaaaaaaaaaaaaOOHKOK.",
                "...KHOOaaaaaaaaaaaaaaaaaaOOHKK..",
                "...KHOaaaaaabbbbbbbbaaaaaaOHK...",
                "...KHOaaaaabbbbbbbbbbaaaaaOHK...",
                "....KHOaaabbbbbbbbbbbbaaaOHK....",
                "....KHOaaabbbbbbbbbbbbaaaOHK....",
                ".....KHOaabbbbbbbbbbbbaaOHK.....",
                ".....KHOaabbbbbbbbbbbbaaOHK.....",
                "......KHOaabbbbbbbbbbaaOHK......",
                "......KHOaaabbbbbbbbaaaOHK......",
            ]),
        ],
        eyesOpen: CalciferFood.face,
        eyesClosed: CalciferFood.asleep,
        gestures: CalciferFood.gestures,
        height: CalciferFood.height,
        shadow: CalciferFood.logAndGlow,
        colors: calciferColors.merging(CalciferFood.colors) { mine, _ in mine }
    )

    private static let calciferColors: [Character: PixelColor] = [
        "K": PixelColor(0x5A1505),
        "H": PixelColor(0xE8401C),
        "O": PixelColor(0xF5821F),
        "a": PixelColor(0xFFC23A),
        "b": PixelColor(0xFFE27A),
        "d": PixelColor(0x3A0A04),
        "e": PixelColor(0xD8302A),
        "C": PixelColor(0xFF8A2A),
        "A": PixelColor(0xFFB347),
        "E": PixelColor(0x1A0A05),
        "s": PixelColor(0xFF8A2A, alpha: 0.3),
    ]

    /// Jiji : le chat noir de Kiki, assis, grands yeux blancs, queue enroulée.
    static let jiji = skin(body: layer(0, [
        "........K..............K........",
        ".......KHK............KHK.......",
        ".......KOHK..........KHOK.......",
        ".......KObHKKKKKKKKKKHbOK.......",
        ".......KObOHHHHHHHHHHObOK.......",
        "........KKOOOOOOOOOOOOKK........",
        "........KHOOOOOOOOOOOOHK........",
        ".......KHOOOOOOOOOOOOOOHK.......",
        ".......KOOOOOOOOOOOOOOOOK.......",
        ".......KOOOOOOOOOOOOOOOOK.......",
        ".......KOOOOOOOOOOOOOOOOK.......",
        ".......KOOOOOOOOOOOOOOOOK.......",
        ".......KOOOOOOOObOOOOOOOK.......",
        "........KOOOOOOcOcOOOOOK........",
        ".........KOOOOOOOOOOOOK...KK....",
        "..........KOOOOOOOOOOK...KHHK...",
        ".........KHOOOOOOOOOOHK...KOK...",
        "........KHOOOOOOOOOOOOHK..KOK...",
        "........KOOOOOOOOOOOOOOK.KHOK...",
        "........KOOOOOOOOOOOOOOKKHOK....",
        "........KOOOOOOOOOOOOOOK.KK.....",
        "........KOOOOOOOOOOOOOOK........",
        "........KOOOOOOOOOOOOOOK........",
        ".........KOOOOOOOOOOOOK.........",
        "..........KOOOOOOOOOOK..........",
        "...........KOOOOOOOOK...........",
        "............KKKKKKKK............",
    ]), eyesOpen: layer(7, [
        "...........WWW.....WWW..........",
        "..........WWWWW...WWWWW.........",
        "..........WWEWW...WWEWW.........",
        "..........WWEWW...WWEWW.........",
        "...........WWW.....WWW..........",
    ]), eyesClosed: layer(10, [
        "...........WWW.....WWW..........",
    ]), legs: layer(25, [
        "...........KOOOKKOOOK...........",
        "...........KOOOKKOOOK...........",
        "............KKK..KKK............",
    ]), colors: ["K": PixelColor(0x5A5A6A), "H": PixelColor(0x2E2E3A), "O": PixelColor(0x17171E), "b": PixelColor(0x8A4A5A), "c": PixelColor(0x5A5A6A), "E": PixelColor(0x111111)])
}
