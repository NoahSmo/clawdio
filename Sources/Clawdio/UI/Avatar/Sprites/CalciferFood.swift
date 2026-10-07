/// Visage, bûche et gestes de repos de Calcifer (`AvatarSkin.gestures`), tirés au sort avec ceux de Clawd. Une seule
/// action par geste, le reste du corps continue de flamber.
///
/// - **bavardage** : bouche fermée au repos, elle s'entrouvre, s'ouvre grand et se referme quelques fois ;
/// - **bacon** : une tranche tombe d'en haut, il la suit des yeux, ouvre grand la bouche, mâche, et flambe de joie ;
/// - **œufs** : Hurle fait cuire ses œufs sur lui — une poêle se pose sur sa tête (il fait la tête), les œufs
///   grésillent, la poêle repart ; puis il avale une coquille, qu'il adore ;
/// - **bûche** : on lui donne une bûche, il l'avale et ses flammes montent ;
/// - **glissade** : il glisse de sa bûche, s'y retrouve accroché derrière (seuls ses yeux et ses petites mains
///   dépassent), puis remonte dessus d'un bond.
///
/// Repères (canevas 32 × 34) : yeux lignes 10–16, bouche 17–21, bûche 23–31, lueur au sol 32–33.
enum CalciferFood {
    static let height = 34

    /// Calque du canevas de Calcifer : `lines` posées à partir de la ligne `row`.
    static func layer(_ row: Int, _ lines: [String]) -> [String] {
        shifted(lines, row)
    }

    /// Calque décalé verticalement (les lignes qui sortent du canevas sont rognées).
    private static func shifted(_ rows: [String], _ dy: Int) -> [String] {
        var sketch = Sketch(32, height)
        sketch.stamp(rows, x: 0, y: dy)
        return sketch.rows
    }

    private static func merged(_ layers: [String]...) -> [String] {
        var sketch = Sketch(32, height)
        for layer in layers { sketch.stamp(layer, x: 0, y: 0) }
        return sketch.rows
    }

    // MARK: Bûche

    /// La bûche couchée sous lui, bois `f` veiné `j`, bout coupé à droite (cernes `k` `m`), contour `i`.
    private static let log = layer(23, [
        "...iiiiiiiiiiiiiiiiiiiiiiiiii...",
        "..iffffffffffffffffffffffikkki..",
        ".ifffffffffffffjjfffffffikkkkki.",
        "ifffjjjffjjjjjfffffjjjjfikmmmki.",
        "ifffjfjjffffffffffffffffikmkmki.",
        "ifffjjfjffffjjjjjjffffffikmkmki.",
        "iffffjjjfffffffffffffjjjikmmmki.",
        ".iffffjjjjffffjjjfffffffikkkkki.",
        "..iffffffffffffffffffffffikkki..",
    ])

    /// Bûche et lueur orange au sol, à la place de l'ombre : fixes, elles ne suivent ni les sauts ni la glissade.
    static let logAndGlow = merged(log, layer(32, [
        "...ssssssssssssssssssssssssss...",
        "......ssssssssssssssssssss......",
    ]))

    // MARK: Visage

    private static let eyes = layer(10, [
        ".........KKKK......KKKK.........",
        "........KWWWWK....KWWWWK........",
        ".......KWWWWWWK..KWWWWWWK.......",
        ".......KWWEEWWK..KWWEEWWK.......",
        ".......KWWEEWWK..KWWEEWWK.......",
        "........KWWWWK....KWWWWK........",
        ".........KKKK......KKKK.........",
    ])
    /// Bouche fermée au repos : un large sourire tranquille (ouverte en permanence, elle faisait peur).
    private static let calm = layer(18, [
        "...........d........d...........",
        "............dddddddd............",
    ])
    /// Grande bouche ouverte, rouge, langue orange.
    private static let smile = layer(17, [
        "...........dddddddddd...........",
        "..........deeeeeeeeeed..........",
        "...........deeeeeeeed...........",
        "............deCCCCed............",
        ".............dddddd.............",
    ])
    /// Petit sourire fermé (sommeil, joie, accroché à sa bûche).
    private static let grin = layer(18, [
        "............d......d............",
        ".............dddddd.............",
    ])
    /// Petite bouche ronde : il est surpris.
    private static let oh = layer(18, [
        "..............dddd..............",
        ".............deeeed.............",
        "..............dddd..............",
    ])

    /// Visage au repos : yeux et bouche ensemble, décalés ensemble quand il regarde ailleurs.
    static let face = merged(eyes, calm)
    /// Yeux fermés en ∪ sombres (sur le jaune du visage, ils se voient) et petit sourire.
    static let asleep = merged(layer(13, [
        ".......K......K..K......K.......",
        "........KKKKKK....KKKKKK........",
    ]), grin)

    private static let eyesUp = shifted(eyes, -1)
    private static let eyesDown = shifted(eyes, 1)
    /// Paupières à mi-hauteur : il fait la tête (la poêle sur le crâne).
    private static let grumpy = layer(11, [
        "........KKKKKK....KKKKKK........",
        ".......KKKKKKKK..KKKKKKKK.......",
        ".......KWWEEWWK..KWWEEWWK.......",
        ".......KWWEEWWK..KWWEEWWK.......",
        "........KWWWWK....KWWWWK........",
        ".........KKKK......KKKK.........",
    ])
    /// Yeux plissés de plaisir (∩ blancs cerclés) : des arcs sombres seuls se perdaient dans les flammes.
    private static let happy = layer(11, [
        ".........KKKK......KKKK.........",
        "........KWWWWK....KWWWWK........",
        ".......KWWKKWWK..KWWKKWWK.......",
        ".......KWK..KWK..KWK..KWK.......",
        ".......KK....KK..KK....KK.......",
    ])
    /// Bouche grande ouverte pour avaler.
    private static let gulp = layer(16, [
        "............dddddddd............",
        "...........dddddddddd...........",
        "..........dddeeeeeeddd..........",
        "..........ddeeeeeeeedd..........",
        "...........ddeeeeeedd...........",
        "............dddddddd............",
    ])
    /// Bouche fermée qui mâche, puis entrouverte : les deux temps alternent.
    private static let chew = layer(18, [
        "...........dd......dd...........",
        ".............dddddd.............",
    ])
    private static let chewWide = layer(17, [
        ".............dddddd.............",
        "............deeeeeed............",
        "............deeCCeed............",
        ".............dddddd.............",
    ])

    // MARK: Nourriture

    /// Tranche de bacon ondulée (viande `p`, ruban de gras `u`, bords grillés), en haut à la ligne `top`.
    private static func bacon(_ top: Int) -> [String] {
        var sketch = Sketch(32, height)
        for x in 0..<14 {
            sketch.stamp(["p", "u", "p"], x: 9 + x, y: top + (x / 3) % 2)
        }
        return sketch.outlined.rows
    }

    /// Poêle posée sur sa tête, deux œufs au plat ; `steam` fait alterner les filets de vapeur (le grésillement).
    private static func pan(steam: Bool, lift: Int = 0) -> [String] {
        layer(3 - lift, [
            steam ? "................................" : "..........w..........w..........",
            steam ? ".........w..........w.........." : "................................",
            "........WWWW......WWWW..........",
            ".......WWYYWW....WWYYWW.........",
            "......vvvvvvvvvvvvvvvvvvvv......",
            "......xxxxxxxxxxxxxxxxxxxxvvvvvv",
            ".......xxxxxxxxxxxxxxxxxx.......",
        ])
    }

    /// Demi-coquille d'œuf, bord cassé en haut.
    private static func shell(_ top: Int) -> [String] {
        layer(top, [
            ".............o.oo.o.............",
            ".............oooooo.............",
            ".............otttto.............",
            "..............tttt..............",
        ])
    }

    /// Petite bûche vue de côté, bout incandescent.
    private static func stick(_ top: Int) -> [String] {
        layer(top, [
            "...........iiiiiiiii............",
            "..........ifjjffffffiF..........",
            "..........ifjjffffffi...........",
            "...........iiiiiiiii............",
        ])
    }

    // MARK: Joie

    /// Grandes langues de feu derrière le corps : il flambe de plaisir.
    private static let flare = layer(2, [
        "..............KHHK....KK........",
        "........KK...KHOOHK..KHHK.......",
        ".......KHHK..KHOOHK..KHHK.......",
        ".......KHHK..KHOOHK..KHHK.......",
        ".......KHHK.KHOOOOHK.KHHK.......",
        "......KHOOHKKHOOOOHKKHOOHKKK....",
        "....KKKHOOHKKHOOOOHKKHOOHKHHK...",
        "...KHHKHOOHKKHOOOOHKKHOOHKHHK...",
        "..KHHHKHOOHKHOOOOOOHKHOOHKHHHK..",
        "..KHOHKHOOHKHOOOOOOHHOOOOHHOHK..",
        ".KHOOHOOOOHHOOOOOOOHHOOOOHOOOHK.",
        ".KHOOHOOOOHHOOOOOOOHHOOOOHOOOHK.",
        ".KHOOHOOOOHOOOOOOOOOHOOOOHOOOHK.",
        ".KHOOHOOOOHOOOOOOOOOHOOOOHOOOHK.",
        ".KHOOHOOOOHOOOOOOOOOHOOOOHOOOHK.",
        "..KHOHOOOOHOOOOOOOOOHOOOOHOOHK..",
    ])
    private static let sparks = layer(0, [
        "....A.......................A...",
        "................................",
        ".A............................A.",
    ])

    // MARK: Glissade

    /// Ses petites mains de flamme agrippées au bord de la bûche, par-dessus elle.
    private static let hands = layer(22, [
        "..........KKK.......KKK.........",
        ".........KOaOK.....KOaOK........",
        ".........KOaOK.....KOaOK........",
        "..........KOK.......KOK.........",
    ])

    // MARK: Gestes

    private typealias Pose = AvatarSkin.Gesture.Pose

    /// Il mâche trois fois, yeux plissés.
    private static let chewing: [Pose] = [
        Pose(layers: [happy, chew], hold: 2), Pose(layers: [happy, chewWide], hold: 2),
        Pose(layers: [happy, chew], hold: 2), Pose(layers: [happy, chewWide], hold: 2),
    ]

    /// Corps décalé de (dx, dy), la bûche (fixe) repassée devant lui : il est derrière elle.
    private static func behindLog(_ layers: [[String]], dx: Int, dy: Int, grip: Bool = false, hold: Int = 1) -> Pose {
        Pose(layers: layers, fixed: grip ? [log, hands] : [log], dx: dx, dy: dy, hold: hold)
    }

    static let gestures: [AvatarSkin.Gesture] = [
        // Il bavarde : la bouche s'entrouvre, s'ouvre grand, se referme, sans que rien d'autre ne bouge.
        AvatarSkin.Gesture(name: "chatter", fps: 6, poses: [
            Pose(layers: [eyes, chewWide]), Pose(layers: [eyes, calm]),
            Pose(layers: [eyes, smile], hold: 2), Pose(layers: [eyes, chewWide]),
            Pose(layers: [eyes, calm], hold: 2),
            Pose(layers: [eyes, chewWide]), Pose(layers: [eyes, calm], hold: 2),
            Pose(layers: [happy, grin], hold: 3),
            Pose(layers: [face], hold: 2),
        ], weight: 8),
        AvatarSkin.Gesture(name: "bacon", fps: 8, poses: [
            Pose(layers: [eyesUp, smile, bacon(0)], hold: 2),
            Pose(layers: [eyesUp, gulp, bacon(5)], hold: 2),
            Pose(layers: [eyes, gulp, bacon(10)]),
            Pose(layers: [eyesDown, gulp, bacon(15)]),
        ] + chewing + [
            Pose(layers: [happy, grin, sparks], under: [flare], hold: 4),
            Pose(layers: [face], hold: 2),
        ]),
        AvatarSkin.Gesture(name: "eggs", fps: 6, poses: [
            Pose(layers: [eyesUp, smile, pan(steam: false, lift: 3)]),
            Pose(layers: [grumpy, chew, pan(steam: false)], hold: 3),
            Pose(layers: [grumpy, chew, pan(steam: true)], hold: 3),
            Pose(layers: [grumpy, chew, pan(steam: false)], hold: 3),
            Pose(layers: [grumpy, chew, pan(steam: true)], hold: 3),
            Pose(layers: [eyesUp, smile, pan(steam: false, lift: 3)]),
            Pose(layers: [face], hold: 2),
            Pose(layers: [eyesUp, smile, shell(2)], hold: 2),
            Pose(layers: [eyes, gulp, shell(8)]),
            Pose(layers: [eyesDown, gulp, shell(14)]),
        ] + chewing.dropLast() + [
            Pose(layers: [face], hold: 2),
        ]),
        AvatarSkin.Gesture(name: "log", fps: 8, poses: [
            Pose(layers: [eyesUp, smile, stick(1)], hold: 3),
            Pose(layers: [eyes, gulp, stick(8)], hold: 2),
            Pose(layers: [eyesDown, gulp, stick(14)], hold: 2),
        ] + chewing.dropLast() + [
            Pose(layers: [happy, grin, sparks], under: [flare], hold: 3),
            Pose(layers: [face, sparks], under: [flare], hold: 3),
            Pose(layers: [face], hold: 2),
        ], weight: 4),
        AvatarSkin.Gesture(name: "slip", fps: 8, poses: [
            Pose(layers: [eyesDown, oh], dx: 1, hold: 2),
            Pose(layers: [eyesDown, oh], dx: -1, hold: 2),
            behindLog([eyesUp, oh], dx: 2, dy: 3),
            behindLog([eyesUp, oh], dx: 3, dy: 7),
            behindLog([eyes, oh], dx: 3, dy: 6, grip: true, hold: 4),
            behindLog([eyes, grin], dx: 3, dy: 6, grip: true, hold: 8),
            behindLog([eyes, grin], dx: 3, dy: 5, grip: true, hold: 2),
            behindLog([eyesUp, grin], dx: 2, dy: 3, grip: true, hold: 2),
            behindLog([eyesUp, grin], dx: 1, dy: 1),
            Pose(layers: [happy, grin], dy: -3, hold: 2),
            Pose(layers: [happy, grin, sparks], under: [flare], hold: 3),
            Pose(layers: [face], hold: 2),
        ], weight: 5),
    ]

    /// Couleurs de la bûche et de la nourriture (le blanc `W`, le jaune `Y` et la vapeur `w` sont ceux de la palette
    /// commune).
    static let colors: [Character: PixelColor] = [
        "i": PixelColor(0x2A160A), "f": PixelColor(0x9C5A2C),           // bûche : contour, bois
        "j": PixelColor(0x6A3818), "k": PixelColor(0xD9A066),           // veines ; bout coupé
        "m": PixelColor(0xB07A44),                                      // cernes
        "p": PixelColor(0xC2412F), "u": PixelColor(0xF6D2C0),           // bacon
        "o": PixelColor(0xF4E9D4), "t": PixelColor(0xCDBFA6),           // coquille
        "x": PixelColor(0x2E2E33), "v": PixelColor(0x55555E),           // poêle en fonte
        "F": PixelColor(0xFF7A2A),                                      // bout de bûche qui brûle
    ]
}
