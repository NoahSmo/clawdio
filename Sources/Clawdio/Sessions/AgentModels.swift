import Foundation

/// Ce dont un agent a "besoin" de toi. L'ordre sert de priorité : le plus haut gagne dans le notch.
enum AgentState: Int, Comparable {
    case idle            // rien à signaler
    case working         // l'agent réfléchit / exécute des outils
    case waitingReply    // l'agent a répondu, il attend ton message
    case needsApproval   // autorisation d'outil, question ou plan à valider

    static func < (a: AgentState, b: AgentState) -> Bool { a.rawValue < b.rawValue }
}

struct AgentSession: Identifiable, Equatable {
    let id: String              // = nom du fichier transcript (sessionId)
    let url: URL
    var title: String
    var project: String
    var lastActivity: Date
    var state: AgentState
    var pendingTool: String?
    var snippet: String         // dernier message de l'agent, une ligne
}

struct ChatMessage: Identifiable, Equatable {
    let id: Int
    let isUser: Bool
    let text: String
}
