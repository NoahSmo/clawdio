import AppKit

/// Les trois états visuels de la pastille.
enum NotchMode: Equatable {
    case collapsed   // au repos : colle au notch
    case hovered     // survol : grossit un peu
    case expanded    // clic : panneau de détails
}

/// Dimensions du notch physique + tailles des états de la pastille.
struct NotchGeometry {
    let screen: NSScreen
    let notchSize: CGSize
    let hasHardwareNotch: Bool
    /// Grossissement de la pastille au survol (largeur totale, hauteur), selon le réglage. `.zero` = elle ne bouge pas.
    var hoverGrow = CGSize.zero

    /// Petites "ailes" à gauche/droite du notch (donut + heure de reset en mode replié).
    static let wingWidth: CGFloat = 78
    /// Plus grand grossissement possible au survol (réglage « Bouncy ») : sert à dimensionner la fenêtre au repos.
    static let maxHoverGrow = CGSize(width: 30, height: 4)
    static let expandedWidth: CGFloat = 500

    init(screen: NSScreen) {
        self.screen = screen
        let topInset = screen.safeAreaInsets.top
        // Clé par résolution : un Mac à notch garde la même encoche tant que l'écran ne change pas.
        let cacheKey = "clawdio.notchSize.\(Int(screen.frame.width))x\(Int(screen.frame.height))"

        if topInset > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            hasHardwareNotch = true
            notchSize = CGSize(width: screen.frame.width - left.width - right.width, height: topInset)
            UserDefaults.standard.set([notchSize.width, notchSize.height], forKey: cacheKey)
        } else if let cached = UserDefaults.standard.array(forKey: cacheKey) as? [Double], cached.count == 2 {
            // L'écran ne déclare pas son notch pour l'instant (Space plein écran, barre de menus masquée qui se
            // révèle au survol du haut de l'écran, transition de démarrage…) alors qu'on l'a déjà mesuré.
            // Sans ça la pastille basculait sur un notch simulé : autre taille, autre position → "le notch bouge".
            hasHardwareNotch = true
            notchSize = CGSize(width: cached[0], height: cached[1])
        } else {
            // Mac sans notch : on simule une pastille collée à la barre de menus.
            hasHardwareNotch = false
            let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
            notchSize = CGSize(width: 180, height: max(menuBar, 24))
        }
    }

    /// L'écran avec notch s'il y en a un, sinon l'écran principal.
    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    var collapsedSize: CGSize {
        CGSize(width: notchSize.width + 2 * Self.wingWidth, height: notchSize.height)
    }

    var hoveredSize: CGSize {
        CGSize(width: collapsedSize.width + hoverGrow.width, height: collapsedSize.height + hoverGrow.height)
    }

    func expandedSize(rows: Int) -> CGSize {
        CGSize(width: Self.expandedWidth, height: ExpandedLayout.height(notchHeight: notchSize.height, rows: rows))
    }

    /// Fenêtre du popup : petite marge permanente pour le dépassement du ressort (~2 %) et le « pop » de fermeture (+4 %).
    /// Permanente : la retirer après coup faisait re-dimensionner la fenêtre (à-coup visible avec le verre liquide).
    func expandedPanelSize(rows: Int) -> CGSize {
        let size = expandedSize(rows: rows)
        return CGSize(width: size.width + 28, height: size.height + 24)
    }

    func size(for mode: NotchMode, rows: Int) -> CGSize {
        switch mode {
        case .collapsed: collapsedSize
        case .hovered: hoveredSize
        case .expanded: expandedSize(rows: rows)
        }
    }

    /// Frame écran (origine bas-gauche) d'une pastille de `size`, collée en haut au centre.
    func frame(for size: CGSize) -> CGRect {
        CGRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}

/// Constantes de mise en page partagées entre la vue SwiftUI et le calcul de hauteur du panel.
/// Chaque bloc a une hauteur fixe → la hauteur totale est déterministe (pas de mesure SwiftUI).
enum ExpandedLayout {
    static let topGap: CGFloat = 4
    static let heroHeight: CGFloat = 82
    static let statsRowHeight: CGFloat = 38
    static let chartHeight: CGFloat = 92
    static let noteHeight: CGFloat = 14
    static let rowHeight: CGFloat = 30
    static let footerHeight: CGFloat = 18
    static let spacing: CGFloat = 10
    static let bottomPadding: CGFloat = 26
    /// Le haut du panneau a des coins concaves (~22 pt) : on prend une marge nettement plus large.
    static let horizontalPadding: CGFloat = 44

    /// Haut du graphique, mesuré depuis le haut du popup.
    static func chartTop(notchHeight: CGFloat) -> CGFloat {
        notchHeight + topGap + heroHeight + spacing + statsRowHeight + spacing
    }

    /// Zone sous le hero : stats + graphique + jauges (l'historique occupe exactement la même).
    static func pageHeight(rows: Int) -> CGFloat {
        statsRowHeight + spacing + chartHeight + 4 + noteHeight + CGFloat(rows) * (spacing + rowHeight)
    }

    static func height(notchHeight: CGFloat, rows: Int) -> CGFloat {
        notchHeight + topGap + heroHeight
            + spacing + pageHeight(rows: rows)
            + spacing + footerHeight
            + bottomPadding
    }
}
