import SwiftUI

/// Réglages de rendu pour les captures debug (`--snapshot`) : `ImageRenderer` ne sait ni
/// jouer les animations d'apparition ni rendre le Liquid Glass (composé par le window server).
enum Reveal {
    static var instant = false
}

/// Palette du dégradé d'ouverture : beige rosé → lavande → violet, sur un fond teal
/// (échantillonnée sur la référence fournie).
enum Aurora {
    static let tan = Color(red: 0.85, green: 0.74, blue: 0.72)
    static let rose = Color(red: 0.87, green: 0.75, blue: 0.82)
    static let lavender = Color(red: 0.82, green: 0.68, blue: 0.87)
    static let violet = Color(red: 0.64, green: 0.47, blue: 0.76)
    static let teal = Color(red: 0.07, green: 0.23, blue: 0.29)
    static let colors = [tan, rose, lavender, violet, teal, tan]
}

/// Fond du panneau ouvert : Liquid Glass (macOS 26+), matériau flou sinon.
struct PanelBackground<S: Shape>: View {
    let shape: S

    var body: some View {
        if Reveal.instant {
            shape.fill(Color(white: 0.13))
        } else if #available(macOS 26.0, *) {
            // Teinte sombre : garde le texte lisible sur fond clair et rappelle le noir du notch.
            Color.clear.glassEffect(.regular.tint(.black.opacity(0.5)), in: shape)
        } else {
            shape.fill(.ultraThinMaterial)
                .overlay(shape.fill(.black.opacity(0.35)))
        }
    }
}

/// Un flanc de la pastille, sans jamais toucher le haut : côté, coin arrondi du bas, puis le bord inférieur jusqu'à son
/// milieu. Le tracé démarre en haut du flanc et se termine au centre du bord inférieur : avec `trim`, il « arrive » donc
/// depuis le bord et se rejoint au centre. Les coins concaves du haut et le bord supérieur sont exclus (collés à l'écran).
struct HaloEdge: Shape {
    var morph: MorphShape
    let left: Bool

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get { morph.animatableData }
        set { morph.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let (f, t, b) = morph.geometry(in: rect)
        var p = Path()
        if left {
            p.move(to: CGPoint(x: f.minX + t, y: f.minY + t))
            p.addLine(to: CGPoint(x: f.minX + t, y: f.maxY - b))
            p.addQuadCurve(to: CGPoint(x: f.minX + t + b, y: f.maxY), control: CGPoint(x: f.minX + t, y: f.maxY))
        } else {
            p.move(to: CGPoint(x: f.maxX - t, y: f.minY + t))
            p.addLine(to: CGPoint(x: f.maxX - t, y: f.maxY - b))
            p.addQuadCurve(to: CGPoint(x: f.maxX - t - b, y: f.maxY), control: CGPoint(x: f.maxX - t, y: f.maxY))
        }
        p.addLine(to: CGPoint(x: f.midX, y: f.maxY))
        return p
    }
}

/// Carte de luminosité du halo (alpha seul) : un cœur fin + deux halos flous de plus en plus larges, comme une LED dont la
/// lumière déborde. L'intérieur de la pastille est gommé : on ne garde que ce qui déborde (l'intérieur reste noir pur).
private struct HaloLight: View {
    let morph: MorphShape
    var progress: Double

    var body: some View {
        ZStack {
            ForEach([true, false], id: \.self) { left in
                let edge = HaloEdge(morph: morph, left: left).trim(from: 0, to: progress)
                edge.stroke(.white, style: StrokeStyle(lineWidth: 14, lineCap: .round)).blur(radius: 13).opacity(0.85)
                edge.stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round)).blur(radius: 5).opacity(0.9)
                edge.stroke(.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            }
            morph.fill(.black).blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

/// Halo autour de la pastille (lancement, agent qui attend) : deux moitiés qui partent des flancs et se rejoignent au
/// centre du bord inférieur (`progress` 0 → 1). Pas de halo sur le haut ni sur les coins supérieurs.
///
/// Rendu « LED » : la carte de luminosité (`HaloLight`) est rastérisée une seule fois ; dessous, une bande de dégradé
/// glisse lentement (les couleurs voyagent le long du bord) et l'intensité respire. Seuls un décalage et une opacité
/// s'animent : la carte, elle, n'est pas redessinée (un dégradé qui tourne DERRIÈRE un flou redessiné à chaque image
/// coûtait ~12 % de CPU).
struct HaloBorder: View {
    let morph: MorphShape
    var progress: Double
    @State private var drift = false
    @State private var breathe = false

    // Plus saturé que la palette du popup : une LED éclaire, elle ne se contente pas de teinter.
    private static let cycle = [
        Color(red: 1.00, green: 0.62, blue: 0.36), // orange
        Color(red: 0.98, green: 0.45, blue: 0.68), // rose
        Color(red: 0.66, green: 0.44, blue: 1.00), // violet
        Color(red: 0.45, green: 0.62, blue: 1.00), // bleu
        Color(red: 0.66, green: 0.44, blue: 1.00),
        Color(red: 0.98, green: 0.45, blue: 0.68),
        Color(red: 1.00, green: 0.62, blue: 0.36),
    ]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            // Le masque (flou + gomme intérieure) est rasterisé une fois pour toutes, indépendamment du dégradé qui
            // glisse dessous : sinon le flou du masque était recalculé à chaque image du glissement (plusieurs % de CPU).
            let light = HaloLight(morph: morph, progress: progress).drawingGroup()
            LinearGradient(colors: Self.cycle + Self.cycle.dropFirst(), startPoint: .leading, endPoint: .trailing)
                .frame(width: 2 * w, alignment: .leading)
                .offset(x: drift ? -w : 0)
                .frame(width: w, alignment: .leading)
                .mask(light)
        }
        // L'opacité suit `progress` 1:1 (au lieu d'atteindre 1 dès les premiers % comme avant) : sinon, à la
        // fermeture, le halo devenait invisible alors que le trait n'avait parcouru qu'une fraction du chemin
        // retour vers les flancs — un « pop » au lieu d'un fondu. Ainsi l'éclat suit exactement le tracé.
        .opacity(progress * (breathe ? 1 : 0.72))
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { drift = true }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}

/// Lavis de couleur qui monte depuis le bas de la zone "hero" à l'ouverture.
struct AuroraWash: View, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let envelope = sin(progress * .pi)
        ZStack {
            LinearGradient(colors: [.clear, Aurora.teal.opacity(0.55)], startPoint: .top, endPoint: .bottom)
            RadialGradient(
                colors: [Aurora.violet.opacity(0.75), Aurora.rose.opacity(0.35), .clear],
                center: UnitPoint(x: 0.58, y: 1.05),
                startRadius: 4,
                endRadius: 180
            )
            .opacity(envelope)
            RadialGradient(
                colors: [Aurora.tan.opacity(0.6), .clear],
                center: UnitPoint(x: 0.3, y: 1.0),
                startRadius: 2,
                endRadius: 120
            )
            .opacity(envelope * 0.8)
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// Ancien fondu échelonné par section : supprimé. Le popup entier fond déjà en ~0,2 s (comme la référence) ;
    /// un second fondu par section, décalé, étirait l'apparition à ~0,5 s et la rendait "en deux temps".
    /// Conservé sous forme neutre pour ne pas toucher aux sites d'appel.
    func reveal(_ on: Bool, _ index: Int) -> some View { self }
}
