import CoreGraphics
import Observation

/// Page affichée dans le panneau ouvert.
enum PopupPage: Hashable {
    case stats
    case history
    case thread(String)   // id de la session
    case settings
}

enum ChartMetric: String, CaseIterable {
    case cost = "Coût"
    case tokens = "Tokens"
}

/// État purement visuel de la pastille (repos / survol / ouvert + géométrie de l'écran).
@MainActor @Observable
final class NotchState {
    var geometry: NotchGeometry
    var page: PopupPage = .stats
    var metric: ChartMetric = .cost
    /// Index du jour survolé dans le graphique (nil = aucun). Calculé par le controller, publié uniquement
    /// quand il CHANGE : la vue ne se redessine donc qu'aux changements de barre, pas à chaque pixel.
    private(set) var hoveredDay: Int?
    private(set) var isHovering = false
    private(set) var isExpanded = false
    /// Le popup est déjà construit (invisible) : au clic, il ne reste que des changements de taille et d'opacité.
    /// Sans ça SwiftUI construit graphique + verre + hero pendant ~100-150 ms AU MOMENT du clic, l'horloge de
    /// l'animation tourne pendant ce blocage, et la première image affichée est déjà quasi finale (le popup
    /// "sort de rien"). Mesuré : la croissance démarrait ~150-200 ms après le clic, avec un saut initial à ~30 %.
    private(set) var isWarm = false

    /// Appelé quand la pastille s'ouvre ou se ferme → le controller redimensionne la fenêtre.
    @ObservationIgnored var onExpandedChange: (() -> Void)?
    /// Avant d'ouvrir : le controller agrandit la fenêtre et laisse SwiftUI recentrer la pastille,
    /// pour que l'animation ne démarre pas dans le coin supérieur gauche de la nouvelle fenêtre.
    @ObservationIgnored var prepareExpand: (() async -> Void)?
    @ObservationIgnored private var isPreparing = false
    @ObservationIgnored private var isClosing = false

    /// Bref gonflement (~1,5 %) juste avant de se refermer : la fermeture ne "tombe" pas d'un coup.
    /// Mesuré sur l'app de référence : +5 % de largeur à la première image, puis effondrement en ~150 ms.
    private(set) var isPopping = false

    var mode: NotchMode { isExpanded ? .expanded : (isHovering ? .hovered : .collapsed) }

    init(geometry: NotchGeometry) {
        self.geometry = geometry
    }

    func setWarm(_ warm: Bool) {
        if warm != isWarm { isWarm = warm }
    }

    func setHoveredDay(_ index: Int?) {
        if index != hoveredDay { hoveredDay = index }
    }

    func setHovering(_ hovering: Bool) {
        guard hovering != isHovering else { return }
        isHovering = hovering
    }

    func setExpanded(_ expanded: Bool) {
        guard expanded != isExpanded else { return }
        if expanded, let prepare = prepareExpand {
            guard !isPreparing else { return }
            isPreparing = true
            Task {
                await prepare()
                isPreparing = false
                commit(true)
            }
            return
        }
        if !expanded, isExpanded {
            guard !isClosing else { return }
            isClosing = true
            Task {
                isPopping = true
                try? await Task.sleep(for: .milliseconds(90))
                isPopping = false
                commit(false)
                isClosing = false
            }
            return
        }
        commit(expanded)
    }

    private func commit(_ expanded: Bool) {
        guard expanded != isExpanded else { return }
        isExpanded = expanded
        if expanded { isHovering = false } else { page = .stats }
        onExpandedChange?()
    }
}
