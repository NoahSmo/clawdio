import AppKit
import Foundation
import Observation

/// Sons système utilisés pour les notifications d'agent.
enum AgentSound {
    case reply      // l'agent a répondu, il attend ton message
    case approval   // il a besoin d'une autorisation / d'une réponse

    func play() {
        let name = self == .reply ? "Glass" : "Funk"
        (NSSound(named: NSSound.Name(name)) ?? NSSound(named: NSSound.Name("Ping")))?.play()
    }
}

/// État des agents Claude Code (sessions récentes) + notifications sonores sur les transitions.
@MainActor @Observable
final class SessionStore {
    private(set) var sessions: [AgentSession] = []
    private(set) var thread: [ChatMessage] = []
    private(set) var soundEnabled: Bool

    /// Debug : force l'état affiché dans le notch (captures `--snapshot`).
    var forcedHeadline: AgentState?
    /// Debug : force l'outil affiché par l'avatar (captures `--snapshot`).
    var forcedTool: String?

    /// Dernier outil vu par session pendant le tour en cours. Le scan passe toutes les 2 s : un Read ou un Edit
    /// (quelques ms) serait presque toujours manqué, et l'avatar clignoterait entre « réfléchit » et l'activité.
    /// On garde donc le dernier outil jusqu'à la fin du tour (session qui quitte l'état « travaille »).
    private var lastTool: [String: String] = [:]

    @ObservationIgnored private let scanner = SessionScanner()
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var hasScanned = false
    @ObservationIgnored private var lastSound = Date.distantPast

    init() {
        soundEnabled = UserDefaults.standard.object(forKey: "clawdio.soundEnabled") as? Bool ?? true
    }

    /// Sessions actives récemment : seules elles influencent le notch.
    private var recent: [AgentSession] {
        sessions.filter { Date.now.timeIntervalSince($0.lastActivity) < 30 * 60 }
    }

    /// Ce que le notch doit signaler : le besoin le plus urgent parmi les sessions récentes.
    var headline: AgentState {
        forcedHeadline ?? recent.map(\.state).max() ?? .idle
    }

    var headlineSession: AgentSession? {
        let top = headline
        return recent.filter { $0.state == top }.max { $0.lastActivity < $1.lastActivity }
    }

    /// Outil à mettre en scène : celui de la session prioritaire, seulement quand elle travaille.
    var headlineTool: String? {
        if let forcedTool { return forcedTool }
        guard headline == .working, let session = headlineSession else { return nil }
        return session.pendingTool ?? lastTool[session.id]
    }

    var attentionCount: Int {
        sessions.filter { $0.state >= .waitingReply }.count
    }

    func setSoundEnabled(_ enabled: Bool) {
        soundEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "clawdio.soundEnabled")
        if enabled { AgentSound.reply.play() } // aperçu
    }

#if DEBUG
    /// Données d'exemple pour les captures du README (voir `DemoData`). Debug uniquement.
    func setDemo(_ sessions: [AgentSession], thread: [ChatMessage]) {
        self.sessions = sessions
        self.thread = thread
        hasScanned = true
    }
#endif

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                // Réactif (2 s) tant qu'une session bouge, sinon on lève le pied : le son doit partir
                // vite quand un agent finit, mais inutile de scruter le disque toutes les 1,5 s à vide.
                let busy = self?.sessions.contains { Date.now.timeIntervalSince($0.lastActivity) < 180 } ?? false
                try? await Task.sleep(for: busy ? .seconds(2) : .seconds(6))
            }
        }
    }

    func poll() async {
        let fresh = await scanner.scan()
        notifyOnTransitions(to: fresh)
        rememberTools(fresh)
        if Self.differsMeaningfully(fresh, sessions) { sessions = fresh }
    }

    /// `lastActivity` bouge à chaque écriture du transcript (toutes les 1,5 s pendant une réponse) : republier
    /// à chaque fois redessinerait le popup en boucle. On ne republie que sur un vrai changement.
    private static func differsMeaningfully(_ a: [AgentSession], _ b: [AgentSession]) -> Bool {
        guard a.count == b.count else { return true }
        for (x, y) in zip(a, b) {
            if x.id != y.id || x.state != y.state || x.title != y.title || x.snippet != y.snippet
                || x.pendingTool != y.pendingTool || abs(x.lastActivity.timeIntervalSince(y.lastActivity)) > 30 { return true }
        }
        return false
    }

    private func rememberTools(_ fresh: [AgentSession]) {
        var next: [String: String] = [:]
        for session in fresh where session.state == .working {
            if let tool = session.pendingTool ?? lastTool[session.id] { next[session.id] = tool }
        }
        if next != lastTool { lastTool = next }
    }

    func loadThread(sessionID: String) async {
        guard let session = sessions.first(where: { $0.id == sessionID }) else { return }
        let messages = await scanner.thread(for: session.url)
        if messages != thread { thread = messages }
    }

    func clearThread() { thread = [] }

    // MARK: Sons

    /// Son uniquement quand une session *passe* de "travaille" à "attend quelque chose".
    /// Le premier scan (lancement de l'app) et les sessions nouvellement vues sont silencieux.
    private func notifyOnTransitions(to fresh: [AgentSession]) {
        defer { hasScanned = true }
        guard hasScanned, soundEnabled else { return }
        let previous = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.state) })

        var sound: AgentSound?
        for session in fresh {
            guard let before = previous[session.id], before != session.state else { continue }
            switch (before, session.state) {
            case (.working, .needsApproval), (.waitingReply, .needsApproval): sound = .approval
            case (.working, .waitingReply): sound = sound ?? .reply
            default: break
            }
        }
        if let sound, Date.now.timeIntervalSince(lastSound) > 1 {
            lastSound = .now
            sound.play()
        }
    }
}
