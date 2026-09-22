import SwiftUI

/// Icône affichée à côté de l'avatar, différente selon ce dont l'agent a besoin (voir `BadgeSprites`).
/// `scale` = points par pixel, comme `AvatarView` : même échelle que l'avatar pour une densité de pixels uniforme.
struct StatusBadge: View {
    let state: AgentState
    var scale: CGFloat = 1

    @State private var clip: SpriteClip?
    @State private var startedAt = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let look = BadgeSprites.look(for: state) {
                TimelineView(.animation(minimumInterval: 1 / (clip?.fps ?? 8), paused: clip == nil)) { context in
                    let frame = clip?.frame(at: context.date.timeIntervalSince(startedAt)) ?? look.rest
                    PixelImage(image: frame.image, scale: scale)
                        .offset(x: CGFloat(frame.dx) * scale, y: CGFloat(frame.dy) * scale)
                }
                // Fondu seulement : un zoom continu casserait la grille de pixels le temps de l'animation.
                .transition(.opacity.animation(.easeOut(duration: 0.15)))
                .id(state)
            }
        }
        .frame(width: CGFloat(BadgeSprites.width) * scale, height: CGFloat(BadgeSprites.height) * scale, alignment: .topLeading)
        .task(id: state) { await run() }
        .onDisappear { clip = nil }
    }

    /// Un rebond à l'apparition, puis de temps en temps pour attirer l'œil sans être envahissant.
    private func run() async {
        guard !reduceMotion, let look = BadgeSprites.look(for: state) else { return }
        while !Task.isCancelled {
            await play(look.clip)
            try? await Task.sleep(for: .seconds(Double.random(in: look.every)))
        }
    }

    @MainActor
    private func play(_ next: SpriteClip) async {
        startedAt = .now
        clip = next
        try? await Task.sleep(for: .seconds(next.duration))
        clip = nil
    }
}
