import SwiftUI

/// L'avatar pixel art (16 × 16 px pour Clawd, 36 × 30 plus fins pour Rocky : voir `AvatarRepertoire`). `scale` = points par pixel du sprite de Clawd ; garder un entier (1 dans le notch,
/// 2 dans le popup) pour que chaque pixel couvre le même nombre de pixels écran.
///
/// Coût : au repos, `TimelineView` est en pause → aucun rendu. Pendant un clip, redessin à la cadence du clip.
/// Quoi jouer et quand : `AvatarDirector`.
struct AvatarView: View {
    let scale: CGFloat
    var mood: AvatarMood = .idle
    /// Coucou à l'apparition (popup).
    var greets = false
    /// false = invisible (popup préchauffé) : aucun clip n'est joué.
    var active = true
    /// Change à chaque survol : déclenche un petit saut.
    var nudge = 0
    /// Affiche les répliques des clips (`SpriteClip.quote`) dans une bulle à côté de l'avatar : dans le popup
    /// seulement, le notch n'a pas la place.
    var speaks = false

    @State private var clip: SpriteClip?
    /// Réplique affichée : reste un peu après la fin d'un clip court, le temps d'être lue.
    @State private var quote: SpriteClip.Quote?
    @State private var quoteToken = Date()
    @State private var startedAt = Date()
    /// Endormi (repos prolongé) : la pose de repos devient celle du sommeil (`AvatarRepertoire.sleeping`).
    @State private var asleep = false
    /// Depuis quand rien ne se passe : dernier changement d'humeur ou dernier réveil.
    @State private var quietSince = Date()
    /// Humeur dont on affiche la pose de repos. En retard d'une mise à jour sur `mood` : au changement, la vue
    /// montre encore l'ancienne pose jusqu'à ce que la transition démarre (sinon la nouvelle pose flasherait
    /// une image avant la transition).
    @State private var settledMood: AvatarMood
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.avatarCharacter) private var character

    private var cast: AvatarRepertoire { character.repertoire }

    init(scale: CGFloat, mood: AvatarMood = .idle, greets: Bool = false, active: Bool = true, nudge: Int = 0, speaks: Bool = false) {
        self.scale = scale
        self.speaks = speaks
        self.mood = mood
        self.greets = greets
        self.active = active
        self.nudge = nudge
        _settledMood = State(initialValue: mood)
    }

    private var restFrame: SpriteFrame {
        asleep && settledMood == .idle ? cast.sleeping : cast.rest(settledMood)
    }

    private struct BehaviorKey: Hashable {
        let mood: AvatarMood
        let active: Bool
        let character: AvatarCharacter
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / (clip?.fps ?? 12), paused: clip == nil)) { context in
            let frame = clip?.frame(at: context.date.timeIntervalSince(startedAt)) ?? restFrame
            AvatarCanvas(frame: frame, scale: cast.points(scale), shadow: cast.shadow, overlay: cast.overlay, width: cast.width, height: cast.height)
        }
        .frame(width: CGFloat(cast.width) * cast.points(scale), height: CGFloat(cast.height) * cast.points(scale))
        // Bulle du côté de celui qui parle, hors du cadre de l'avatar (au-dessus, le popup n'a pas la place).
        .overlay(alignment: quote?.side == .leading ? .leading : .trailing) {
            if let quote {
                SpeechBubble(quote: quote)
                    .alignmentGuide(.leading) { $0[.trailing] + 6 }
                    .alignmentGuide(.trailing) { $0[.leading] - 16 } // laisse la place au badge d'état
                    .transition(.opacity)
                    .id(quote.text)
            }
        }
        .task(id: BehaviorKey(mood: mood, active: active, character: character)) { if active { await run() } }
        .onChange(of: mood) { old, new in
            let from = restFrame // encore l'ancienne pose (settledMood n'a pas bougé)
            settledMood = new
            // Pas de transition à la fin de la naissance (l'avatar de naissance disparaît), ni animations réduites.
            guard active, !reduceMotion, old != .pushing else { return }
            let clip = AvatarSprites.transition(from: from, to: cast.rest(new))
            let token = begin(clip) // synchrone : la première image affichée après le changement est la transition
            Task {
                try? await Task.sleep(for: .seconds(clip.duration))
                if startedAt == token { self.clip = nil }
            }
        }
        .onChange(of: nudge) { _, _ in
            guard active, !reduceMotion else { return }
            if asleep {
                // Réveil au survol, même au milieu des « z » ; il repart pour un cycle complet avant de se rendormir.
                asleep = false
                quietSince = .now
                Task { await play(cast.wake) }
            } else if clip == nil { // ne coupe pas un clip en cours
                Task { await play(cast.hop) }
            }
        }
        .onDisappear { clip = nil; quote = nil }
    }

    /// Démarre un clip ; renvoie son jeton (sa date de départ) pour ne l'effacer que s'il est toujours affiché.
    @MainActor
    private func begin(_ next: SpriteClip) -> Date {
        let token = Date.now
        startedAt = token
        clip = next
        if speaks, let line = next.quote {
            withAnimation(.easeOut(duration: 0.15)) { quote = line }
            quoteToken = token
            Task {
                try? await Task.sleep(for: .seconds(max(next.duration, 2.5)))
                if quoteToken == token { withAnimation(.easeOut(duration: 0.25)) { quote = nil } }
            }
        }
        return token
    }

    @MainActor
    private func play(_ next: SpriteClip) async {
        let token = begin(next)
        try? await Task.sleep(for: .seconds(next.duration))
        // Aussi si la tâche est annulée : le TimelineView repasse en pause. Mais seulement si aucun autre clip
        // n'a pris la place entre-temps (réveil au survol pendant les « z »).
        if startedAt == token { clip = nil }
    }

    private func pause(_ range: ClosedRange<Double>) async {
        guard range.upperBound > 0 else { return }
        try? await Task.sleep(for: .seconds(Double.random(in: range)))
    }

    /// Boucle de comportement : relancée à chaque changement d'humeur (la tâche précédente est annulée).
    private func run() async {
        asleep = false
        quietSince = .now
        // Animations réduites (réglage d'accessibilité) : poses de repos seulement — l'objet tenu, la main levée
        // ou la bulle disent déjà tout, sans rien animer.
        if reduceMotion { return }
        // Laisse finir la transition de changement d'humeur lancée par `onChange(of: mood)`.
        await Task.yield()
        if let clip {
            let remaining = max(0, clip.duration - Date.now.timeIntervalSince(startedAt))
            try? await Task.sleep(for: .seconds(remaining))
        }
        if greets {
            await pause(0.5...0.6) // après l'ouverture du panneau
            await play(cast.wave)
        }
        var round = 0
        while !Task.isCancelled {
            round += 1
            let beat = AvatarDirector.beat(for: mood, round: round, idleFor: Date.now.timeIntervalSince(quietSince), asleep: asleep, cast: cast)
            await pause(beat.before)
            if Task.isCancelled { return }
            if let next = beat.clip { await play(next) }
            if Task.isCancelled { return }
            if let sleeping = beat.asleep { asleep = sleeping }
            await pause(beat.after)
            if beat.clip == nil && beat.before.upperBound == 0 && beat.after.upperBound == 0 {
                await pause(1...1) // garde-fou : un temps vide ne doit jamais tourner à vide
            }
        }
    }
}

/// Bulle de dialogue : une réplique courte, queue tournée vers celui qui parle.
private struct SpeechBubble: View {
    let quote: SpriteClip.Quote

    var body: some View {
        let towardLeft = quote.side == .trailing // Rocky parle à droite de l'avatar : la queue pointe à gauche
        Text(quote.text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(Color(white: 0.1))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(alignment: towardLeft ? .leading : .trailing) {
                Rectangle()
                    .fill(.white.opacity(0.92))
                    .frame(width: 6, height: 6)
                    .rotationEffect(.degrees(45))
                    .offset(x: towardLeft ? -2.5 : 2.5)
            }
    }
}

/// Une image de l'avatar : ombre au sol fixe, puis le corps décalé de (dx, dy) pixels.
struct AvatarCanvas: View {
    let frame: SpriteFrame
    let scale: CGFloat
    var shadow: CGImage = AvatarSprites.shadow
    var overlay: CGImage?
    var width: Int = AvatarSprites.size
    var height: Int = AvatarSprites.size

    var body: some View {
        ZStack(alignment: .topLeading) {
            PixelImage(image: shadow, scale: scale)
            PixelImage(image: frame.image, scale: scale)
                .offset(x: CGFloat(frame.dx) * scale, y: CGFloat(frame.dy) * scale)
            if let overlay { PixelImage(image: overlay, scale: scale) }
        }
        .frame(width: CGFloat(width) * scale, height: CGFloat(height) * scale, alignment: .topLeading)
    }
}

/// Image pixel art agrandie au plus proche voisin : les pixels restent nets.
struct PixelImage: View {
    let image: CGImage
    let scale: CGFloat

    var body: some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .interpolation(.none)
            .frame(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
    }
}
