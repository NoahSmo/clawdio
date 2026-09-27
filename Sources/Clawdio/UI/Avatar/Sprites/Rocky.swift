import CoreGraphics

/// Rocky, l'Éridien de « Projet Hail Mary » : carapace de pierre, cinq pattes terminées par des pinces à trois
/// doigts, et pas d'yeux — il « voit » au sonar et parle en accords musicaux.
///
/// Dessiné d'après un pixel art du film : carapace ronde en dôme, brun cuivré tachée de patine verte, entre
/// des pattes épaisses et segmentées qui montent en arche jusqu'au coude puis descendent au sol. Même vue que
/// Clawd (face à la caméra, lumière zénithale). Sans visage, il s'exprime par les notes de musique (`M`) et par ses pattes :
/// une seule bouge à la fois, comme les yeux de Clawd.
///
/// Les accessoires (livre, laptop, Terminal, globe) sont ceux de Clawd : mêmes lettres, recolorés avec la
/// palette de Rocky (voir `pose`).
///
/// Une instance par tenue (`Look`) : mêmes dessins, autre palette, bulle ou non. Classe à propriétés `lazy` :
/// chaque image n'est construite qu'une fois, à la première lecture.
final class RockySprites {
    /// Tenue. Fissures (`T`) et incrustations (`J`) deviennent coutures et écussons sur la combinaison.
    enum Look {
        case natural    // carapace de pierre
        case suit       // combinaison de sortie extravéhiculaire : blanche, écussons orange
        case bubble     // dans sa bulle de verre
        case duo        // avec Grace, son ami humain, à sa gauche : ils se disent les répliques du film

        var colors: [Character: PixelColor] {
            switch self {
            case .natural, .bubble, .duo: [   // roche brun cuivré
                "K": PixelColor(0x2E1A0E),      // contour
                "H": PixelColor(0xE0A469),      // arêtes éclairées (dessus, coudes)
                "h": PixelColor(0xBC7A45),      // pente éclairée
                "O": PixelColor(0x975A2F),      // roche
                "S": PixelColor(0x66391B),      // ombre propre, bas des pattes
                "T": PixelColor(0x44240F),      // fissures, articulations
                "J": PixelColor(0x3E9A48),      // patine verte
                "j": PixelColor(0x8BD870),      // patine verte, reflet
            ]
            case .suit: [
                "K": PixelColor(0x2A2E35),
                "H": PixelColor(0xF4F6F8),      // tissu blanc, éclairé
                "h": PixelColor(0xDDE2E7),
                "O": PixelColor(0xC3CAD2),
                "S": PixelColor(0x7D8894),      // plis, bottes
                "T": PixelColor(0x9AA3AD),      // coutures
                "J": PixelColor(0xF08A24),      // écussons orange
                "j": PixelColor(0xFFBE73),
            ]
            }
        }
    }

    /// Palette de Clawd (accessoires) avec les couleurs de la tenue à la place de l'orange.
    let palette: [Character: PixelColor]
    private let look: Look

    init(_ look: Look) {
        self.look = look
        palette = AvatarPalette.standard.merging(look.colors.merging(Grace.colors) { _, new in new }.merging([
            "M": PixelColor(0x9FE0FF),              // notes de musique (sa voix)
            "m": PixelColor(0x9FE0FF, alpha: 0.5),  // note qui s'efface
            "X": PixelColor(0xA8F0A0, alpha: 0.5),  // arêtes de la bulle, vert d'Érid
        ]) { _, new in new }) { _, rocky in rocky }
    }

    /// Réplique du film, dite seulement en duo (Grace est là pour l'entendre).
    private func line(_ text: String, by side: SpriteClip.Quote.Side = .trailing) -> SpriteClip.Quote? {
        look == .duo ? SpriteClip.Quote(text: text, side: side) : nil
    }

    /// Canevas 24 × 20 (Clawd : 16 × 16), plus large que haut comme lui : de longues pattes très écartées et
    /// du vide entre elles. Les deux lignes du haut restent libres pour les pinces levées et les sauts.
    static let width = 24
    static let height = 20

    /// Dans la bulle : le même dessin posé au centre d'un canevas 36 × 30 aux pixels ⅔ plus petits
    /// (`AvatarRepertoire.pixelScale`) — la bulle occupe la place de Rocky à l'écran, lui tient dedans.
    static let bubbleWidth = 36
    static let bubbleHeight = 30
    private static let bubbleOffset = (x: 6, y: 7)

    /// En duo : Grace à gauche (12 px), Rocky à droite, même hauteur, mêmes pixels.
    static let duoWidth = 36
    static let duoOffset = 12

    var width: Int {
        switch look {
        case .bubble: Self.bubbleWidth
        case .duo: Self.duoWidth
        case .natural, .suit: Self.width
        }
    }
    var height: Int { look == .bubble ? Self.bubbleHeight : Self.height }
    var pixelScale: CGFloat { look == .bubble ? 2.0 / 3 : 1 }

    /// Calques sans couleur propre : `pose` applique la palette de la tenue.
    static func layer(_ row: Int, _ lines: [String]) -> PixelGrid {
        PixelGrid(at: row, lines, width: width, height: height, palette: AvatarPalette.standard)
    }

    static func bubbleLayer(_ row: Int, _ lines: [String]) -> PixelGrid {
        PixelGrid(at: row, lines, width: bubbleWidth, height: bubbleHeight, palette: AvatarPalette.standard)
    }

    /// Calque du duo (36 de large) : lignes écrites depuis le bord gauche, complétées de transparent.
    static func duoLayer(_ row: Int, _ lines: [String]) -> PixelGrid {
        let padded = lines.map { $0 + String(repeating: ".", count: duoWidth - $0.count) }
        return PixelGrid(at: row, padded, width: duoWidth, height: height, palette: AvatarPalette.standard)
    }

    func pose(_ layers: PixelGrid...) -> SpriteFrame {
        pose(layers)
    }

    /// Recolore le tout avec la palette de la tenue : les calques d'accessoires de Clawd portent la palette
    /// standard, qui écraserait sinon la pierre (`PixelGrid.layered` garde la palette du dernier calque).
    /// En duo, `grace` remplace sa pose debout et `duo` ajoute des calques à l'échelle du duo (le bras tendu
    /// vers elle) ; les autres tenues les ignorent.
    func pose(_ layers: [PixelGrid], grace: PixelGrid = Grace.stand, duo: [PixelGrid] = []) -> SpriteFrame {
        SpriteFrame(image: grid(PixelGrid.layered(layers), grace: grace, duo: duo).makeImage())
    }

    /// Une image prête à afficher : recolorée, recentrée dans la bulle (`.bubble`) ou posée à droite de Grace (`.duo`).
    private func grid(_ picture: PixelGrid, grace: PixelGrid = Grace.stand, duo: [PixelGrid] = []) -> PixelGrid {
        let colored = PixelGrid(picture.rows, palette: palette)
        switch look {
        case .natural, .suit:
            return colored
        case .bubble:
            return colored.placed(width: Self.bubbleWidth, height: Self.bubbleHeight, dx: Self.bubbleOffset.x, dy: Self.bubbleOffset.y)
        case .duo:
            let rocky = colored.placed(width: Self.duoWidth, height: Self.height, dx: Self.duoOffset, dy: 0)
            let layers = [rocky, grace] + duo
            return PixelGrid(PixelGrid.layered(layers).rows, palette: palette)
        }
    }

    private func with(_ frame: SpriteFrame, dx: Int = 0, dy: Int = 0, hold: Int = 1) -> SpriteFrame {
        AvatarSprites.with(frame, dx: dx, dy: dy, hold: hold)
    }

    // MARK: Calques

    /// Large et plate : tout l'écart des pattes.
    private static let shadowGrid = layer(18, [
        ".ssssssssssssssssssssss.",
        "....ssssssssssssssss....",
    ])
    lazy var shadow = grid(Self.shadowGrid, grace: Grace.shadow).makeImage()

    /// La bulle, dessinée par-dessus sans suivre les sauts : quand il saute, il saute dans sa bulle.
    lazy var overlay: CGImage? = look == .bubble ? PixelGrid(Bubble.edges.rows, palette: palette).makeImage() : nil

    enum Body {
        /// Carapace : un rocher rond en dôme, brun cuivré, taches de patine verte (vert-de-gris) jamais
        /// alignées — deux taches côte à côte se liraient comme des yeux.
        static let carapace = layer(3, [
            "..........KKKK..........",
            "........KKHHHhKK........",
            ".......KHHJJHhhhK.......",
            "......KhHJjJJhhOOK......",
            "......KhhJJJhOOOSK......",
            ".....KhhhhhOOOJJOSK.....",
            ".....KhOOhOOOJjJSSK.....",
            ".....KOOTOOOOOJJSSK.....",
            "......KJJOTOOOSSSK......",
            ".......KKOSSSTSKK.......",
            ".........KKKKKK.........",
        ])

        /// Tassé d'une ligne (sommeil).
        static let low = layer(4, [
            "..........KKKK..........",
            "........KKHHHhKK........",
            ".......KHHJJHhhhK.......",
            "......KhHJjJJhhOOK......",
            "......KhhJJJhOOOSK......",
            ".....KhhhhhOOOJJOSK.....",
            ".....KhOOhOOOJjJSSK.....",
            ".....KOOTOOOOOJJSSK.....",
            "......KJJOTOOOSSSK......",
            ".......KKOSSSTSKK.......",
            ".........KKKKKK.........",
        ])
    }

    enum Legs {
        /// Deux pattes avant, épaisses, sous la carapace.
        static let inner = layer(13, [
            ".........KOS..SOK.......",
            "........KhOS..hOSK......",
            ".......KhOS....hOSK.....",
            ".......KOOS....OOSK.....",
            "......KS.SK....KS.SK....",
        ])

        static let innerLow = layer(14, [
            "........KhOS..hOSK......",
            ".......KhOS....hOSK.....",
            ".......KOOS....OOSK.....",
            "......KS.SK....KS.SK....",
        ])

        /// Pied avant droit levé d'un pixel (il tapote).
        static let innerTap = layer(13, [
            ".........KOS..SOK.......",
            "........KhOS..hOSK......",
            ".......KhOS....hOSK.....",
            ".......KOOS....KS.SK....",
            "......KS.SK.............",
        ])

        /// Poussée : pieds écartés puis serrés, en alternance.
        static let innerApart = layer(13, [
            ".........KOS..SOK.......",
            "........KhOS..hOSK......",
            "......KhOS......hOSK....",
            ".....KhOS........hOSK...",
            "....KS.SK........KS.SK..",
        ])

        static let innerTogether = layer(13, [
            ".........KOS..SOK.......",
            ".........KOS..SOK.......",
            ".........KOS..SOK.......",
            ".........KOS..SOK.......",
            "........KS.SKKS.SK......",
        ])

        /// Pattes extérieures, épaisses et segmentées : le haut monte de la carapace jusqu'au coude, en arche,
        /// puis l'avant-bras descend au sol. Articulation sombre (`T`), incrustations vertes (`J`), pince à trois doigts.
        static let leftDown = layer(1, [
            "...KKK..................",
            "..KHHhK.................",
            "..KhHhOK................",
            ".KhJhOOSK...............",
            ".KhJSKOOSK..............",
            ".KhOS.KSK...............",
            ".KhOS...................",
            "KhOOS...................",
            "KTTTK...................",
            "KhOS....................",
            "KhJS....................",
            "KOJS....................",
            "KOOS....................",
            "KOSS....................",
            "KhSK....................",
            "KSSK....................",
            "S.SS....................",
        ])

        static let rightDown = layer(1, [
            "..................KKK...",
            ".................KhHHK..",
            "................KOhHhK..",
            "...............KSOOhJhK.",
            "..............KSOOKSJhK.",
            "...............KSK.SOhK.",
            "...................SOhK.",
            "...................SOOhK",
            "...................KTTTK",
            "....................SOhK",
            "....................SJhK",
            "....................SJOK",
            "....................SOOK",
            "....................SSOK",
            "....................KShK",
            "....................KSSK",
            "....................SS.S",
        ])

        static let leftDownLow = layer(2, [
            "...KKK..................",
            "..KHHhK.................",
            "..KhHhOK................",
            ".KhJhOOSK...............",
            ".KhJSKOOSK..............",
            ".KhOS.KSK...............",
            ".KhOS...................",
            "KhOOS...................",
            "KTTTK...................",
            "KhOS....................",
            "KhJS....................",
            "KOOS....................",
            "KOSS....................",
            "KhSK....................",
            "KSSK....................",
            "S.SS....................",
        ])

        static let rightDownLow = layer(2, [
            "..................KKK...",
            ".................KhHHK..",
            "................KOhHhK..",
            "...............KSOOhJhK.",
            "..............KSOOKSJhK.",
            "...............KSK.SOhK.",
            "...................SOhK.",
            "...................SOOhK",
            "...................KTTTK",
            "....................SOhK",
            "....................SJhK",
            "....................SOOK",
            "....................SSOK",
            "....................KShK",
            "....................KSSK",
            "....................SS.S",
        ])

        /// Patte levée comme un bras, pince ouverte ; `Closed` = pince refermée (l'autre temps du coucou :
        /// seule la main bouge).
        static let leftUp = layer(0, [
            "KS.SK...................",
            "KhOSK...................",
            "KhJS....................",
            "KhJS....................",
            "KTTTK...................",
            "KhOOK...................",
            "KhOOhKK.................",
            ".KhOOOSK................",
            "..KKSSK.................",
        ])

        static let rightUp = layer(0, [
            "...................KS.SK",
            "...................KSOhK",
            "....................SJhK",
            "....................SJhK",
            "...................KTTTK",
            "...................KOOhK",
            ".................KKhOOhK",
            "................KSOOOhK.",
            ".................KSSKK..",
        ])

        static let rightUpClosed = layer(0, [
            "....................KKK.",
            "...................KSOhK",
            "....................SJhK",
            "....................SJhK",
            "...................KTTTK",
            "...................KOOhK",
            ".................KKhOOhK",
            "................KSOOOhK.",
            ".................KSSKK..",
        ])

        /// Pattes tendues à plat contre les murs, une ligne plus haut ou plus bas (tremblement d'effort).
        static let pushHigh = layer(6, [
            "K......................K",
            "KKKKKKK..........KKKKKKK",
            "KhhThhhK........KhhhThhK",
            "KOOTOOSK........KSOOTOOK",
            "KSSSSSK..........KSSSSSK",
            "K......................K",
        ])

        static let pushLow = layer(7, [
            "K......................K",
            "KKKKKKK..........KKKKKKK",
            "KhhThhhK........KhhhThhK",
            "KOOTOOSK........KSOOTOOK",
            "KSSSSSK..........KSSSSSK",
            "K......................K",
        ])

        /// Avant-bras qui se replient vers l'intérieur : pince posée sur le bord d'un objet tenu devant lui.
        static let holdLeft = layer(1, [
            "...KKK..................",
            "..KHHhK.................",
            "..KhHhOK................",
            ".KhJhOOSK...............",
            ".KhJSKOOSK..............",
            ".KhOS.KSK...............",
            ".KhOS...................",
            "KhOOS...................",
            "KhOS....................",
            ".KOSSK..................",
            "..KSSK..................",
        ])

        static let holdRight = layer(1, [
            "..................KKK...",
            ".................KhHHK..",
            "................KOhHhK..",
            "...............KSOOhJhK.",
            "..............KSOOKSJhK.",
            "...............KSK.SOhK.",
            "...................SOhK.",
            "...................SOOhK",
            "....................SOhK",
            "..................KSSOK.",
            "..................KSSK..",
        ])
    }

    /// Sa bulle : le dôme de verre géodésique où il vit à bord de l'Hail Mary (atmosphère d'Érid). Rien que les
    /// arêtes et des reflets, par-dessus lui : un fond teinté se lisait comme une boîte grise.
    enum Bubble {
        /// Arêtes du dôme géodésique et reflets, par-dessus lui (comme sur la photo, elles coupent sa silhouette).
        static let edges = bubbleLayer(0, [
            ".................XXX................",
            ".............XXXXXX.XXX.............",
            ".........XXXX...X..X...XXXX.........",
            ".......XXXX.....X...X....XXXX.......",
            "......X.XWWXXXXXXXXXXXXXX..X.X......",
            ".....X...W..XX........XX..X...X.....",
            "....X....XXX............XXXW...X....",
            "....X..XX..................XX..X....",
            "...X.XX......................XX.X...",
            "..XXX..........................XXX..",
            ".XX..............................XX.",
            ".X................................X.",
            ".X................................X.",
            ".X................................X.",
            ".X................................X.",
            ".X................................X.",
            ".X................................X.",
            ".X................................X.",
            ".X................................X.",
            "..X..............................X..",
            "...X............................X...",
            "....X..........................X....",
            "....X..........................X....",
            ".....X........................X.....",
            "......X......................X......",
            ".......XX..................XX.......",
            ".........XXXX..........XXXX.........",
            ".............XXXX...XXX.............",
            ".................XXX................",
        ])
    }

    /// Ryland Grace, l'astronaute humain, debout à gauche de Rocky (duo seulement). Plus grand que lui, cheveux
    /// blond sable, t-shirt bleu-gris de bord. Face à nous comme Clawd : lui a des yeux, c'est eux qui bougent.
    enum Grace {
        static let colors: [Character: PixelColor] = [
            "a": PixelColor(0xD2B176),  // cheveux
            "A": PixelColor(0x9A7A48),  // mèche, dans l'ombre
            "f": PixelColor(0xF0C6A0),  // peau
            "F": PixelColor(0xC7966F),  // peau dans l'ombre, barbe de trois jours
            "c": PixelColor(0x7390AD),  // t-shirt
            "C": PixelColor(0x4F6883),  // t-shirt dans l'ombre
            "p": PixelColor(0x3E4250),  // pantalon
            "k": PixelColor(0x24252B),  // chaussures
        ]

        private static let hair = ["...aaaa...", "..aaaaaa..", "..aAAAAa.."]
        private static let jaw = ["..ffffff..", "...fFFf..."]
        private static let legs = ["..pppppp..", "..pp..pp..", "..pp..pp..", ".kkk..kkk."]
        private static let armsDown = ["..cccccc..", ".cccccccC.", ".cCcccccC.", ".cCcccccC.", ".f.cccC.f."]

        /// Debout, bras le long du corps ; `eyes` = la ligne des yeux (ouverts, fermés, tournés vers Rocky).
        private static func standing(eyes: String, arms: [String] = armsDown) -> PixelGrid {
            duoLayer(3, hair + [eyes] + jaw + arms + legs)
        }

        static let eyesOpen = "..fEffEf.."
        static let stand = standing(eyes: eyesOpen)
        static let blink = standing(eyes: "..fFffFf..")
        /// Il regarde Rocky.
        static let lookRocky = standing(eyes: "..ffEffE..")

        /// Poing tendu vers Rocky, à hauteur d'épaule (check : « Fist my bump »).
        static let fistOut = standing(eyes: "..ffEffE..", arms: [
            "..cccccc....",
            ".ccccccccfF.",
            ".cCccccC.FF.",
            ".cCccccC....",
            ".f.cccC.....",
        ])

        /// Les deux bras en l'air, bouche ouverte (« Amaze ! »).
        static let cheer = duoLayer(3, [
            "...aaaa...",
            "f.aaaaaa.f",
            "c.aAAAAa.c",
            "c.fEffEf.c",
            "c.ffffff.c",
            "cc.fKKf.cc",
            ".cccccccc.",
            "..cccccC..",
            "..cCcccC..",
            "..cCcccC..",
            "...cccC...",
        ] + legs)

        /// Assis par terre en tailleur, pour dormir (les Éridiens veillent sur ceux qui dorment).
        private static func sitting(eyes: String) -> PixelGrid {
            duoLayer(8, hair + [eyes] + jaw + [
                ".cccccccc.",
                ".fCccccCf.",
                ".pppppppp.",
                "kkpp..ppkk",
            ])
        }
        static let sittingAwake = sitting(eyes: eyesOpen)
        static let asleep = sitting(eyes: "..fFffFf..")

        /// « z » au-dessus de sa tête (assis).
        static let snoreDot = duoLayer(6, ["......W"])
        static let snoreLow = duoLayer(4, ["......WW", ".......W", ".......WW"])
        static let snoreHigh = duoLayer(3, ["......ww", ".......w", ".......ww"])

        static let shadow = duoLayer(18, [".ssssssss."])
    }

    /// Calques à l'échelle du duo : la patte gauche de Rocky tendue vers Grace (elle remplace `Legs.leftDown`).
    enum Duo {
        /// Pince en route, encore à un pixel du poing de Grace.
        static let reach = duoLayer(4, [
            "...............KKK",
            "..............KHhhK",
            ".............KhOOOSK",
            "............KhJSKOSK",
            "...........KhJSK",
            "...........KTTTK",
            "............KOSK",
            "............KSK",
        ])
        /// Pince contre le poing.
        static let bump = duoLayer(4, [
            "...............KKK",
            "..............KHhhK",
            ".............KhOOOSK",
            "............KhJSKOSK",
            "...........KhJSK",
            "...........KTTK",
            "...........KhSK",
            "...........KSK",
        ])
        /// Étincelles du check, au point de contact.
        static let spark = duoLayer(7, [
            "..........Y",
            ".........Y",
            "",
            "",
            "",
            "..........Y.Y",
        ])
    }

    /// Sa voix : des notes (♪) au-dessus de la carapace, entre les coudes ; à gauche aussi pour un accord.
    enum Notes {
        static let low = layer(1, ["...............MM.......", "...............M........", "..............MM........"])
        static let high = layer(0, ["...............mm.......", "...............m........", "..............mm........"])
        static let lowLeft = layer(1, ["........MM..............", "........M...............", ".......MM..............."])
        static let highLeft = layer(0, ["........mm..............", "........m...............", ".......mm..............."])
        /// Grande joie (« Amaze ! ») : une note de chaque côté, qui scintille.
        static let cheerBig = PixelGrid.layered([lowLeft, low])
        static let cheerSmall = PixelGrid.layered([highLeft, high])
    }

    /// « z » du sommeil, entre les coudes.
    enum Snore {
        static let dot = layer(3, ["................W......."])
        static let low = layer(1, ["...............WW.......", "................W.......", "................WW......"])
        static let high = layer(0, ["...............ww.......", "................w.......", "................ww......"])
    }

    enum Props {
        /// Point de sonar qui balaie les lignes du livre : il lit à l'écoute, pas des yeux.
        static func sonar(_ step: Int) -> PixelGrid {
            let spots = [(9, 7), (9, 9), (9, 14), (9, 16), (11, 7), (11, 9), (11, 14), (11, 16)]
            let (row, x) = spots[step % spots.count]
            return layer(row, [String(repeating: ".", count: x) + "M" + String(repeating: ".", count: width - 1 - x)])
        }

        /// Deux mini-Rocky au sol, aux coins : carapace plate et pattes écartées. Les pattes extérieures du grand
        /// sont levées pour leur laisser la place.
        static let minis = layer(15, [
            ".KK..................KK.",
            "KhJK................KJhK",
            "S..S................S..S",
        ])
        static let minisHop = layer(14, [
            ".KK..................KK.",
            "KhJK................KJhK",
            "S..S................S..S",
        ])
    }

    /// Accessoires de Clawd (canevas 16) replacés devant la carapace de Rocky : centrés (+4 px), un peu plus bas.
    enum Borrowed {
        private static func place(_ grid: PixelGrid, dy: Int) -> PixelGrid {
            grid.placed(width: width, height: height, dx: 4, dy: dy)
        }
        static let book = place(AvatarSprites.Props.book, dy: 1)
        static let pageRight = place(AvatarSprites.Props.pageRight, dy: 1)
        static let pageUp = place(AvatarSprites.Props.pageUp, dy: 1)
        static let pageLeft = place(AvatarSprites.Props.pageLeft, dy: 1)
        static let laptop = place(AvatarSprites.Props.laptop, dy: 2)
        static let screenGlow = place(AvatarSprites.Props.screenGlow, dy: 2)
        static let screenGlowDim = place(AvatarSprites.Props.screenGlowDim, dy: 2)
        static func hands(leftDown: Bool, rightDown: Bool) -> PixelGrid {
            place(AvatarSprites.Props.hands(leftDown: leftDown, rightDown: rightDown), dy: 2)
        }
        static func terminal(_ lines: [String]) -> PixelGrid { place(AvatarSprites.Props.terminal(lines), dy: 1) }
        static func globe(turn: Int) -> PixelGrid { place(AvatarSprites.Props.globe(turn: turn), dy: 4) }
        static let summonSparks = place(AvatarSprites.Props.summonSparks, dy: 4)
    }

    // MARK: Poses

    lazy var stand = pose(Body.carapace, Legs.inner, Legs.leftDown, Legs.rightDown)
    private lazy var tapping = pose(Body.carapace, Legs.innerTap, Legs.leftDown, Legs.rightDown)
    private lazy var low = pose(Body.low, Legs.innerLow, Legs.leftDownLow, Legs.rightDownLow)
    private lazy var handUp = pose(Body.carapace, Legs.inner, Legs.leftDown, Legs.rightUp)
    private lazy var handClosed = pose(Body.carapace, Legs.inner, Legs.leftDown, Legs.rightUpClosed)
    private lazy var bothUp = pose(Body.carapace, Legs.inner, Legs.leftUp, Legs.rightUp)
    private lazy var cheerBig = pose([Body.carapace, Legs.inner, Legs.leftUp, Legs.rightUp, Notes.cheerBig], grace: Grace.cheer)
    private lazy var cheerSmall = pose([Body.carapace, Legs.inner, Legs.leftUp, Legs.rightUp, Notes.cheerSmall], grace: Grace.cheer)
    private lazy var pushApart = pose(Body.carapace, Legs.innerApart, Legs.pushHigh)
    private lazy var pushTogether = pose(Body.carapace, Legs.innerTogether, Legs.pushLow)

    private func standing(_ extras: PixelGrid...) -> SpriteFrame {
        pose([Body.carapace, Legs.inner, Legs.leftDown, Legs.rightDown] + extras)
    }

    private func lowered(_ extras: PixelGrid...) -> SpriteFrame {
        pose([Body.low, Legs.innerLow, Legs.leftDownLow, Legs.rightDownLow] + extras)
    }

    // Duo : Grace bouge, Rocky garde sa pose debout.
    private func withGrace(_ grace: PixelGrid, _ duo: PixelGrid...) -> SpriteFrame {
        pose([Body.carapace, Legs.inner, Legs.leftDown, Legs.rightDown], grace: grace, duo: duo)
    }
    private func bumping(_ arm: PixelGrid, _ extras: PixelGrid...) -> SpriteFrame {
        pose([Body.carapace, Legs.inner, Legs.rightDown], grace: Grace.fistOut, duo: [arm] + extras)
    }
    private lazy var graceBlinking = withGrace(Grace.blink)
    private lazy var graceLooking = withGrace(Grace.lookRocky)
    private lazy var graceSitting = withGrace(Grace.sittingAwake)
    private lazy var graceAsleep = withGrace(Grace.asleep)

    /// En duo, c'est Grace qui s'endort ; Rocky reste debout et veille.
    var sleeping: SpriteFrame { look == .duo ? graceAsleep : low }

    // MARK: Clips généraux (mêmes rôles que ceux de Clawd)

    lazy var hop = SpriteClip(name: "rocky.hop", frames: [
        with(stand, dy: -2), with(stand, dy: -3, hold: 2), with(stand, dy: -2), stand, with(stand, dy: -1), stand,
    ], fps: 12)

    /// Coucou : patte levée, la pince s'ouvre et se referme.
    lazy var wave = SpriteClip(name: "rocky.wave", frames: [
        with(handUp, hold: 2), with(handClosed, hold: 2), with(handUp, hold: 2), with(handClosed, hold: 2),
        with(handUp, hold: 2), stand,
    ], fps: 10)

    /// « Amaze, amaze, amaze ! » : saut, pattes en l'air, un accord de chaque côté.
    lazy var cheer = SpriteClip(name: "rocky.cheer", frames: [
        with(cheerBig, dy: -2), with(cheerBig, dy: -3, hold: 2), with(cheerSmall, dy: -2), with(cheerSmall, hold: 2),
        with(cheerBig, hold: 3), with(cheerSmall, hold: 3), with(cheerBig, hold: 3), stand,
    ], fps: 12, quote: line("Amaze! Amaze! Amaze!"))

    /// Il a besoin de ton accord : en éridien, une question finit par « question ».
    lazy var raiseHand = SpriteClip(name: "rocky.raiseHand", frames: [
        with(handUp, dy: -1), with(handUp, dy: -2, hold: 2), with(handUp, dy: -1), with(handUp, hold: 3),
        with(handUp, dy: -1), with(handUp, dy: -2, hold: 2), with(handUp, dy: -1), with(handUp, hold: 3),
    ], fps: 12, quote: line("Question?"))

    lazy var push = SpriteClip(name: "rocky.push", frames: [pushApart, pushTogether, pushApart, pushTogether], fps: 10)

    // MARK: Repos

    /// Tapote du bout d'une patte, deux fois.
    lazy var tap = SpriteClip(name: "rocky.tap", frames: [tapping, stand, tapping, with(stand, hold: 2)], fps: 6)

    /// Il fredonne : une note monte et s'efface.
    lazy var hum = SpriteClip(name: "rocky.hum", frames: [
        with(standing(Notes.low), hold: 3), with(standing(Notes.high), hold: 3), with(stand, hold: 2),
    ], fps: 6)

    /// Un accord : deux notes, à droite puis à gauche.
    lazy var chord = SpriteClip(name: "rocky.chord", frames: [
        with(standing(Notes.low), hold: 2), with(standing(Notes.high, Notes.lowLeft), hold: 3),
        with(standing(Notes.highLeft), hold: 2), with(stand, hold: 2),
    ], fps: 6, quote: line("Happy happy happy!"))

    /// Un seul grand geste, lent : les deux pattes extérieures en l'air, puis relâchées.
    lazy var stretch = SpriteClip(name: "rocky.stretch", frames: [with(bothUp, hold: 6), with(stand, hold: 2)], fps: 6)

    /// Somnolent : la carapace s'affaisse un instant, il se redresse.
    lazy var sag = SpriteClip(name: "rocky.sag", frames: [with(low, hold: 5), with(stand, hold: 2)], fps: 6)

    /// Il s'assoupit : s'affaisse, se redresse une fois, puis s'endort tassé. En duo, Grace cligne, s'assoit
    /// et ferme les yeux ; Rocky promet de veiller.
    lazy var fallAsleep = look == .duo
        ? SpriteClip(name: "duo.fallAsleep", frames: [
            with(graceBlinking, hold: 2), with(stand, hold: 3), with(graceSitting, hold: 5), with(graceAsleep, hold: 8),
        ], fps: 6, quote: line("You sleep. I watch."))
        : SpriteClip(name: "rocky.fallAsleep", frames: [
            with(low, hold: 3), with(stand, hold: 2), with(low, hold: 5),
        ], fps: 6)

    lazy var snore = look == .duo
        ? SpriteClip(name: "duo.snore", frames: [
            withGrace(Grace.asleep, Grace.snoreDot), with(withGrace(Grace.asleep, Grace.snoreLow), hold: 2),
            with(withGrace(Grace.asleep, Grace.snoreHigh), hold: 2), with(graceAsleep, hold: 2),
        ], fps: 3)
        : SpriteClip(name: "rocky.snore", frames: [
            lowered(Snore.dot), with(lowered(Snore.low), hold: 2), with(lowered(Snore.high), hold: 2), with(low, hold: 2),
        ], fps: 3)

    lazy var wake = look == .duo
        ? SpriteClip(name: "duo.wake", frames: [with(graceAsleep, hold: 2), with(graceSitting, hold: 3), with(stand, hold: 2)], fps: 8)
        : SpriteClip(name: "rocky.wake", frames: [with(low, hold: 2), with(stand, dy: -1), with(stand, hold: 2)], fps: 8)

    // MARK: Duo

    /// Le check : Grace tend le poing, la pince de Rocky vient le toucher, étincelle.
    private lazy var fistBump = SpriteClip(name: "duo.fistBump", frames: [
        with(graceLooking, hold: 3), with(bumping(Duo.reach), hold: 3), with(bumping(Duo.bump), hold: 2),
        with(bumping(Duo.bump, Duo.spark), hold: 4), with(bumping(Duo.bump), hold: 2), with(stand, hold: 2),
    ], fps: 8, quote: line("Fist my bump."))

    /// Grace ne bouge que les yeux, comme Clawd : un clignement, ou un regard vers Rocky.
    private lazy var graceBlink = SpriteClip(name: "duo.graceBlink", frames: [with(graceBlinking, hold: 2), stand], fps: 12)
    private lazy var graceLook = SpriteClip(name: "duo.graceLook", frames: [with(graceLooking, hold: 12), graceBlinking, stand], fps: 6)
    /// Somnolente : elle ferme les yeux un long moment.
    private lazy var graceNod = SpriteClip(name: "duo.graceNod", frames: [with(graceBlinking, hold: 8), with(stand, hold: 2)], fps: 6)

    /// Gestes de repos tirés au sort (poids normal, poids une fois somnolent : voir `AvatarRepertoire.idle`).
    /// Rocky ne cligne pas des yeux (il n'en a pas) : il tapote et fredonne surtout ; somnolent, il se tait et sa
    /// carapace s'affaisse de plus en plus souvent. En duo, c'est Grace qui cligne et qui s'endort.
    lazy var idle: [(clip: SpriteClip, weight: Double, drowsy: Double)] = look == .duo
        ? [
            (graceBlink, 25, 20),
            (graceLook, 12, 8),
            (tap, 20, 15),
            (hum, 12, 5),
            (chord, 8, 2),
            (fistBump, 10, 2),
            (graceNod, 2, 20),
        ]
        : [
            (tap, 32, 25),
            (hum, 25, 8),
            (chord, 12, 3),
            (stretch, 7, 5),
            (sag, 3, 20),
        ]

    // MARK: Activités

    private typealias Shell = AvatarSprites.Shell

    private lazy var thinking = standing(Notes.low)

    private func reading(sonar step: Int? = nil, page: PixelGrid? = nil) -> SpriteFrame {
        var layers = [Body.carapace, Legs.inner, Legs.holdLeft, Legs.holdRight, Borrowed.book]
        if let step { layers.append(Props.sonar(step)) }
        if let page { layers.append(page) }
        return pose(layers)
    }

    private func coding(dim: Bool = false, hand: Int = 0) -> SpriteFrame {
        pose(Body.carapace, dim ? Borrowed.screenGlowDim : Borrowed.screenGlow, Legs.inner,
             Legs.leftDown, Legs.rightDown, Borrowed.laptop,
             Borrowed.hands(leftDown: hand == 1, rightDown: hand == 2))
    }

    private func shell(_ lines: [String]) -> SpriteFrame {
        pose(Body.carapace, Legs.inner, Legs.holdLeft, Legs.holdRight, Borrowed.terminal(lines))
    }

    private lazy var readingRest = reading()
    private lazy var codingRest = coding()
    private lazy var shellRest = shell([Shell.command, Shell.out1, Shell.out2, Shell.prompt])
    private lazy var globeTurns = (0..<4).map { standing(Borrowed.globe(turn: $0)) }
    private lazy var summoning = pose(Body.carapace, Legs.inner, Legs.leftUp, Legs.rightUp, Borrowed.summonSparks)
    private lazy var summoned = pose(Body.carapace, Legs.inner, Legs.leftUp, Legs.rightUp, Props.minis, Notes.low)
    private lazy var withMinis = pose(Body.carapace, Legs.inner, Legs.leftUp, Legs.rightUp, Props.minis)
    private lazy var withMinisHop = pose(Body.carapace, Legs.inner, Legs.leftUp, Legs.rightUp, Props.minisHop)

    /// Il réfléchit à voix haute : il tapote, fredonne, tapote.
    private lazy var think = SpriteClip(name: "rocky.think", frames: [
        with(thinking, hold: 3), with(standing(Notes.high), hold: 3), tapping, stand, tapping, with(thinking, hold: 2),
    ], fps: 8)

    /// Le point de sonar parcourt deux lignes, puis une page passe par-dessus le livre.
    private lazy var read = SpriteClip(name: "rocky.read", frames:
        (0..<8).map { with(reading(sonar: $0), hold: 2) } + [
            reading(page: Borrowed.pageRight), reading(page: Borrowed.pageUp),
            reading(page: Borrowed.pageLeft), with(readingRest, hold: 2),
        ], fps: 8)

    private lazy var write: SpriteClip = {
        var frames: [SpriteFrame] = []
        for step in 0..<6 {
            frames.append(self.coding(dim: step % 2 == 1, hand: step % 2 == 0 ? 1 : 2))
            frames.append(self.coding(dim: step % 2 == 1))
        }
        frames.append(self.with(self.codingRest, hold: 4))
        return SpriteClip(name: "rocky.write", frames: frames, fps: 8)
    }()

    private lazy var run = SpriteClip(name: "rocky.run", frames: [
        with(shell([Shell.command, Shell.out1, Shell.out2, Shell.promptOff]), hold: 2),
        with(shellRest, hold: 2),
        shell([Shell.command, Shell.out1, Shell.out2, Shell.typing[0]]),
        shell([Shell.command, Shell.out1, Shell.out2, Shell.typing[1]]),
        with(shell([Shell.command, Shell.out1, Shell.out2, Shell.typing[2]]), hold: 2),
        shell([Shell.out1, Shell.out2, Shell.command, Shell.out1]),
        shell([Shell.out2, Shell.command, Shell.out1, Shell.out2]),
        with(shellRest, hold: 2),
    ], fps: 8)

    private lazy var web = SpriteClip(name: "rocky.web", frames: (globeTurns + globeTurns).map { with($0, hold: 2) } + [globeTurns[0]], fps: 8)

    private lazy var delegate = SpriteClip(name: "rocky.delegate", frames: [
        with(summoning, hold: 2), with(summoned, hold: 2), with(withMinis, hold: 2),
        withMinisHop, withMinis, withMinisHop, with(withMinis, hold: 2),
    ], fps: 8)

    func rest(_ mood: AvatarMood) -> SpriteFrame {
        switch mood {
        case .attention: handUp
        case .pushing: pushApart
        case .working(let activity):
            switch activity {
            case .think: thinking
            case .read: readingRest
            case .write: codingRest
            case .run: shellRest
            case .web: globeTurns[0]
            case .delegate: withMinis
            }
        case .idle, .waiting: stand
        }
    }

    func activityClip(_ activity: AvatarActivity) -> SpriteClip {
        switch activity {
        case .think: think
        case .read: read
        case .write: write
        case .run: run
        case .web: web
        case .delegate: delegate
        }
    }
}
