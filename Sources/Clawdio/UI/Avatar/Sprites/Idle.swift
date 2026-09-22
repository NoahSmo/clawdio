/// Répertoire de repos (humeur `.idle`) : des gestes calmes, surtout des yeux — le corps et les bras bougent le
/// moins possible — puis le sommeil quand rien ne se passe depuis un moment (voir `AvatarDirector`).
extension AvatarSprites {
    enum IdleEyes {
        /// Paupières closes : un trait sous chaque œil.
        static let closed = layer(8, ["....EE....EE...."])
        /// Mi-closes (clignement, somnolence) : yeux d'un pixel de haut.
        static let half = layer(8, [".....E....E....."])
        static let left = layer(7, ["....E....E......", "....E....E......"])
        static let right = layer(7, ["......E....E....", "......E....E...."])
        /// Regard baissé vers le sol, à droite (le rubis).
        static let downRight = layer(8, ["......E....E...."])
    }

    enum IdleProps {
        /// Bouche du bâillement, petite puis grande.
        static let mouthSmall = layer(10, [".......EE......."])
        static let mouthBig = layer(9, [".......EE.......", ".......EE......."])

        /// « z » qui montent au-dessus de la tête, à droite : un point, un z, un z qui s'efface. En 3 × 3, un z
        /// s'écrit `WW.` / `.W.` / `.WW` (comme dans les polices pixel) : avec deux barres pleines, on lirait un « I ».
        static let zDot = layer(4, ["..............W."])
        static let zLow = layer(2, [".............WW.", "..............W.", "..............WW"])
        static let zHigh = layer(0, [".............ww.", "..............w.", "..............ww"])

        /// Rubis posé au sol à droite de ses pieds, avec un éclat qui scintille.
        static let gem = layer(12, ["............R...", "...........RqR..", "............R..."])
        static let gemGlint = layer(11, ["..............W."])
        /// Le rubis disparaît dans un petit éclat.
        static let gemPop = layer(11, ["............Y...", "...........YWY..", "............Y..."])
    }

    private static func standing(_ extras: PixelGrid...) -> SpriteFrame {
        SpriteFrame(image: PixelGrid.layered([Body.trunk, Legs.stand, Arms.leftDown, Arms.rightDown] + extras).makeImage())
    }

    // MARK: Poses

    private static let eyesClosed = standing(IdleEyes.closed)
    private static let eyesHalf = standing(IdleEyes.half)
    private static let lookingLeft = standing(IdleEyes.left)
    private static let lookingRight = standing(IdleEyes.right)
    private static let yawnSmall = standing(IdleEyes.closed, IdleProps.mouthSmall)
    private static let yawnBig = standing(IdleEyes.closed, IdleProps.mouthBig)
    private static let stretching = pose(Body.trunk, IdleEyes.closed, Legs.stand, Arms.leftUp, Arms.rightUp)

    /// Pose tenue pendant le sommeil (remplace la pose de repos, voir `AvatarView`).
    static let sleeping = eyesClosed

    // MARK: Clips

    static let blink = SpriteClip(name: "blink", frames: [eyesClosed, stand], fps: 8)
    static let doubleBlink = SpriteClip(name: "doubleBlink", frames: [eyesClosed, stand, eyesClosed, stand], fps: 8)

    /// Coup d'œil à gauche, puis à droite : seuls les yeux bougent.
    static let lookAround = SpriteClip(name: "lookAround", frames: [
        with(lookingLeft, hold: 8), with(stand, hold: 2), with(lookingRight, hold: 8), stand,
    ], fps: 8)

    static let yawn = SpriteClip(name: "yawn", frames: [
        with(eyesHalf, hold: 2), yawnSmall, with(yawnBig, hold: 5), yawnSmall, with(eyesHalf, hold: 2), stand,
    ], fps: 6)

    /// Un seul grand geste, lent : bras en l'air, yeux fermés, puis relâché.
    static let stretch = SpriteClip(name: "stretch", frames: [
        with(stretching, hold: 6), with(eyesClosed, hold: 2), stand,
    ], fps: 6)

    /// Un rubis apparaît à ses pieds et scintille ; il le regarde, sourit, et le rubis s'évanouit.
    static let find = SpriteClip(name: "find", frames: [
        with(standing(Eyes.open, IdleProps.gem), hold: 3),
        standing(Eyes.open, IdleProps.gem, IdleProps.gemGlint),
        with(standing(IdleEyes.downRight, IdleProps.gem), hold: 4),
        standing(IdleEyes.downRight, IdleProps.gem, IdleProps.gemGlint),
        with(standing(Eyes.happy, IdleProps.gem), hold: 6),
        with(standing(Eyes.happy, IdleProps.gemPop), hold: 2),
        with(stand, hold: 2),
    ], fps: 8)

    /// Il s'assoupit : yeux mi-clos, il lutte une fois, puis s'endort.
    static let fallAsleep = SpriteClip(name: "fallAsleep", frames: [
        with(eyesHalf, hold: 3), with(eyesClosed, hold: 2), with(eyesHalf, hold: 2), with(sleeping, hold: 3),
    ], fps: 6)

    /// Les « z » montent lentement pendant qu'il dort.
    static let snore = SpriteClip(name: "snore", frames: [
        standing(IdleEyes.closed, IdleProps.zDot),
        with(standing(IdleEyes.closed, IdleProps.zLow), hold: 2),
        with(standing(IdleEyes.closed, IdleProps.zHigh), hold: 2),
        with(sleeping, hold: 2),
    ], fps: 3)

    /// Réveil (survol) : il ouvre les yeux et fait un petit bond.
    static let wake = SpriteClip(name: "wake", frames: [
        with(eyesHalf, hold: 2), with(stand, dy: -1), with(stand, hold: 2),
    ], fps: 8)

    static let idleClips: [SpriteClip] = [blink, doubleBlink, lookAround, yawn, stretch, find, fallAsleep, snore, wake]
}
