/// Sprites de l'avatar : Clawd face à la caméra (sud), vue de dessus façon JRPG — on voit le sommet de la tête
/// (tons `H`) et la face avant avec les yeux. Canevas 16 × 16 ; les deux lignes du haut restent libres pour les
/// bras levés et les sauts.
///
/// Chaque pose est un empilement de calques (corps, yeux, jambes, bras, effets) : une variante = un calque changé.
enum AvatarSprites {
    static let size = 16

    static func layer(_ row: Int, _ lines: [String]) -> PixelGrid {
        PixelGrid(at: row, lines, palette: AvatarPalette.standard)
    }

    static func pose(_ layers: PixelGrid...) -> SpriteFrame {
        SpriteFrame(image: PixelGrid.layered(layers).makeImage())
    }

    // MARK: Calques

    /// Ombre au sol, dessinée sous le corps et jamais décalée : c'est elle qui ancre le perso quand il saute.
    static let shadow = layer(14, [
        "...ssssssssss...",
        "....ssssssss....",
    ]).makeImage()

    enum Body {
        static let trunk = layer(2, [
            "....KKKKKKKK....",
            "...KHHHHHHHHK...",
            "...KHHHHHHHHK...",
            "...KOOOOOOOOK...",
            "...KOOOOOOOOK...",
            "...KOOOOOOOOK...",
            "...KOOOOOOOOK...",
            "...KOOOOOOOOK...",
            "...KOOOOOOOOK...",
            "...KSSSSSSSSK...",
            "....KKKKKKKK....",
        ])
    }

    enum Eyes {
        static let open = layer(7, [
            ".....E....E.....",
            ".....E....E.....",
        ])
        /// ^ ^ : yeux rieurs (joie).
        static let happy = layer(7, [
            ".....E....E.....",
            "....E.E..E.E....",
        ])
        /// > < : effort (il pousse).
        static let strain = layer(6, [
            "....E......E....",
            ".....E....E.....",
            "....E......E....",
        ])
    }

    enum Legs {
        static let stand = layer(13, [
            "....KSK..KSK....",
            "....KKK..KKK....",
        ])
        /// Patinage : pieds écartés puis serrés, en alternance.
        static let apart = layer(13, [
            "...KSK....KSK...",
            "...KKK....KKK...",
        ])
        static let together = layer(13, [
            ".....KSKKSK.....",
            ".....KKKKKK.....",
        ])
    }

    enum Arms {
        static let leftDown = layer(6, [
            "KKKK............",
            "KOOK............",
            "KSSK............",
            "KKKK............",
        ])
        static let rightDown = layer(6, [
            "............KKKK",
            "............KOOK",
            "............KSSK",
            "............KKKK",
        ])
        static let leftUp = layer(1, [
            ".KK.............",
            "KOOK............",
            "KOOK............",
            "KSOK............",
            "KSOK............",
            "KKKK............",
        ])
        static let rightUp = layer(1, [
            ".............KK.",
            "............KOOK",
            "............KOOK",
            "............KOSK",
            "............KOSK",
            "............KKKK",
        ])
        /// Bras droit à mi-hauteur, penché vers l'extérieur : l'autre temps du coucou.
        static let rightTilted = layer(3, [
            "..............KK",
            ".............KOK",
            "............KOSK",
            "............KKKK",
        ])
        /// Bras tendus à plat contre les murs (sans ombre propre : paumes en appui), une ligne plus haut ou plus
        /// bas pour le tremblement d'effort.
        static let pushHigh = layer(5, [
            "KKKK........KKKK",
            "KOOK........KOOK",
            "KOOK........KOOK",
            "KKKK........KKKK",
        ])
        static let pushLow = layer(6, [
            "KKKK........KKKK",
            "KOOK........KOOK",
            "KOOK........KOOK",
            "KKKK........KKKK",
        ])
    }

    /// Étincelles de joie, deux temps qui alternent (scintillement).
    enum Sparkles {
        static let big = layer(10, [
            ".Y............Y.",
            "YWY..........YWY",
            ".Y............Y.",
        ])
        static let small = PixelGrid.layered([
            layer(9, ["Y..............Y"]),
            layer(13, ["..W..........W.."]),
        ])
    }

    // MARK: Poses

    static let stand = pose(Body.trunk, Eyes.open, Legs.stand, Arms.leftDown, Arms.rightDown)
    static let handUp = pose(Body.trunk, Eyes.open, Legs.stand, Arms.leftDown, Arms.rightUp)
    static let handTilted = pose(Body.trunk, Eyes.open, Legs.stand, Arms.leftDown, Arms.rightTilted)
    static let cheerBig = pose(Body.trunk, Eyes.happy, Legs.stand, Arms.leftUp, Arms.rightUp, Sparkles.big)
    static let cheerSmall = pose(Body.trunk, Eyes.happy, Legs.stand, Arms.leftUp, Arms.rightUp, Sparkles.small)
    static let pushApart = pose(Body.trunk, Eyes.strain, Legs.apart, Arms.pushHigh)
    static let pushTogether = pose(Body.trunk, Eyes.strain, Legs.together, Arms.pushLow)

    // MARK: Clips

    /// Petit saut (survol) : même image, décalée ; rebond final d'un pixel.
    static let hop = SpriteClip(name: "hop", frames: [
        with(stand, dy: -2),
        with(stand, dy: -3, hold: 2),
        with(stand, dy: -2),
        stand,
        with(stand, dy: -1),
        stand,
    ], fps: 12)

    /// Coucou : le bras droit bat entre levé et penché.
    static let wave = SpriteClip(name: "wave", frames: [
        with(handUp, hold: 2),
        with(handTilted, hold: 2),
        with(handUp, hold: 2),
        with(handTilted, hold: 2),
        with(handUp, hold: 2),
        stand,
    ], fps: 10)

    /// Joie : saut bras en l'air, yeux rieurs, étincelles qui scintillent.
    static let cheer = SpriteClip(name: "cheer", frames: [
        with(cheerBig, dy: -2),
        with(cheerBig, dy: -3, hold: 2),
        with(cheerSmall, dy: -2),
        with(cheerSmall, hold: 2),
        with(cheerBig, hold: 3),
        with(cheerSmall, hold: 3),
        with(cheerBig, hold: 3),
        stand,
    ], fps: 12)

    /// Autorisation requise : main levée, deux petits sauts insistants. Finit main levée (= sa pose de repos).
    static let raiseHand = SpriteClip(name: "raiseHand", frames: [
        with(handUp, dy: -1),
        with(handUp, dy: -2, hold: 2),
        with(handUp, dy: -1),
        with(handUp, hold: 3),
        with(handUp, dy: -1),
        with(handUp, dy: -2, hold: 2),
        with(handUp, dy: -1),
        with(handUp, hold: 3),
    ], fps: 12)

    /// Naissance de la pastille : bras tendus qui tremblent, pieds qui patinent. Rejoué en boucle.
    static let push = SpriteClip(name: "push", frames: [
        pushApart, pushTogether, pushApart, pushTogether,
    ], fps: 10)

    /// Changement d'humeur : il se tasse d'un pixel dans l'ancienne pose, puis rebondit dans la nouvelle —
    /// un seul petit geste qui masque le changement d'accessoire au lieu d'un remplacement sec.
    static func transition(from old: SpriteFrame, to new: SpriteFrame) -> SpriteClip {
        SpriteClip(name: "transition", frames: [with(old, dy: 1), with(new, dy: -1), new], fps: 12)
    }

    /// Image tenue quand aucun clip ne joue.
    static func rest(_ mood: AvatarMood) -> SpriteFrame {
        switch mood {
        case .attention: handUp
        case .pushing: pushApart
        case .working(let activity): activityRest(activity)
        case .idle, .waiting: stand
        }
    }

    static func with(_ frame: SpriteFrame, dx: Int = 0, dy: Int = 0, hold: Int = 1) -> SpriteFrame {
        SpriteFrame(image: frame.image, dx: dx, dy: dy, hold: hold)
    }
}
