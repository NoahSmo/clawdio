/// Metteur en scène : décide ce que l'avatar joue ensuite selon son humeur. Un temps = une attente, un clip
/// (ou rien), puis une pause. Les attentes longues gardent le sprite immobile — donc gratuit — la plupart du temps.
enum AvatarDirector {
    struct Beat {
        var before: ClosedRange<Double> = 0...0
        var clip: SpriteClip?
        var after: ClosedRange<Double> = 0...0
        /// Non nil : après le clip, l'avatar s'endort (true) ou se réveille (false) — change sa pose de repos.
        var asleep: Bool?
    }

    /// Joué une fois à l'ouverture du popup.
    static let greeting = AvatarSprites.wave

    /// Rien ne se passe depuis ce délai (secondes, humeur `.idle`) : il s'endort.
    static let sleepAfter: Double = 180

    /// - `round` : temps écoulés depuis le dernier changement d'humeur (1, 2, 3…).
    /// - `idleFor` : secondes depuis le dernier changement d'humeur ou le dernier réveil.
    static func beat(for mood: AvatarMood, round: Int, idleFor: Double, asleep: Bool) -> Beat {
        switch mood {
        case .pushing:
            // Boucle serrée, sans pause : il pousse tant que dure la naissance de la pastille.
            Beat(clip: AvatarSprites.push)
        case .waiting:
            // Il attend ta réponse : coucou répété, avec une explosion de joie un temps sur quatre.
            Beat(clip: round % 4 == 0 ? AvatarSprites.cheer : AvatarSprites.wave, after: 2.2...3.2)
        case .attention:
            // Main levée en permanence (pose de repos), petits sauts insistants.
            Beat(clip: AvatarSprites.raiseHand, after: 1.2...1.8)
        case .working(let activity):
            // L'accessoire reste visible au repos (pose d'activité) ; le clip rejoue le geste de temps en temps.
            // Une pause au moins aussi longue que le clip : le sprite est immobile la moitié du temps.
            Beat(clip: AvatarSprites.activityClip(activity), after: 1.5...3)
        case .idle:
            idleBeat(idleFor: idleFor, asleep: asleep)
        }
    }

    /// Repos : gestes calmes et espacés, surtout des yeux ; bâille plus souvent à mesure que le temps passe,
    /// puis s'endort. Endormi, les « z » montent de temps en temps.
    private static func idleBeat(idleFor: Double, asleep: Bool) -> Beat {
        if asleep { return Beat(clip: AvatarSprites.snore, after: 3...6) }
        if idleFor > sleepAfter { return Beat(before: 1...2, clip: AvatarSprites.fallAsleep, asleep: true) }

        let drowsy = idleFor > sleepAfter / 2
        let weighted: [(SpriteClip, Double)] = [
            (AvatarSprites.blink, 35),
            (AvatarSprites.doubleBlink, 10),
            (AvatarSprites.lookAround, 25),
            (AvatarSprites.yawn, drowsy ? 15 : 4),
            (AvatarSprites.stretch, 7),
            (AvatarSprites.find, 5),
        ]
        var roll = Double.random(in: 0..<weighted.reduce(0) { $0 + $1.1 })
        let clip = weighted.first { roll -= $0.1; return roll < 0 }?.0 ?? AvatarSprites.blink
        return Beat(before: 4...9, clip: clip)
    }
}
