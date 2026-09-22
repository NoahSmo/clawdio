/// Ce que l'avatar "ressent", déduit de l'état des agents. Pilote son répertoire d'animations.
enum AvatarMood: Hashable {
    case idle                       // rien à signaler
    case working(AvatarActivity)    // l'agent travaille, avec tel outil
    case waiting                    // l'agent a répondu, il attend ta réponse
    case attention                  // besoin d'une autorisation
    case pushing                    // naissance de la pastille : il pousse les bords (voir `birthSequence`)

    init(_ state: AgentState, tool: String? = nil) {
        switch state {
        case .idle: self = .idle
        case .working: self = .working(AvatarActivity(tool: tool))
        case .waitingReply: self = .waiting
        case .needsApproval: self = .attention
        }
    }

    /// Toutes les humeurs, chaque activité comprise (planche contact, page de visualisation).
    static let gallery: [AvatarMood] = [.idle] + AvatarActivity.allCases.map { .working($0) } + [.waiting, .attention, .pushing]

    /// Nom court, pour les planches de debug.
    var label: String {
        switch self {
        case .working(let activity): "working.\(activity)"
        default: "\(self)"
        }
    }
}
