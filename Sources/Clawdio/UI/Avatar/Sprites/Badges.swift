/// Badges de besoin, en pixel art comme l'avatar (même palette, même échelle) : étincelle = il travaille ·
/// bulle blanche « … » = il a répondu · bulle orange « ! » = il a besoin de toi. Canevas 12 × 10.
enum BadgeSprites {
    static let width = 12
    static let height = 10

    private static func image(_ rows: [String], top: Int = 0) -> SpriteFrame {
        SpriteFrame(image: PixelGrid(at: top, rows, width: width, height: height, palette: AvatarPalette.standard).makeImage())
    }

    static let reply = image([
        ".WWWWWWWWWW.",
        "WWWWWWWWWWWW",
        "WWWWWWWWWWWW",
        "WWDDWDDWDDWW",
        "WWDDWDDWDDWW",
        "WWWWWWWWWWWW",
        "WWWWWWWWWWWW",
        ".WWWWWWWWWW.",
        "..WW........",
        "..W.........",
    ])

    static let approval = image([
        ".BBBBBBBBBB.",
        "BBBBBWWBBBBB",
        "BBBBBWWBBBBB",
        "BBBBBWWBBBBB",
        "BBBBBWWBBBBB",
        "BBBBBBBBBBBB",
        "BBBBBWWBBBBB",
        ".BBBBBBBBBB.",
        "..BB........",
        "..B.........",
    ])

    static let sparkleBig = image([
        "....Y.......",
        "....Y.......",
        "....Y.......",
        "...YWY......",
        "YYYWWWYYY...",
        "...YWY......",
        "....Y.......",
        "....Y.......",
        "....Y.......",
    ], top: 1)

    static let sparkleSmall = image([
        "....Y.......",
        "....Y.......",
        "..YYWYY.....",
        "....Y.......",
        "....Y.......",
    ], top: 3)

    /// Bulles : petit rebond d'un pixel.
    static let replyBounce = bounce(reply, name: "replyBounce")
    static let approvalBounce = bounce(approval, name: "approvalBounce")

    /// Étincelle : se contracte puis rejaillit.
    static let twinkle = SpriteClip(name: "twinkle", frames: [
        with(sparkleSmall, hold: 2), with(sparkleBig, hold: 1), with(sparkleSmall, hold: 1), sparkleBig,
    ], fps: 8)

    /// Ce que montre le badge pour un état : image de repos, clip joué de temps en temps, et à quel rythme.
    struct Look {
        let rest: SpriteFrame
        let clip: SpriteClip
        let every: ClosedRange<Double>
    }

    static func look(for state: AgentState) -> Look? {
        switch state {
        case .idle: nil
        case .working: Look(rest: sparkleBig, clip: twinkle, every: 2.5...4)
        case .waitingReply: Look(rest: reply, clip: replyBounce, every: 4...5)
        case .needsApproval: Look(rest: approval, clip: approvalBounce, every: 1.5...2)
        }
    }

    static let allClips: [SpriteClip] = [twinkle, replyBounce, approvalBounce]

    private static func bounce(_ frame: SpriteFrame, name: String) -> SpriteClip {
        SpriteClip(name: name, frames: [with(frame, dy: -1, hold: 2), frame], fps: 8)
    }

    private static func with(_ frame: SpriteFrame, dy: Int = 0, hold: Int = 1) -> SpriteFrame {
        SpriteFrame(image: frame.image, dy: dy, hold: hold)
    }
}
