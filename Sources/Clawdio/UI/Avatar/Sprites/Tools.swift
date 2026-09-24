/// Activités par outil (voir `AvatarActivity`). Chaque activité a une pose de repos lisible même immobile et un
/// clip joué de temps en temps.
///
/// Parti pris de lisibilité : l'objet de travail (livre, laptop, Terminal) est tenu **face à nous**, les yeux
/// dépassant par-dessus. Vu strictement d'en haut, un objet tenu à plat n'était qu'un rectangle illisible à 16 px.
extension AvatarSprites {
    // MARK: Calques propres aux activités

    enum ToolEyes {
        /// Regard levé (il réfléchit), et le même glissé à gauche.
        static let up = layer(6, [
            ".....E....E.....",
            ".....E....E.....",
        ])
        static let upLeft = layer(6, [
            "....E....E......",
            "....E....E......",
        ])
        /// Yeux qui dépassent au-dessus d'un objet tenu devant le visage : à gauche, au centre, à droite (lecture).
        static func peek(_ shift: Int) -> PixelGrid {
            let row = String(repeating: ".", count: 5 + shift) + "E....E" + String(repeating: ".", count: 5 - shift)
            return layer(5, [row, row])
        }
    }

    enum ToolLimbs {
        /// Pied droit levé (il tape du pied).
        static let legsTap = layer(13, [
            "....KSK..KKK....",
            "....KKK.........",
        ])
        /// Bras remontés pour tenir un objet par les bords.
        static let holdLeft = layer(8, ["KKKK............", "KOOK............", "KSSK............", "KKKK............"])
        static let holdRight = layer(8, ["............KKKK", "............KOOK", "............KSSK", "............KKKK"])
    }

    enum Props {
        /// Livre ouvert tenu devant le visage, pages vers nous (comme l'emoji 📖) : plus large que le corps pour
        /// ne pas se lire comme un vêtement ; creux au dos, lignes de texte, tranche de couverture en bas.
        static let book = layer(7, [
            "..WWWWW..WWWWW..",
            "..WLLLLPPLLLLW..",
            "..WWWWWPPWWWWW..",
            "..WLLLWPPWLLLW..",
            "..NNNNNNNNNNNN..",
        ])
        /// Page tournée qui passe par-dessus le livre, de droite à gauche.
        static let pageRight = layer(5, ["..........WWW...", ".........WWWW..."])
        static let pageUp = layer(4, [".......WW.......", ".......WW.......", ".......WW......."])
        static let pageLeft = layer(5, ["...WWW..........", "...WWWW........."])

        /// Laptop vu de face : l'écran est tourné vers lui, on voit donc le dos du capot (plus large que le corps)
        /// et son logo. Ce qui dit « il tape », c'est la lumière de l'écran sur son visage (`screenGlow`).
        static let laptop = layer(7, [
            ".gggggggggggggg.",
            ".gGGGGGGGGGGGGg.",
            ".gGGGGGGGGGGGGg.",
            ".gGGGGGWWGGGGGg.",
            ".gGGGGGWWGGGGGg.",
            ".gggggggggggggg.",
        ])
        /// Petites mains posées au bas du capot (les bras sont cachés derrière) ; `down` = main abaissée d'un
        /// pixel (elle frappe une touche). Seules elles bougent : pas de bras entiers qui battent.
        static func hands(leftDown: Bool = false, rightDown: Bool = false) -> PixelGrid {
            PixelGrid.layered([
                layer(leftDown ? 10 : 9, ["..HH............", "..OO............"]),
                layer(rightDown ? 10 : 9, ["............HH..", "............OO.."]),
            ])
        }
        /// Reflet bleuté juste au-dessus du capot ; deux variantes qui alternent quand le contenu de l'écran change.
        static let screenGlow = layer(6, ["....llllllll...."])
        static let screenGlowDim = layer(6, ["....lll.llll...."])

        /// Fenêtre Terminal : barre de titre avec les trois pastilles, prompt vert, commande claire, sortie grise.
        static func terminal(_ lines: [String]) -> PixelGrid {
            layer(7, ["..GrYVGGGGGGGG.."] + lines.map { "..\($0).." })
        }

        /// Globe qui tourne : les terres glissent d'une colonne vers la gauche à chaque image (cycle de 4).
        static func globe(turn: Int) -> PixelGrid {
            let bands = ["UVVU", "VUUV", "UUVV"]
            func rotated(_ band: String) -> String {
                let chars = Array(band), n = turn % chars.count
                return String(chars[n...] + chars[..<n])
            }
            return layer(9, [
                "......KKKK......",
                ".....K\(rotated(bands[0]))K.....",
                ".....K\(rotated(bands[1]))K.....",
                ".....K\(rotated(bands[2]))K.....",
                "......KKKK......",
            ])
        }

        /// Deux mini-Clawd (3 × 3) posés au sol de part et d'autre, à distance des bras (sinon on les prend pour
        /// des mains) ; tête éclairée comme le grand.
        static let minis = layer(12, [
            "HHH..........HHH",
            "EOE..........EOE",
            "K.K..........K.K",
        ])
        static let minisHop = layer(11, [
            "HHH..........HHH",
            "EOE..........EOE",
            "K.K..........K.K",
        ])
        /// Étincelles d'invocation, là où les minis vont apparaître.
        static let summonSparks = layer(13, [".Y............Y."])
    }

    // MARK: Écrans

    /// Lignes du Terminal (12 px de large) : `V` = prompt vert, `P` = commande tapée, `W` = curseur,
    /// `g` = sortie gris foncé (distincte de la barre de titre claire).
    enum Shell {
        static let command = "ZVZPPPPPZZZZ"
        static let out1 = "ZggggZZZZZZZ", out2 = "ZggZgggggZZZ"
        static let prompt = "ZVZWZZZZZZZZ", promptOff = "ZVZZZZZZZZZZ"
        static let typing = ["ZVZPWZZZZZZZ", "ZVZPPPWZZZZZ", "ZVZPPPPPWZZZ"]
    }

    // MARK: Poses

    private static let thinking = pose(Body.trunk, ToolEyes.up, Legs.stand, Arms.leftDown, Arms.rightDown)
    private static let thinkingLeft = pose(Body.trunk, ToolEyes.upLeft, Legs.stand, Arms.leftDown, Arms.rightDown)
    private static let thinkingTap = pose(Body.trunk, ToolEyes.up, ToolLimbs.legsTap, Arms.leftDown, Arms.rightDown)

    private static func reading(eyes shift: Int, page: PixelGrid? = nil) -> SpriteFrame {
        // Bras avant le livre : ses bords recouvrent le bout des mains, qui le tiennent par-derrière.
        var layers = [Body.trunk, ToolEyes.peek(shift), Legs.stand, ToolLimbs.holdLeft, ToolLimbs.holdRight, Props.book]
        if let page { layers.append(page) }
        return SpriteFrame(image: PixelGrid.layered(layers).makeImage())
    }

    /// Bras cachés derrière le capot ; changent seulement le regard, le reflet de l'écran et une petite main.
    /// `hand` : 0 = mains posées, 1 = gauche qui frappe, 2 = droite qui frappe.
    private static func coding(eyes: Int = 0, dim: Bool = false, hand: Int = 0) -> SpriteFrame {
        pose(Body.trunk, dim ? Props.screenGlowDim : Props.screenGlow, ToolEyes.peek(eyes), Legs.stand,
             Props.laptop, Props.hands(leftDown: hand == 1, rightDown: hand == 2))
    }

    private static func shell(_ lines: [String]) -> SpriteFrame {
        pose(Body.trunk, ToolEyes.peek(0), Legs.stand, ToolLimbs.holdLeft, ToolLimbs.holdRight, Props.terminal(lines))
    }

    private static let readingRest = reading(eyes: 0)
    private static let codingRest = coding()
    private static let shellRest = shell([Shell.command, Shell.out1, Shell.out2, Shell.prompt])

    private static let globeTurns = (0..<4).map {
        pose(Body.trunk, Eyes.open, Legs.stand, Arms.leftDown, Arms.rightDown, Props.globe(turn: $0))
    }

    private static let summoning = pose(Body.trunk, Eyes.open, Legs.stand, Arms.leftUp, Arms.rightUp, Props.summonSparks)
    private static let summoned = pose(Body.trunk, Eyes.happy, Legs.stand, Arms.leftUp, Arms.rightUp, Props.minis)
    private static let withMinis = pose(Body.trunk, Eyes.open, Legs.stand, Arms.leftDown, Arms.rightDown, Props.minis)
    private static let withMinisHop = pose(Body.trunk, Eyes.open, Legs.stand, Arms.leftDown, Arms.rightDown, Props.minisHop)

    // MARK: Clips

    private static let think = SpriteClip(name: "think", frames: [
        with(thinking, hold: 4), with(thinkingLeft, hold: 4),
        thinking, thinkingTap, thinking, thinkingTap, with(thinking, hold: 2),
    ], fps: 8)

    /// Les yeux balaient deux lignes de gauche à droite, puis une page passe par-dessus le livre.
    private static let read = SpriteClip(name: "read", frames: [
        with(reading(eyes: -1), hold: 3), with(reading(eyes: 0), hold: 3), with(reading(eyes: 1), hold: 3),
        with(reading(eyes: -1), hold: 3), with(reading(eyes: 0), hold: 3), with(reading(eyes: 1), hold: 2),
        reading(eyes: 0, page: Props.pageRight), reading(eyes: 0, page: Props.pageUp), reading(eyes: -1, page: Props.pageLeft),
        with(readingRest, hold: 2),
    ], fps: 8)

    /// Il tape : le regard suit la ligne de gauche à droite (deux lignes), le reflet de l'écran scintille à
    /// chaque cran ; puis il se pose et relit, reflet stable. Calqué sur la lecture.
    /// Les mains frappent à tour de rôle (une image sur deux, pour rester calme).
    private static let write: SpriteClip = {
        var frames: [SpriteFrame] = []
        for (step, eyes) in [-1, 0, 1, -1, 0, 1].enumerated() {
            let dim = step % 2 == 1
            frames.append(coding(eyes: eyes, dim: dim, hand: step % 2 == 0 ? 1 : 2))
            frames.append(coding(eyes: eyes, dim: dim))
        }
        frames.append(with(codingRest, hold: 4))
        return SpriteClip(name: "write", frames: frames, fps: 8)
    }()

    /// Curseur qui clignote, commande tapée, Entrée : la sortie défile ligne par ligne jusqu'au nouveau prompt.
    /// L'état final est la pose de repos : la boucle ne saute pas.
    private static let run = SpriteClip(name: "run", frames: [
        with(shell([Shell.command, Shell.out1, Shell.out2, Shell.promptOff]), hold: 2),
        with(shellRest, hold: 2),
        shell([Shell.command, Shell.out1, Shell.out2, Shell.typing[0]]),
        shell([Shell.command, Shell.out1, Shell.out2, Shell.typing[1]]),
        with(shell([Shell.command, Shell.out1, Shell.out2, Shell.typing[2]]), hold: 2),
        shell([Shell.out1, Shell.out2, Shell.command, Shell.out1]),
        shell([Shell.out2, Shell.command, Shell.out1, Shell.out2]),
        with(shellRest, hold: 2),
    ], fps: 8)

    private static let web = SpriteClip(name: "web", frames: (globeTurns + globeTurns).map { with($0, hold: 2) } + [globeTurns[0]], fps: 8)

    private static let delegate = SpriteClip(name: "delegate", frames: [
        with(summoning, hold: 2), with(summoned, hold: 2), with(withMinis, hold: 2),
        withMinisHop, withMinis, withMinisHop, with(withMinis, hold: 2),
    ], fps: 8)

    /// Pose tenue entre deux clips : l'objet de travail reste visible, sans aucun rendu.
    static func activityRest(_ activity: AvatarActivity) -> SpriteFrame {
        switch activity {
        case .think: thinking
        case .read: readingRest
        case .write: codingRest
        case .run: shellRest
        case .web: globeTurns[0]
        case .delegate: withMinis
        }
    }

    static func activityClip(_ activity: AvatarActivity) -> SpriteClip {
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
