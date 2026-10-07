/// Attente de ta réponse : il se demande ce que tu vas répondre — les yeux levés, qui vont d'un côté à l'autre.
/// Le « ? » est dans la bulle de pensée du badge (`BadgeSprites.reply`), au-dessus de lui : un second « ? » sur
/// l'avatar tombait pile dessous. Les personnages adaptés (`AvatarSkin`) reprennent ces yeux tels quels.
extension AvatarSprites {
    private static func wondering(_ eyes: PixelGrid) -> SpriteFrame {
        pose(Body.trunk, eyes, Legs.stand, Arms.leftDown, Arms.rightDown)
    }

    /// Pose tenue tant qu'il attend ta réponse : regard levé, vers la bulle.
    static let wonderRest = wondering(ToolEyes.upLeft)

    /// Il réfléchit : le regard passe d'en haut à gauche à en haut, et revient.
    static let wonder = SpriteClip(name: "wonder", frames: [
        with(wondering(ToolEyes.up), hold: 6),
        with(wonderRest, hold: 6),
        with(wondering(ToolEyes.up), hold: 4),
        with(wonderRest, hold: 2),
    ], fps: 8)
}
