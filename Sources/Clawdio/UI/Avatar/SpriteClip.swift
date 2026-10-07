import CoreGraphics

/// Une image d'animation. `dx` / `dy` décalent le corps en pixels du sprite (un saut réutilise la même image au
/// lieu d'en dessiner une nouvelle ; l'ombre au sol, elle, ne bouge pas). `hold` = nombre de ticks où l'image reste.
struct SpriteFrame {
    let image: CGImage
    var dx = 0
    var dy = 0
    var hold = 1
    /// Calques d'origine (dessins de Clawd seulement) : un costume (`AvatarSkin`) les réassemble avec son corps.
    var layers: [PixelGrid] = []
    /// Variantes de la même image qui se relaient en continu, même sans clip (les flammes de Calcifer) ; vide = fixe.
    /// Voir `AvatarRepertoire.flickerFPS`.
    var flicker: [CGImage] = []

    /// Image à montrer à la phase `phase` du scintillement.
    func image(phase: Int) -> CGImage {
        flicker.isEmpty ? image : flicker[phase % flicker.count]
    }
}

/// Suite d'images jouée à cadence fixe, sans interpolation : une vraie animation image par image.
struct SpriteClip {
    let name: String
    let frames: [SpriteFrame]
    let fps: Double
    var loops = false
    /// Réplique dite pendant le clip (bulle de dialogue, dans le popup seulement : voir `AvatarView.speaks`).
    var quote: Quote? = nil

    struct Quote: Equatable {
        /// Qui parle : le personnage à gauche (Grace) ou à droite (Rocky). La bulle s'affiche de son côté.
        enum Side { case leading, trailing }
        let text: String
        var side: Side = .trailing
    }

    var ticks: Int { frames.reduce(0) { $0 + $1.hold } }
    var duration: Double { Double(ticks) / fps }

    func frame(at time: Double) -> SpriteFrame {
        var tick = max(0, Int(time * fps))
        if loops { tick %= max(ticks, 1) }
        for frame in frames {
            if tick < frame.hold { return frame }
            tick -= frame.hold
        }
        return frames[frames.count - 1] // clip terminé : on tient la dernière image
    }
}
