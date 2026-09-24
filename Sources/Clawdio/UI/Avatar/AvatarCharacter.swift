import CoreGraphics
import SwiftUI

/// Personnage de l'avatar, choisi dans les Paramètres.
enum AvatarCharacter: String, CaseIterable, Identifiable {
    case clawd  // la mascotte de Claude Code
    case rocky  // l'Éridien de « Projet Hail Mary » (Andy Weir)
    case rockySuit  // le même, en combinaison de sortie
    case rockyBubble  // le même, dans sa bulle de verre
    case rockyGrace  // Rocky et Grace, qui se disent les répliques du film

    var id: String { rawValue }

    /// Nom propre : identique dans toutes les langues.
    var name: String {
        switch self {
        case .clawd: "Clawd"
        case .rocky: "Rocky"
        case .rockySuit: "Rocky EVA"
        case .rockyBubble: "Rocky bulle"
        case .rockyGrace: "Rocky & Grace"
        }
    }

    var repertoire: AvatarRepertoire {
        switch self {
        case .clawd: .clawd
        case .rocky: .rocky
        case .rockySuit: .rockySuit
        case .rockyBubble: .rockyBubble
        case .rockyGrace: .rockyGrace
        }
    }
}

/// Tout ce qu'un personnage sait jouer. `AvatarView` et `AvatarDirector` ne connaissent que ça : chaque
/// personnage garde ses propres gestes (Clawd cligne des yeux, Rocky, sans yeux, fredonne).
struct AvatarRepertoire {
    /// Taille du canevas, en pixels du sprite (Clawd : 16 × 16 ; Rocky, plus large que haut : 24 × 20).
    let width: Int
    let height: Int
    /// Taille d'un pixel du sprite par rapport à ceux de Clawd : Rocky, plus détaillé, a des pixels plus petits
    /// pour tenir dans la même place.
    var pixelScale: CGFloat = 1

    /// Points par pixel du sprite pour une échelle donnée (celle de Clawd), arrondis au demi-point : sur Retina,
    /// chaque pixel couvre alors un nombre entier de pixels écran et reste net.
    func points(_ scale: CGFloat) -> CGFloat {
        max(0.5, (scale * pixelScale * 2).rounded() / 2)
    }
    let shadow: CGImage
    /// Dessiné par-dessus, fixe comme l'ombre (la bulle de Rocky) : ne suit pas les sauts.
    var overlay: CGImage? = nil
    let stand: SpriteFrame
    /// Pose tenue pendant le sommeil (remplace la pose de repos).
    let sleeping: SpriteFrame
    /// Image tenue quand aucun clip ne joue.
    let rest: (AvatarMood) -> SpriteFrame
    let activityClip: (AvatarActivity) -> SpriteClip
    let hop, wave, cheer, raiseHand, push, fallAsleep, snore, wake: SpriteClip
    /// Gestes de repos tirés au sort : poids normal, puis poids une fois somnolent (voir `AvatarDirector`).
    let idle: [(clip: SpriteClip, weight: Double, drowsy: Double)]

    /// Tous les clips, pour la planche contact et la page de visualisation.
    var allClips: [SpriteClip] {
        [hop, wave, cheer, raiseHand, push] + idle.map(\.clip) + [fallAsleep, snore, wake]
            + AvatarActivity.allCases.map(activityClip)
    }
}

extension AvatarRepertoire {
    static let clawd = AvatarRepertoire(
        width: AvatarSprites.size, height: AvatarSprites.size,
        shadow: AvatarSprites.shadow,
        stand: AvatarSprites.stand,
        sleeping: AvatarSprites.sleeping,
        rest: AvatarSprites.rest,
        activityClip: AvatarSprites.activityClip,
        hop: AvatarSprites.hop, wave: AvatarSprites.wave, cheer: AvatarSprites.cheer,
        raiseHand: AvatarSprites.raiseHand, push: AvatarSprites.push,
        fallAsleep: AvatarSprites.fallAsleep, snore: AvatarSprites.snore, wake: AvatarSprites.wake,
        idle: [
            (AvatarSprites.blink, 35, 35),
            (AvatarSprites.doubleBlink, 10, 10),
            (AvatarSprites.lookAround, 25, 25),
            (AvatarSprites.yawn, 4, 15),
            (AvatarSprites.stretch, 7, 7),
            (AvatarSprites.find, 5, 5),
        ]
    )

    static let rocky = AvatarRepertoire(RockySprites(.natural))
    static let rockySuit = AvatarRepertoire(RockySprites(.suit))
    static let rockyBubble = AvatarRepertoire(RockySprites(.bubble))
    static let rockyGrace = AvatarRepertoire(RockySprites(.duo))

    init(_ rocky: RockySprites) {
        self.init(
            width: rocky.width, height: rocky.height, pixelScale: rocky.pixelScale,
            shadow: rocky.shadow,
            overlay: rocky.overlay,
            stand: rocky.stand,
            sleeping: rocky.sleeping,
            rest: rocky.rest,
            activityClip: rocky.activityClip,
            hop: rocky.hop, wave: rocky.wave, cheer: rocky.cheer,
            raiseHand: rocky.raiseHand, push: rocky.push,
            fallAsleep: rocky.fallAsleep, snore: rocky.snore, wake: rocky.wake,
            idle: rocky.idle
        )
    }
}

// MARK: - Environnement SwiftUI

private struct AvatarCharacterKey: EnvironmentKey {
    static let defaultValue = AvatarCharacter.clawd
}

extension EnvironmentValues {
    /// Personnage joué par toutes les `AvatarView` du notch et du popup (réglage `AppSettings.avatar`).
    var avatarCharacter: AvatarCharacter {
        get { self[AvatarCharacterKey.self] }
        set { self[AvatarCharacterKey.self] = newValue }
    }
}
