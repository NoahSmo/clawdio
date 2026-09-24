import SwiftUI

struct NotchRootView: View {
    let usage: UsageModel
    let local: LocalUsageStore
    let sessions: SessionStore
    let settings: AppSettings
    let state: NotchState

    /// Progression du lavis coloré du hero : toujours 0. Le liseré / dégradé d'ouverture du popup a été retiré : le
    /// halo n'existe plus que sur le notch.
    private let glow = 0.0
    /// Opacités du fond noir et du verre : animées par `withAnimation` (états séparés) et NON par un `.animation`
    /// posé sur la forme. Un `.animation(..., value: mode)` collé sur la forme s'appliquait aussi à sa GÉOMÉTRIE :
    /// le noir grandissait avec l'easeInOut retardé de son fondu, pas avec le ressort du masque → contenu qui
    /// dépassait de la forme, largeur qui « stagnait », popup qui semblait sortir de nulle part.
    @State private var blackOpacity = 1.0
    @State private var glassOpacity = 0.0
    /// Halo autour de la pastille : au lancement/initialisation, puis en continu tant qu'un agent attend.
    /// 0 → 1 : le halo avance depuis les flancs jusqu'au centre du bord inférieur.
    @State private var haloProgress = Reveal.instant ? 1.0 : 0.0
    @State private var launchHalo = false
    /// Naissance de la pastille au lancement : 0 = largeur de l'encoche nue, 1 = pastille repliée. Voir `birthSequence`.
    @State private var leftBirth = Reveal.instant ? 1.0 : 0.0
    @State private var rightBirth = Reveal.instant ? 1.0 : 0.0
    /// Position (points) et écrasement du Clawd de naissance : il glisse sans avancer, recule, puis charge un bord.
    @State private var pushX: CGFloat = 0
    @State private var pushSquash: CGFloat = 1
    @State private var pushFacing: CGFloat = 1
    /// Tremblement de toute la pastille à l'impact (naissance) : voir `impact`.
    @State private var shakeX: CGFloat = 0

    private static let forceHalo = ProcessInfo.processInfo.environment["CLAWDIO_FORCEHALO"] != nil

    private var wantsHalo: Bool {
        settings.haloEnabled && mode != .expanded && (launchHalo || sessions.headline >= .waitingReply || Self.forceHalo)
    }

    private var mode: NotchMode { state.mode }
    /// Popup monté : ouvert, ou préchauffé (survol en cours).
    private var showExpanded: Bool { mode == .expanded || state.isWarm }
    /// La forme unique qui pilote TOUT (fond, masque du contenu, masque du verre, halo). Elle calcule elle-même sa
    /// taille et sa position à partir de `progress` (0 = pastille, 1 = popup) et `hover`, et se centre en haut du
    /// cadre qu'on lui donne : la fenêtre entière, de taille fixe. Aucun découpage/cadre SwiftUI à interpoler.
    private var morph: MorphShape {
        MorphShape(
            progress: mode == .expanded ? 1 : 0,
            hover: mode == .hovered ? 1 : 0,
            leftBirth: leftBirth,
            rightBirth: rightBirth,
            collapsed: state.geometry.collapsedSize,
            hoverGrow: state.geometry.hoverGrow,
            popup: state.geometry.expandedSize(rows: usage.rowCount),
            notchWidth: state.geometry.notchSize.width
        )
    }

    /// Hover : ressort lent (fluide) mais peu amorti (bounce visible : ~16 % de dépassement).
    private static let bump = Animation.spring(response: 0.42, dampingFraction: 0.5)
    /// Ressorts calés sur l'enregistrement de l'app de référence (mesure image par image à 60 i/s) :
    /// ouverture response 0,48 / damping 0,80 (90 % de la course à ~220 ms, 1,5 % de dépassement) ;
    /// fermeture ~150 ms. Un seul ressort pour largeur, hauteur et arrondis.
    private static let open = Animation.spring(response: 0.48, dampingFraction: 0.8)
    private static let close = Animation.spring(response: 0.26, dampingFraction: 0.95)

    private var hoverAnimation: Animation {
        switch settings.hoverStyle {
        case .off, .subtle: .spring(response: 0.3, dampingFraction: 0.9)
        case .bouncy: Self.bump
        }
    }

    private var sizeAnimation: Animation {
        switch mode {
        case .hovered: hoverAnimation
        case .expanded: Self.open
        case .collapsed: Self.close
        }
    }

    // MARK: Couches

    /// Fond : noir (fusionne avec le notch matériel) → verre liquide à l'ouverture.
    @ViewBuilder private var backgroundLayers: some View {
        let glass = settings.popupStyle == .glass
        // Noir du notch. En mode Verre il s'efface en fondu rapide sous le verre ; en mode Noir il reste :
        // le popup est alors le notch lui-même qui grandit (comme l'app de référence).
        morph.fill(.black)
            .opacity(blackOpacity)
        if showExpanded, glass {
            ZStack(alignment: .top) {
                PanelBackground(shape: morph)
                // Le haut du popup reste noir comme le notch, puis se fond dans le verre.
                LinearGradient(colors: [.black, .black.opacity(0.88), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: state.geometry.notchSize.height + 52)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .mask { morph }
            }
            // Monté (invisible) dès le survol ; visible = simple changement d'opacité.
            .opacity(glassOpacity)
        }
    }

    @ViewBuilder private var contentLayers: some View {
        // Le popup est monté (invisible, non cliquable) dès le survol : au clic il n'y a plus qu'à animer
        // taille et opacité, sans construction de vue pendant l'animation.
        if showExpanded {
            ExpandedContent(usage: usage, local: local, sessions: sessions, settings: settings, state: state, glow: glow)
                .frame(
                    width: NotchGeometry.expandedWidth,
                    height: state.geometry.expandedSize(rows: usage.rowCount).height,
                    alignment: .top
                )
                // Fondu simultané à la croissance (référence : dès 30 ms, plein en ~0,2 s).
                .opacity(mode == .expanded ? 1 : 0)
                .animation(mode == .expanded ? .easeOut(duration: 0.2).delay(0.03) : .easeOut(duration: 0.08), value: mode)
                .allowsHitTesting(mode == .expanded)
        }
        if mode != .expanded {
            // La pastille occupe exactement la taille de la forme au repos / survol.
            let pill = state.geometry.size(for: mode, rows: usage.rowCount)
            CollapsedContent(usage: usage, sessions: sessions, settings: settings, geometry: state.geometry, hovered: mode == .hovered, leftReady: rightBirth >= 0.999) {
                state.setExpanded(true)
            }
            .frame(width: pill.width, height: pill.height)
            // Les ailes du notch s'effacent vite à l'ouverture et reviennent à la fermeture.
            .transition(.asymmetric(
                insertion: .opacity.animation(.easeOut(duration: 0.15).delay(0.1)),
                removal: .opacity.animation(.easeOut(duration: 0.08))
            ))
            // Naissance : Clawd pousse au centre, bien visible (les ailes sont encore masquées à cet endroit-là,
            // le Clawd "final" du bord n'apparaît que lorsque le masque atteint sa largeur). Il patine près du bord
            // gauche sans avancer, recule, charge et étend ce bord, puis court étendre le bord droit (voir
            // `birthSequence`) — il s'écrase légèrement à chaque impact. Il disparaît une fois la pastille posée.
            if leftBirth < 0.999 || rightBirth < 0.999 {
                AvatarView(scale: CollapsedContent.avatarScale, mood: .pushing)
                    .scaleEffect(x: pushFacing, y: pushSquash, anchor: .bottom)
                    .offset(x: pushX)
                    .frame(width: state.geometry.notchSize.width, height: state.geometry.notchSize.height, alignment: .center)
                    .transition(.opacity.animation(.easeOut(duration: 0.18)))
            }
        }
    }

    /// Fondu enchaîné noir → verre. Le verre est entièrement en place (0,15 s) AVANT que le noir ne se retire
    /// (0,12 → 0,42 s) : un fondu simultané passait par un creux de transparence (flash du fond d'écran).
    private func syncFades(entering: Bool, leaving: Bool, animated: Bool = true) {
        let glass = settings.popupStyle == .glass
        func run(_ animation: Animation?, _ change: @escaping () -> Void) {
            if animated, let animation { withAnimation(animation, change) } else { change() }
        }
        if entering {
            run(.easeOut(duration: 0.15)) { glassOpacity = glass ? 1 : 0 }
            run(.easeInOut(duration: 0.3).delay(0.12)) { blackOpacity = glass ? 0 : 1 }
        } else if leaving {
            run(.easeOut(duration: 0.1)) { glassOpacity = 0 }
            run(.easeOut(duration: 0.15)) { blackOpacity = 1 }
        }
    }

    /// Les couches empilées, dans le cadre de la fenêtre (fixe).
    private var layers: some View {
        ZStack(alignment: .top) {
            backgroundLayers
            // Le contenu est de taille fixe et centré ; la forme animée le découpe (masque), à chaque image.
            ZStack(alignment: .top) { contentLayers }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .mask { morph }
            // Halo : sur le notch uniquement, jamais sur le popup ouvert.
            if mode != .expanded, haloProgress > 0.001 {
                HaloBorder(morph: morph, progress: haloProgress)
            }
        }
        // La fenêtre est fixe (taille du popup) : tout est centré en haut de ce cadre.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Animations de la forme : ressorts calés sur la référence. Ils pilotent `progress` / `hover` (un seul paramètre) :
    /// taille, position et arrondis suivent forcément la même courbe.
    private var animatedLayers: some View {
        layers
            .animation(sizeAnimation, value: mode)
            // "Pop" doux juste avant la fermeture (+1,5 % sur ~90 ms) : la fermeture démarre par un très léger gonflement.
            // (La référence fait +5 % en une image : trop sec ressenti ; on garde l'idée, en beaucoup plus discret.)
            .scaleEffect(state.isPopping ? 1.015 : 1, anchor: .top)
            .animation(.easeInOut(duration: 0.09), value: state.isPopping)
            // Tremblement du bord à l'impact, à la naissance (voir `impact`) : décalage horizontal bref et amorti.
            .offset(x: shakeX)
    }

    var body: some View {
        animatedLayers
            .onAppear { state.geometry.hoverGrow = settings.hoverStyle.grow }
            .onChange(of: settings.hoverStyle) { _, style in state.geometry.hoverGrow = style.grow }
            .onChange(of: mode) { old, new in modeChanged(from: old, to: new) }
            .onChange(of: wantsHalo) { _, wants in
                // Arrivée : depuis les flancs vers le centre. Départ : les deux moitiés se rétractent vers les flancs.
                withAnimation(.easeInOut(duration: wants ? 1.0 : 0.85)) { haloProgress = wants ? 1 : 0 }
            }
            .task { await launchHaloSequence() }
            .task { await birthSequence() }
            .onChange(of: settings.popupStyle) { _, _ in
                syncFades(entering: mode == .expanded, leaving: false, animated: false)
            }
            // Chaînes de l'interface : lues ici, donc tout le popup se redessine au changement de langue.
            .environment(\.t, settings.t)
            .environment(\.avatarCharacter, settings.avatar)
            // Fond toujours sombre → texte toujours clair, quel que soit le thème système.
            .environment(\.colorScheme, .dark)
            .foregroundStyle(.white)
    }

    /// Halo de lancement : au minimum 2,5 s, prolongé (8 s max) tant que l'analyse initiale des logs n'est pas finie.
    private func launchHaloSequence() async {
        guard !Reveal.instant else { return }
        if Self.forceHalo { withAnimation(.easeInOut(duration: 1.0)) { haloProgress = 1 } }
        launchHalo = true
        try? await Task.sleep(for: .seconds(2.5))
        var extra = 0
        while local.stats == nil, extra < 11 {
            try? await Task.sleep(for: .milliseconds(500))
            extra += 1
        }
        launchHalo = false
    }

    /// Naissance au lancement : la pastille part de la largeur exacte de l'encoche (soudée au bezel). Sur un vrai
    /// MacBook à encoche, ce rectangle central correspond au trou physique de la caméra : AUCUN pixel n'y est
    /// affichable, donc tout ce que Clawd fait tant qu'il reste dedans est invisible en vrai (même si nos captures
    /// internes le montrent, elles composent la fenêtre entière). Il faut donc le faire déborder tout de suite dans
    /// le petit bout d'aile qu'on ouvre exprès pour lui — LÀ où il y a de vrais pixels — avant même de le faire
    /// patiner : sinon les 3 premières secondes ne montrent rien du tout.
    private func birthSequence() async {
        guard !Reveal.instant else { return }
        try? await Task.sleep(for: .milliseconds(150)) // laisse la fenêtre s'installer, et Clawd le temps d'apparaître

        let half = state.geometry.notchSize.width / 2
        let wing = NotchGeometry.wingWidth
        let margin: CGFloat = 12 // Clawd s'arrête juste avant le bord définitif, sans le dépasser (sinon rogné)
        let leftWall = -(half + wing - margin)  // position finale, aile gauche totalement ouverte
        let rightWall = half + wing - margin    // idem à droite
        // Sliver ouvert tout de suite (bien avant que `leftBirth` avance vraiment) : juste assez pour que TOUT le
        // sprite (pas juste un pixel) dépasse le bord physique de l'encoche, avec de la marge — sinon il reste
        // dans la zone centrale, qui sur un vrai MacBook à encoche n'a tout simplement aucun pixel affichable.
        let spriteHalf: CGFloat = 13 * 1.9 / 2 // demi-largeur du Clawd de naissance (cell: 1.9)
        let clearance: CGFloat = 10             // marge en plus, pour être sûr d'être bien au-delà du bord physique
        let peekLeft = -(half + spriteHalf + clearance)
        let peekReveal = min(1, (spriteHalf * 2 + clearance) / wing) // ouvre le masque au moins jusque-là
        let towardCenter = -half * 0.25

        // Orientation animée (pas un flip instantané) : `pushFacing` passe par 0 en s'animant, donc le sprite se
        // comprime puis se retourne, comme une tête qui pivote plutôt qu'un miroir qui claque.
        withAnimation(.easeInOut(duration: 0.15)) { pushFacing = -1 }
        withAnimation(.easeOut(duration: 0.22)) { pushX = peekLeft; leftBirth = peekReveal }
        try? await Task.sleep(for: .seconds(0.24))

        // Phase 1 (≈2.6 s) — ça glisse : déjà visible, dans le bout d'aile ouvert. Il pousse mais patine, aucune
        // prise : `leftBirth` avance à peine (le reste est raconté par le patinage des pieds, côté Clawd.swift).
        withAnimation(.easeInOut(duration: 2.6)) { leftBirth = peekReveal + 0.1 }
        let slipUntil = Date().addingTimeInterval(2.6)
        while Date() < slipUntil {
            withAnimation(.easeInOut(duration: 0.16)) { pushX = peekLeft + 3 }
            try? await Task.sleep(for: .milliseconds(160))
            withAnimation(.easeInOut(duration: 0.16)) { pushX = peekLeft - 2 }
            try? await Task.sleep(for: .milliseconds(160))
        }

        // Phase 2 — bouge un peu vers le centre (il lâche prise, prend du recul).
        withAnimation(.easeOut(duration: 0.3)) { pushX = towardCenter }
        try? await Task.sleep(for: .seconds(0.34))

        // Phase 3 — revient taper le bord gauche : cette fois ça cède. Le mur s'ouvre EN MÊME TEMPS qu'il fonce
        // dessus (même animation, même durée pour `pushX` et `leftBirth`) : sinon le mur met plus de temps à
        // s'ouvrir que lui à arriver, et il disparaît brièvement juste avant l'impact (rogné par le masque).
        withAnimation(.easeIn(duration: 0.2)) { pushX = leftWall; leftBirth = 1 }
        try? await Task.sleep(for: .seconds(0.2))
        await impactFeedback(side: -1)
        try? await Task.sleep(for: .seconds(0.45)) // souffle avant de repartir : sinon les deux rushs s'enchaînent trop vite

        // Phase 4 — court taper le mur droit pour l'agrandir à son tour, même principe (mur et position ensemble).
        withAnimation(.easeInOut(duration: 0.15)) { pushFacing = 1 } // se retourne (animé) avant de partir
        withAnimation(.easeIn(duration: 0.46)) { pushX = rightWall; rightBirth = 1 }
        try? await Task.sleep(for: .seconds(0.46))
        await impactFeedback(side: 1)

        withAnimation(.easeOut(duration: 0.12)) { pushX = 0 }
    }

    /// Le mur vient de céder (voir les phases 3/4 ci-dessus, qui l'ouvrent déjà) : Clawd s'écrase brièvement contre
    /// lui, et TOUTE la pastille tremble (secousse horizontale amortie, ça se calme en 4 rebonds) — ça vend le choc
    /// bien mieux qu'un simple écrasement du sprite. `side` = -1 (mur gauche) ou +1 (mur droit) : la première
    /// secousse recule (à l'opposé du mur qui vient de céder), comme un contrecoup.
    private func impactFeedback(side: CGFloat) async {
        withAnimation(.easeOut(duration: 0.08)) { pushSquash = 0.68 }
        let kicks: [(CGFloat, Double)] = [(-side * 3.4, 0.045), (side * 2.2, 0.045), (-side * 1.3, 0.05), (side * 0.6, 0.05)]
        for (dx, dt) in kicks {
            withAnimation(.easeOut(duration: dt)) { shakeX = dx }
            try? await Task.sleep(for: .seconds(dt))
        }
        withAnimation(.easeOut(duration: 0.06)) { shakeX = 0 }
        withAnimation(.easeOut(duration: 0.15)) { pushSquash = 1 }
        try? await Task.sleep(for: .seconds(0.11))
    }

    private func modeChanged(from old: NotchMode, to new: NotchMode) {
        syncFades(entering: new == .expanded, leaving: old == .expanded && new != .expanded)
    }
}

// MARK: - Replié : [donut + heure de reset] · notch · [Clawd + icône de besoin]

private struct CollapsedContent: View {
    /// Points par pixel du sprite dans le notch (aussi pour l'avatar de naissance).
    static let avatarScale: CGFloat = 1.5

    let usage: UsageModel
    let sessions: SessionStore
    let settings: AppSettings
    let geometry: NotchGeometry
    let hovered: Bool
    /// false pendant la naissance de la pastille (voir `birthSequence`) : le donut et l'heure de reset restent
    /// masqués — sinon le fond noir qui grandit les "révèle" par un simple essuyage, pas très joli — puis tombent
    /// d'un coup une fois que Clawd a fini toute la naissance (les deux murs posés, pas juste le gauche).
    var leftReady = true
    let onTap: () -> Void
    /// Compte les survols : avec le réglage « Fixe », Clawd fait un petit saut à chaque survol.
    @State private var hoverCount = 0

    /// Au survol la pastille s'élargit de chaque côté : on décale d'autant le contenu pour qu'il
    /// reste immobile par rapport au notch (hover minimaliste : seul le fond bouge).
    private var growHalf: CGFloat { hovered ? geometry.hoverGrow.width / 2 : 0 }
    private var wingWidth: CGFloat { NotchGeometry.wingWidth + growHalf }

    var body: some View {
        let need = sessions.headline
        // Points en plus de Clawd (16 × 16) : la bulle suit le coin haut droit d'un avatar plus grand (Rocky).
        let cast = settings.avatar.repertoire
        let extraW = CGFloat(cast.width) * cast.points(Self.avatarScale) - CGFloat(AvatarSprites.size) * Self.avatarScale
        let extraH = CGFloat(cast.height) * cast.points(Self.avatarScale) - CGFloat(AvatarSprites.size) * Self.avatarScale
        HStack(spacing: 0) {
            Group {
                if leftReady {
                    HStack(spacing: 9) {
                        SessionDonut(percent: usage.snapshot?.session?.percent)
                        ResetTime(date: usage.snapshot?.session?.resetsAt, font: settings.timeFont)
                    }
                    // Tombent du haut à l'arrivée, plutôt que d'être "essuyés" par le fond qui grandit dessous.
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.62), value: leftReady)
            // Le côté extérieur de chaque aile est mangé par la courbure concave du haut (rayon 6–8).
            .padding(.leading, 12 + growHalf)
            .frame(width: wingWidth, alignment: .leading)

            Spacer(minLength: 0)

            ZStack(alignment: .bottomLeading) {
                // ×1,5 : 3 pixels écran par pixel du sprite sur un Retina (tous les Mac à encoche le sont) — net,
                // et plus lisible qu'à ×1. Badge à la même échelle : même taille de pixels que l'avatar.
                AvatarView(scale: Self.avatarScale, mood: AvatarMood(need, tool: sessions.headlineTool), nudge: geometry.hoverGrow == .zero ? hoverCount : 0)
                    .offset(y: 4) // pieds près du bas de la pastille, place au-dessus pour la bulle
                // Bulle en haut à droite de la tête, queue contre la tempe : au-dessus de la tête, elle touchait le
                // haut de l'écran (pastille de 38 pt). Suit le coin haut droit d'un avatar plus grand (Rocky).
                StatusBadge(state: need, scale: Self.avatarScale)
                    .offset(x: 18 + extraW / 2, y: -12.5 - extraH / 2) // à moitié : sinon elle sort de la pastille / touche le haut de l'écran
            }
            .frame(width: 38, height: geometry.notchSize.height, alignment: .center)
            .padding(.trailing, 13 + growHalf)
            .frame(width: wingWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
        .frame(height: geometry.notchSize.height)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onChange(of: hovered) { _, isHovered in if isHovered { hoverCount += 1 } }
    }
}

/// Anneau coloré qui se remplit progressivement jusqu'au % de la session 5 h.
private struct SessionDonut: View {
    let percent: Double?
    @State private var shown = Reveal.instant
    @State private var pulse = false

    var body: some View {
        let value = percent ?? 0
        let level = UsageLevel(percent: value)
        ZStack {
            Circle().stroke(.white.opacity(0.16), lineWidth: 3.2)
            Circle()
                .trim(from: 0, to: shown && percent != nil ? min(max(value / 100, 0.025), 1) : 0)
                .stroke(level.color, style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: level.color.opacity(0.55), radius: 2.5)
        }
        .frame(width: 18, height: 18)
        .opacity(level == .critical && pulse ? 0.55 : 1)
        .animation(.smooth(duration: 1.2), value: shown)
        .animation(.smooth(duration: 0.8), value: value)
        .task {
            try? await Task.sleep(for: .milliseconds(150)) // laisse la pastille finir de s'installer
            shown = true
        }
        .task(id: level == .critical) {
            guard level == .critical else { pulse = false; return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

private struct ResetTime: View {
    let date: Date?
    let font: TimeFont
    @Environment(\.t) private var t

    var body: some View {
        Group {
            if let date {
                Text(t.time(date))
            }
            // Pas de date connue (pas encore de session) : rien plutôt qu'un « – » qui traîne à côté du donut vide.
        }
        .font(font.font(size: font == .minecraft ? 10 : 10.5))
        .lineLimit(1)
        .fixedSize()  // jamais de retour à la ligne : Monocraft est plus large que la police système
        .foregroundStyle(.white.opacity(0.9))
        .contentTransition(.numericText())
        .animation(.smooth, value: date)
    }
}

// MARK: - Ouvert

private struct ExpandedContent: View {
    let usage: UsageModel
    let local: LocalUsageStore
    let sessions: SessionStore
    let settings: AppSettings
    @Bindable var state: NotchState
    let glow: Double
    @State private var appeared = Reveal.instant
    @Environment(\.t) private var t

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: ExpandedLayout.spacing) {
                HeroView(sessions: sessions, glow: glow, active: state.isExpanded)
                    .reveal(appeared, 0)

                page
                    .frame(height: ExpandedLayout.pageHeight(rows: usage.rowCount), alignment: .top)
                    .id(state.page) // change de page → fondu croisé
                    .transition(.opacity)

                footer.reveal(appeared, 4)
            }
            .padding(.horizontal, ExpandedLayout.horizontalPadding)
            .padding(.top, state.geometry.notchSize.height + ExpandedLayout.topGap)
            .frame(maxHeight: .infinity, alignment: .top)

            // Boutons dans la bande du notch, de part et d'autre de l'encoche : exactement là où se trouvaient
            // les ailes de la pastille, donc elles "deviennent" la barre d'outils (comme l'app de référence).
            TopBand(usage: usage, local: local, sessions: sessions, state: state)
        }
        .animation(.easeOut(duration: 0.22), value: state.page)
        .onAppear { appeared = true }
    }

    @ViewBuilder private var page: some View {
        switch state.page {
        case .stats:
            statsPage
        case .history:
            HistoryPage(store: sessions, state: state)
        case .thread(let id):
            ThreadPage(store: sessions, sessionID: id)
        case .settings:
            SettingsPage(settings: settings, sessions: sessions)
        }
    }

    private var statsPage: some View {
        let rows = usage.snapshot?.rows ?? []
        return VStack(alignment: .leading, spacing: ExpandedLayout.spacing) {
            StatsRow(stats: local.stats).reveal(appeared, 1)

            VStack(spacing: 4) {
                MinimalChart(stats: local.stats, metric: state.metric, state: state)
                ChartNote(stats: local.stats, metric: $state.metric)
            }
            .reveal(appeared, 2)

            if rows.isEmpty {
                Text(usage.statusMessage(t) ?? t(.loading))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(3)
                    .frame(height: ExpandedLayout.rowHeight, alignment: .leading)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    QuotaRow(row: row, revealed: appeared).reveal(appeared, 3 + index)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let snapshot = usage.snapshot, usage.isRateLimited {
                // Pas une alerte : les dernières valeurs restent affichées, le rafraîchissement est juste en pause.
                let when = usage.retryAt.map(t.time) ?? t(.retrySoon)
                Label {
                    UpdatedText(date: snapshot.fetchedAt, plan: nil, retry: when)
                } icon: {
                    Image(systemName: "clock")
                }
                .foregroundStyle(.white.opacity(0.6))
            } else if usage.snapshot != nil, let error = usage.error {
                Label(error.message(t), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else if let fetched = usage.snapshot?.fetchedAt {
                UpdatedText(date: fetched, plan: usage.snapshot?.plan, retry: nil)
            }
            Spacer()
            Button {
                sessions.setSoundEnabled(!sessions.soundEnabled)
            } label: {
                Image(systemName: sessions.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 20, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(t(.soundHelp))
            Button(t(.quit)) { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
        }
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.45))
        .lineLimit(1)
        .frame(height: ExpandedLayout.footerHeight)
    }
}

// MARK: - Hero : Clawd, besoin de l'agent, boutons

private struct HeroView: View {
    let sessions: SessionStore
    let glow: Double
    /// false tant que le popup est préchauffé mais invisible : Clawd ne joue aucune scène (chaque scène redessine la fenêtre).
    let active: Bool
    @Environment(\.t) private var t
    @Environment(\.avatarCharacter) private var character

    /// Taille de l'avatar dans le popup (×2) : 32 × 32 pt pour Clawd, 54 × 45 pour Rocky.
    private var avatarWidth: CGFloat { CGFloat(character.repertoire.width) * character.repertoire.points(2) }
    private var avatarHeight: CGFloat { CGFloat(character.repertoire.height) * character.repertoire.points(2) }

    var body: some View {
        let need = sessions.headline
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.05))
                .overlay(AuroraWash(progress: glow).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)))

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ZStack(alignment: .bottomLeading) {
                    AvatarView(scale: 2, mood: AvatarMood(need, tool: sessions.headlineTool), greets: true, active: active, speaks: true)
                    StatusBadge(state: need, scale: 2)
                        .offset(x: avatarWidth - 12, y: 4 - avatarHeight)
                }
                .frame(width: avatarWidth + 24, height: avatarHeight, alignment: .bottomLeading)
                statusText(need)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
            }
        }
        .frame(height: ExpandedLayout.heroHeight)
    }

    private func statusText(_ need: AgentState) -> some View {
        let session = sessions.headlineSession
        let title = session.flatMap { $0.title.isEmpty ? nil : $0.title } ?? "Claude"
        let text: String
        let color: Color
        switch need {
        case .idle:
            (text, color) = (t(.statusNone), .white.opacity(0.4))
        case .working:
            (text, color) = (t(.statusWorking, title), .white.opacity(0.65))
        case .waitingReply:
            (text, color) = (t(.statusWaiting, title), .white.opacity(0.85))
        case .needsApproval:
            (text, color) = (
                session?.pendingTool.map { t(.statusApprovalTool, $0) } ?? t(.statusApprovalAction, title),
                Color(red: 1.0, green: 0.65, blue: 0.30)
            )
        }
        return Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .animation(.easeOut(duration: 0.25), value: text)
    }
}

/// "Pro · mis à jour il y a 3 min" / "dernières valeurs : … · réessai 20:02". Rafraîchi toutes les 30 s seulement.
private struct UpdatedText: View {
    let date: Date
    let plan: String?
    let retry: String?
    @Environment(\.t) private var t

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let age = AgeText.phrase(from: date, to: context.date, t: t)
            if let retry {
                Text(t(.rateLimitFooter, age, retry))
            } else if let plan {
                Text(t(.planUpdatedFmt, plan.capitalized, age))
            } else {
                Text(t(.updatedFmt, age))
            }
        }
    }
}

/// Apparition "par échelle" : `amount` 0 = caché (réduit, flou, transparent) → 1 = normal.
/// Ancré en haut : le contenu se déplie depuis le notch.
private struct Emerge: ViewModifier {
    var amount: Double
    var from: CGFloat = 0.9

    func body(content: Content) -> some View {
        content
            .opacity(amount)
            .scaleEffect(from + (1 - from) * amount, anchor: .top)
            .blur(radius: (1 - amount) * 7)
    }
}

// MARK: - Barre d'outils dans la bande du notch

private struct TopBand: View {
    let usage: UsageModel
    let local: LocalUsageStore
    let sessions: SessionStore
    @Bindable var state: NotchState
    @Environment(\.t) private var t

    var body: some View {
        HStack(spacing: 0) {
            historyButton
            // On laisse libre la zone de l'encoche matérielle.
            Spacer(minLength: state.geometry.notchSize.width + 24)
            HStack(spacing: 2) {
                iconButton("gearshape") {
                    withAnimation(.snappy(duration: 0.3)) { state.page = state.page == .settings ? .stats : .settings }
                }
                iconButton("arrow.clockwise") {
                    Task { await usage.refresh(force: true) }
                    Task { await local.refresh() }
                }
                .rotationEffect(.degrees(usage.isRefreshing ? 360 : 0))
                .animation(
                    usage.isRefreshing ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
                    value: usage.isRefreshing
                )
                .disabled(usage.isRefreshing)
                iconButton("chevron.up") { state.setExpanded(false) }
            }
        }
        .padding(.horizontal, 30)
        .frame(width: NotchGeometry.expandedWidth, height: state.geometry.notchSize.height)
    }

    private var historyButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.3)) { state.page = backTarget ?? .history }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: backTarget == nil ? "clock.arrow.circlepath" : "chevron.left")
                Text(backTarget == nil ? t(.history) : t(.back))
                if backTarget == nil, sessions.attentionCount > 0 {
                    Circle().fill(Color(red: 1.0, green: 0.60, blue: 0.22)).frame(width: 6, height: 6)
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(.white.opacity(0.08), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Où mène "Retour" (nil = on est sur la page stats, le bouton ouvre l'historique).
    private var backTarget: PopupPage? {
        switch state.page {
        case .stats: nil
        case .history, .settings: .stats
        case .thread: .history
        }
    }

    private func iconButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Forme animée unique

/// Rectangle "notch" dont la taille est interpolée entre la pastille (`progress` 0) et le popup (`progress` 1), avec un
/// léger grossissement au survol (`hover`). Il se centre en haut du cadre fourni. `progress` peut dépasser 1 (rebond du
/// ressort). Tout ce qui doit épouser la forme (fond, masque, verre, halo) utilise CETTE forme : aucun cadre SwiftUI
/// à interpoler, donc aucune divergence possible entre le fond et son découpage.
struct MorphShape: Shape {
    var progress: Double
    var hover: Double
    /// 0 = bord soudé à l'encoche nue · 1 = bord de la pastille repliée. Indépendants (gauche/droite) pour que
    /// Clawd puisse étendre un côté avant l'autre à la naissance. Uniquement animés une fois, au lancement de
    /// l'app : ensuite toujours à 1 tous les deux.
    var leftBirth: Double
    var rightBirth: Double
    let collapsed: CGSize
    let hoverGrow: CGSize
    let popup: CGSize
    let notchWidth: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get { .init(.init(progress, hover), .init(leftBirth, rightBirth)) }
        set {
            progress = newValue.first.first; hover = newValue.first.second
            leftBirth = newValue.second.first; rightBirth = newValue.second.second
        }
    }

    /// Rectangle courant de la forme (centré en haut de `rect`) et ses deux rayons d'arrondi.
    func geometry(in rect: CGRect) -> (frame: CGRect, top: CGFloat, bottom: CGFloat) {
        let p = min(max(progress, -0.03), 1.15)
        let h = min(max(hover, 0), 1)
        // Pas de plafond sur lb/rb : le ressort de fin de naissance dépasse légèrement 1.
        let lb = max(leftBirth, 0)
        let rb = max(rightBirth, 0)
        let wing = (collapsed.width - notchWidth) / 2 // largeur d'une aile, à taille repliée
        // Bords de la naissance (asymétriques tant que lb ≠ rb) ; leur centre sert de pivot pour la croissance
        // symétrique suivante (survol, popup) — une fois lb = rb = 1, ce centre retombe exactement sur rect.midX.
        let leftEdge = rect.midX - notchWidth / 2 - wing * lb
        let rightEdge = rect.midX + notchWidth / 2 + wing * rb
        let birthWidth = rightEdge - leftEdge
        let birthCenter = (leftEdge + rightEdge) / 2

        let base = CGSize(width: birthWidth + hoverGrow.width * h, height: collapsed.height + hoverGrow.height * h)
        let width = base.width + (popup.width - base.width) * p
        let height = base.height + (popup.height - base.height) * p
        let frame = CGRect(x: birthCenter - width / 2, y: rect.minY, width: width, height: height)

        // Arrondis : ceux du survol ne s'appliquent que si la pastille grossit réellement.
        let grows = hoverGrow != .zero
        let restTop = 6 + (grows ? 4 * h : 0)
        let restBottom = 12 + (grows ? 5 * h : 0)
        return (frame, restTop + (22 - restTop) * p, restBottom + (32 - restBottom) * p)
    }

    func path(in rect: CGRect) -> Path {
        let (frame, top, bottom) = geometry(in: rect)
        return NotchShape(topRadius: top, bottomRadius: bottom).path(in: frame)
    }
}
