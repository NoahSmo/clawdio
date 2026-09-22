import SwiftUI

/// Gravité d'un quota, utilisée pour colorer les pourcentages et les barres.
///
/// ★ À TOI DE JOUER — les seuils ci-dessous sont un défaut raisonnable, mais ils
/// changent ce que tu ressens en un coup d'œil. Ajuste `init(percent:)` :
///  - Session 5 h : se remplit vite, se vide vite → tolérer plus haut avant d'alerter ?
///  - Semaine 7 j : cramée = bloqué plusieurs jours → alerter plus tôt ?
/// Tu peux aussi passer un `UsageRow.id` si tu veux des seuils différents par fenêtre.
enum UsageLevel {
    case calm, warning, critical

    init(percent: Double) {
        switch percent {
        case ..<70: self = .calm
        case ..<90: self = .warning
        default: self = .critical
        }
    }

    var color: Color {
        switch self {
        case .calm: Color(red: 0.38, green: 0.82, blue: 0.56)
        case .warning: Color(red: 0.98, green: 0.72, blue: 0.25)
        case .critical: Color(red: 0.98, green: 0.36, blue: 0.34)
        }
    }
}
