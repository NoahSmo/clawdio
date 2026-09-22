import AppKit
import SwiftUI

/// Colle tout : possède le panel, suit la souris, redimensionne la fenêtre à chaque état.
///
/// Survol → la pastille grossit · clic → elle s'ouvre · clic ailleurs (ou chevron) → elle se ferme.
/// Le panel épouse *exactement* la pastille (pas de grande fenêtre transparente) : les clics
/// à côté du notch continuent d'aller aux apps en dessous.
@MainActor
final class NotchController {
    private let usage = UsageModel()
    private let local = LocalUsageStore()
    private let sessions = SessionStore()
    private let settings = AppSettings()
    private let state: NotchState
    private let panel = NotchPanel()
    private var mouseMonitors: [Any] = []
    private var hoverTarget = false
    private var hoverTask: Task<Void, Never>?
    private var warmTask: Task<Void, Never>?
    private let escape = EscapeHotKey()
    private var shrinkTask: Task<Void, Never>?

    init?() {
        guard let screen = NotchGeometry.preferredScreen() else { return nil }
        var geometry = NotchGeometry(screen: screen)
        geometry.hoverGrow = settings.hoverStyle.grow
        state = NotchState(geometry: geometry)

        panel.contentView = FirstMouseHostingView(rootView: NotchRootView(usage: usage, local: local, sessions: sessions, settings: settings, state: state))

        usage.onLayoutChange = { [weak self] in self?.applyFrame() }
        state.onExpandedChange = { [weak self] in self?.expandedChanged() }
        state.prepareExpand = { [weak self] in await self?.prepareForExpansion() }
        escape.onPress = { [weak self] in self?.state.setExpanded(false) }
        // Fenêtre toujours à la taille du popup, transparente et traversante : on ne la redimensionne JAMAIS à
        // l'ouverture (le redimensionnement laissait SwiftUI recentrer son contenu avec retard : la forme grandissait
        // depuis le coin supérieur gauche). Elle ne capte les clics qu'au-dessus de la pastille ou popup ouvert.
        panel.ignoresMouseEvents = true
        panel.acceptsMouseMovedEvents = true
        applyFrame()
        panel.orderFrontRegardless()
        startMouseMonitoring()
        usage.start()
        local.start()
        sessions.start()

        if ProcessInfo.processInfo.environment["CLAWDIO_TRACE"] == "halo" {
            // Halo de lancement : images toutes les 170 ms pendant ~3 s.
            let d = Double(ProcessInfo.processInfo.environment["CLAWDIO_HALODUR"] ?? "") ?? 3.2
            let step = Double(ProcessInfo.processInfo.environment["CLAWDIO_HALOSTEP"] ?? "") ?? 170
            Trace.record(window: panel, duration: d, label: "halo", dumpEveryMs: step)
        }
        if Trace.enabled {
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(900))
                guard let self, let view = self.panel.contentView else { return }
                let text = """
                window.frame      = \(self.panel.frame)
                contentLayoutRect = \(self.panel.contentLayoutRect)
                contentView.frame = \(view.frame)
                contentView.bounds= \(view.bounds)
                safeAreaInsets    = \(view.safeAreaInsets)
                additionalSafe    = \(view.additionalSafeAreaInsets)
                fittingSize       = \(view.fittingSize)
                intrinsic         = \(view.intrinsicContentSize)
                screen.frame      = \(String(describing: self.panel.screen?.frame))
                """
                try? text.write(toFile: "/tmp/clawdio_view.log", atomically: true, encoding: .utf8)
                if let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(self.panel.windowNumber), [.boundsIgnoreFraming]) {
                    try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "/tmp/clawdio_rest.png"))
                }
            }
        }

        // Aide au profilage : CLAWDIO_AUTOOPEN=1 ouvre le popup 1,5 s après le lancement.
        if ProcessInfo.processInfo.environment["CLAWDIO_AUTOOPEN"] != nil {
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(1500))
                if Trace.enabled, let self {
                    // Cas réel : le popup est préchauffé pendant le survol qui précède le clic.
                    if ProcessInfo.processInfo.environment["CLAWDIO_TRACE"] != "cold" {
                        self.state.setWarm(true)
                        try? await Task.sleep(for: .milliseconds(500))
                    }
                    let long = ProcessInfo.processInfo.environment["CLAWDIO_TRACE"] == "esc"
                    Trace.record(window: self.panel, duration: long ? 5.0 : 1.2, label: "ouverture")
                }
                self?.state.setExpanded(true)
            }
        }

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenChanged() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                await self?.usage.refresh()
                await self?.local.refresh()
            }
        }
    }

    // MARK: Souris

    /// Les tracking areas ne sont pas fiables sur un panel non-activant : on écoute la souris
    /// directement. `.mouseMoved` global ne demande aucune permission (contrairement au clavier).
    private func startMouseMonitoring() {
        let onMove: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateHover()
                self?.updateChartHover()
            }
        }
        let onClick: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.clickedElsewhere() }
        }
        mouseMonitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: onMove) as Any)
        mouseMonitors.append(NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
            onMove(event)
            return event
        } as Any)
        // Global = clics dans *d'autres* fenêtres/apps : exactement le "clic à l'extérieur".
        mouseMonitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: onClick) as Any)
    }

    private func clickedElsewhere() {
        guard state.isExpanded else { return }
        let geometry = state.geometry
        let rect = geometry.frame(for: geometry.expandedSize(rows: usage.rowCount))
        if !rect.contains(NSEvent.mouseLocation) { state.setExpanded(false) }
    }

    private func updateHover() {
        // Popup ouvert : la fenêtre capte tout (clics dans le popup) ; la fermeture au clic extérieur est gérée à part.
        guard !state.isExpanded else {
            panel.ignoresMouseEvents = false
            return
        }
        // Hystérésis : on entre par la zone du notch, on sort par la zone (plus grande) grossie.
        let geometry = state.geometry
        let size = state.isHovering ? geometry.hoveredSize : geometry.collapsedSize
        let inside = geometry.frame(for: size).contains(NSEvent.mouseLocation)
        // La fenêtre est immense et transparente : elle ne doit intercepter les clics que sur la pastille elle-même.
        panel.ignoresMouseEvents = !inside
        hoverChanged(inside)
    }

    private func hoverChanged(_ inside: Bool) {
        guard inside != hoverTarget else { return }
        hoverTarget = inside
        hoverTask?.cancel()
        if inside {
            // Réaction immédiate à l'entrée : c'est ce qui rend le hover "vivant".
            state.setHovering(true)
            // Préconstruit le popup (invisible) pendant que la main va vers le clic. Léger délai : la
            // construction bloque le thread principal ~100 ms, autant ne pas la faire au premier pixel.
            warmTask?.cancel()
            warmTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(60))
                guard !Task.isCancelled else { return }
                self?.state.setWarm(true)
            }
            return
        }
        // Un peu de tolérance à la sortie pour ne pas clignoter quand la souris frôle le bord.
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(110))
            guard !Task.isCancelled, let self, !self.state.isExpanded else { return }
            self.state.setHovering(false)
        }
        scheduleUnwarm()
    }

    // MARK: Survol du graphique

    /// Barre survolée, calculée à chaque mouvement de souris (moniteur global déjà en place : aucun timer,
    /// donc aucun réveil quand la souris ne bouge pas). Le popup est centré en haut de la fenêtre et ses
    /// dimensions sont connues : pas besoin de mesurer la vue SwiftUI.
    private func updateChartHover() {
        guard state.isExpanded, state.page == .stats, let count = local.stats?.dayTotals.count, count > 0 else {
            state.setHoveredDay(nil)
            return
        }
        let frame = panel.frame
        let mouse = NSEvent.mouseLocation
        let left = frame.midX - NotchGeometry.expandedWidth / 2 + ExpandedLayout.horizontalPadding
        let width = NotchGeometry.expandedWidth - 2 * ExpandedLayout.horizontalPadding
        let top = frame.maxY - ExpandedLayout.chartTop(notchHeight: state.geometry.notchSize.height)
        let rect = CGRect(x: left, y: top - ExpandedLayout.chartHeight, width: width, height: ExpandedLayout.chartHeight)
        guard rect.contains(mouse) else {
            state.setHoveredDay(nil)
            return
        }
        state.setHoveredDay(min(max(Int((mouse.x - rect.minX) / rect.width * CGFloat(count)), 0), count - 1))
    }

    // MARK: Ouverture / fermeture

    /// Défait la préconstruction si la souris est partie et que le popup n'est pas ouvert.
    private func scheduleUnwarm() {
        warmTask?.cancel()
        warmTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, let self, !self.state.isExpanded, !self.state.isHovering else { return }
            self.state.setWarm(false)
        }
    }

    private func prepareForExpansion() async {
        shrinkTask?.cancel()
        hoverTask?.cancel()
        warmTask?.cancel()
        hoverTarget = false
        panel.ignoresMouseEvents = false
        // Clic sans survol préalable (rare) : on construit d'abord le popup, invisible, avant de lancer l'animation,
        // pour qu'elle ne démarre pas pendant la construction (~100-150 ms). Préchauffé : démarrage immédiat.
        let wasWarm = state.isWarm
        state.setWarm(true)
        if !wasWarm { try? await Task.sleep(for: .milliseconds(140)) }
    }

    private func expandedChanged() {
        shrinkTask?.cancel()
        hoverTask?.cancel()
        hoverTarget = false
        if state.isExpanded {
            escape.register() // Échap ferme le popup
            panel.ignoresMouseEvents = false
            applyFrame() // ne fait quelque chose que si le nombre de lignes du quota a changé
            local.interval = .seconds(20)
            // Chiffres frais dès l'ouverture (puis mises à jour régulières en arrière-plan).
            Task { await usage.refresh() }
            Task { await local.refresh() }
            Task { await sessions.poll() }
        } else {
            escape.unregister() // Échap redevient normal pour les autres apps
            local.interval = .seconds(60)
            state.setHoveredDay(nil)
            scheduleUnwarm()
            // La fenêtre ne bouge plus : on attend seulement la fin de l'animation pour la rendre de nouveau traversante.
            shrinkTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(340)) // la fermeture rapide dure ~0,25 s
                guard !Task.isCancelled, let self else { return }
                self.updateHover()
            }
        }
    }

    // MARK: Frame

    /// Taille fixe = popup + petite marge (dépassement du ressort, « pop » de fermeture). Ne change que si le nombre
    /// de lignes du quota change (rare) ou si l'écran change : jamais pendant une ouverture.
    private func applyFrame() {
        let geometry = state.geometry
        let target = geometry.frame(for: geometry.expandedPanelSize(rows: usage.rowCount))
        if panel.frame != target { panel.setFrame(target, display: true) }
    }

    private func screenChanged() {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        var geometry = NotchGeometry(screen: screen)
        geometry.hoverGrow = settings.hoverStyle.grow
        state.geometry = geometry
        applyFrame()
    }
}
