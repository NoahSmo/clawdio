import Foundation

/// Lit les transcripts de Claude Code pour en déduire l'état de chaque session et son historique.
///
/// Aucune configuration côté Claude Code : tout est inféré de la fin du fichier JSONL.
/// - dernier message assistant avec `stop_reason: end_turn` → l'agent a fini, il attend ta réponse
/// - dernier message = `tool_use` sans résultat → outil en cours… ou autorisation demandée
///   (heuristique : outil soumis à permission + fichier immobile depuis > 15 s + mode ≠ auto/bypass)
/// - dernier message utilisateur / tool_result / assistant en cours de stream → l'agent travaille
actor SessionScanner {
    // MARK: Types internes

    private enum LastKind {
        case none, interrupted, userPrompt, toolResult
        case assistantStreaming, assistantDone
        case toolPending(String)
    }

    private struct Summary {
        var kind: LastKind = .none
        var title: String?
        var project: String?
        var mode: String?
        var snippet = ""
    }

    private struct Cached {
        let modified: Date
        let size: Int
        let summary: Summary
    }

    private struct Entry: Decodable {
        struct Block: Decodable {
            let type: String?
            let name: String?
            let text: String?
        }

        struct Message: Decodable {
            let role: String?
            let stopReason: String?
            let plainText: String?
            let blocks: [Block]

            enum CodingKeys: String, CodingKey {
                case role, content
                case stopReason = "stop_reason"
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                role = try? c.decodeIfPresent(String.self, forKey: .role)
                stopReason = try? c.decodeIfPresent(String.self, forKey: .stopReason)
                if let text = try? c.decode(String.self, forKey: .content) {
                    plainText = text
                    blocks = []
                } else {
                    plainText = nil
                    blocks = (try? c.decode([Block].self, forKey: .content)) ?? []
                }
            }

            var text: String {
                plainText ?? blocks.compactMap { $0.type == "text" ? $0.text : nil }.joined(separator: "\n\n")
            }
            var hasToolResult: Bool { blocks.contains { $0.type == "tool_result" } }
        }

        let type: String?
        let isSidechain: Bool?
        let isMeta: Bool?
        let cwd: String?
        let aiTitle: String?
        let permissionMode: String?
        let message: Message?

        enum CodingKeys: String, CodingKey {
            case type, isSidechain, isMeta, cwd, aiTitle, permissionMode, message
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type = try? c.decodeIfPresent(String.self, forKey: .type)
            isSidechain = try? c.decodeIfPresent(Bool.self, forKey: .isSidechain)
            isMeta = try? c.decodeIfPresent(Bool.self, forKey: .isMeta)
            cwd = try? c.decodeIfPresent(String.self, forKey: .cwd)
            aiTitle = try? c.decodeIfPresent(String.self, forKey: .aiTitle)
            permissionMode = try? c.decodeIfPresent(String.self, forKey: .permissionMode)
            message = try? c.decodeIfPresent(Message.self, forKey: .message)
        }

        var isConversation: Bool {
            (type == "user" || type == "assistant") && isSidechain != true && isMeta != true
        }
    }

    // MARK: État

    private var cache: [URL: Cached] = [:]
    private var headTitles: [URL: String] = [:]
    private let decoder = JSONDecoder()
    private let roots = ClaudePaths.projectRoots

    private static let toolResultMarker = Data("\"tool_result\"".utf8)
    private static let permissionGated: Set<String> = ["Bash", "Edit", "Write", "MultiEdit", "NotebookEdit", "WebFetch"]
    private static let editTools: Set<String> = ["Edit", "Write", "MultiEdit", "NotebookEdit"]
    private static let alwaysAsk: Set<String> = ["AskUserQuestion", "ExitPlanMode"]

    // MARK: Scan

    func scan(now: Date = .now, limit: Int = 12) -> [AgentSession] {
        let cutoff = now.addingTimeInterval(-7 * 86400)
        var files: [(url: URL, modified: Date, size: Int)] = []

        let fm = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        for root in roots {
            guard let projects = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { continue }
            for project in projects {
                // Uniquement projects/<projet>/<session>.jsonl (les sous-agents vivent plus bas).
                guard let items = try? fm.contentsOfDirectory(at: project, includingPropertiesForKeys: keys, options: .skipsHiddenFiles) else { continue }
                for url in items where url.pathExtension == "jsonl" {
                    guard let v = try? url.resourceValues(forKeys: Set(keys)), let modified = v.contentModificationDate, modified >= cutoff else { continue }
                    files.append((url, modified, v.fileSize ?? 0))
                }
            }
        }
        files.sort { $0.modified > $1.modified }

        var sessions: [AgentSession] = []
        for file in files.prefix(limit) {
            var summary: Summary
            if let hit = cache[file.url], hit.modified == file.modified, hit.size == file.size {
                summary = hit.summary
            } else {
                summary = summarize(file.url)
                cache[file.url] = Cached(modified: file.modified, size: file.size, summary: summary)
            }

            let title = summary.title ?? firstPrompt(of: file.url) ?? "" // vide → la vue affiche "Conversation" localisé
            let project = summary.project ?? Self.projectName(fromDirectory: file.url.deletingLastPathComponent().lastPathComponent)
            var pending: String?
            if case .toolPending(let name) = summary.kind { pending = name }

            sessions.append(AgentSession(
                id: file.url.deletingPathExtension().lastPathComponent,
                url: file.url,
                title: title,
                project: project,
                lastActivity: file.modified,
                state: Self.state(for: summary, modified: file.modified, now: now),
                pendingTool: pending,
                snippet: summary.snippet
            ))
        }

        // Ne garde en cache que ce qui est encore dans le top.
        let live = Set(files.prefix(limit).map(\.url))
        cache = cache.filter { live.contains($0.key) }
        return sessions
    }

    private static func state(for summary: Summary, modified: Date, now: Date) -> AgentState {
        let idleFor = now.timeIntervalSince(modified)
        if idleFor > 30 * 60 { return .idle } // vieux → on ne réclame plus rien

        switch summary.kind {
        case .none, .interrupted:
            return .idle
        case .assistantDone:
            return .waitingReply
        case .assistantStreaming, .userPrompt, .toolResult:
            return idleFor > 120 ? .idle : .working // rien n'a bougé depuis 2 min : session abandonnée
        case .toolPending(let name):
            if alwaysAsk.contains(name) { return .needsApproval }
            let gated = permissionGated.contains(name) || name.hasPrefix("mcp__")
            let autoMode = summary.mode == "bypassPermissions" || summary.mode == "auto"
            let editsAutoApproved = summary.mode == "acceptEdits" && editTools.contains(name)
            if gated, !autoMode, !editsAutoApproved, idleFor > 15 { return .needsApproval }
            return idleFor > 900 ? .idle : .working
        }
    }

    // MARK: Lecture de fichier

    /// Les `bytes` derniers octets, sans la première ligne (probablement coupée).
    private func readTail(_ url: URL, bytes: Int) -> (data: Data, wholeFile: Bool)? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let offset = size > UInt64(bytes) ? size - UInt64(bytes) : 0
        try? handle.seek(toOffset: offset)
        guard var data = try? handle.readToEnd() else { return nil }
        if offset > 0, let newline = data.firstIndex(of: 0x0A) {
            data = Data(data[data.index(after: newline)...])
        }
        return (data, offset == 0)
    }

    private func decode(_ line: Data) -> Entry? {
        try? decoder.decode(Entry.self, from: Data(line))
    }

    private func summarize(_ url: URL) -> Summary {
        var window = 400_000
        var summary = Summary()
        for _ in 0..<3 {
            guard let (data, wholeFile) = readTail(url, bytes: window) else { break }
            summary = Summary()
            var haveKind = false
            var decodedAfterKind = 0

            for line in data.split(separator: 0x0A).reversed() {
                // Gros résultat d'outil (lecture de fichier, sortie de build…) : inutile de le décoder
                // pour savoir que c'est un tool_result, et c'est ce qui coûtait le plus cher.
                if line.count > 60_000, line.range(of: Self.toolResultMarker) != nil {
                    if !haveKind { summary.kind = .toolResult; haveKind = true }
                    continue
                }
                if haveKind {
                    decodedAfterKind += 1
                    if decodedAfterKind > 120 { break } // titre / snippet absents des 120 lignes suivantes : on abandonne
                }
                guard let entry = decode(line) else { continue }
                switch entry.type {
                case "ai-title":
                    if summary.title == nil { summary.title = entry.aiTitle }
                case "permission-mode":
                    if summary.mode == nil { summary.mode = entry.permissionMode }
                case "user", "assistant":
                    guard entry.isConversation else { continue }
                    if summary.project == nil, let cwd = entry.cwd, !cwd.isEmpty {
                        summary.project = URL(fileURLWithPath: cwd).lastPathComponent
                    }
                    if !haveKind {
                        summary.kind = Self.classify(entry)
                        haveKind = true
                    }
                    if summary.snippet.isEmpty, entry.type == "assistant", let text = entry.message?.text, !text.isEmpty {
                        summary.snippet = Self.oneLine(text, limit: 140)
                    }
                default: break
                }
                if haveKind, summary.title != nil, summary.mode != nil, !summary.snippet.isEmpty { break }
            }
            if haveKind || wholeFile { break }
            window *= 4 // fenêtre pleine de tool results géants : on élargit
        }
        return summary
    }

    private static func classify(_ entry: Entry) -> LastKind {
        guard let message = entry.message else { return .none }
        if entry.type == "assistant" {
            let last = message.blocks.last
            if last?.type == "tool_use" { return .toolPending(last?.name ?? "") }
            switch message.stopReason {
            case "end_turn", "stop_sequence", "max_tokens":
                // Bloc "thinking" en dernier : le texte de la réponse arrive juste après.
                return last?.type == "thinking" ? .assistantStreaming : .assistantDone
            default:
                return .assistantStreaming
            }
        }
        if message.hasToolResult { return .toolResult }
        return message.text.hasPrefix("[Request interrupted") ? .interrupted : .userPrompt
    }

    // MARK: Titres / projets

    /// Repli quand aucun `ai-title` : premier vrai prompt de l'utilisateur.
    private func firstPrompt(of url: URL) -> String? {
        if let known = headTitles[url] { return known }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 200_000) else { return nil }
        for line in head.split(separator: 0x0A) {
            guard let entry = decode(line), entry.type == "user", entry.isConversation,
                  let message = entry.message, !message.hasToolResult,
                  let text = Self.realUserText(message.text) else { continue }
            let title = Self.oneLine(text, limit: 60)
            headTitles[url] = title
            return title
        }
        return nil
    }

    /// Filtre les "faux" messages utilisateur injectés par Claude Code (commandes, rappels système).
    private static func realUserText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("<"), !trimmed.hasPrefix("Caveat:"), !trimmed.hasPrefix("[Request interrupted") else { return nil }
        return trimmed
    }

    private static func oneLine(_ text: String, limit: Int) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return flat.count > limit ? String(flat.prefix(limit)) + "…" : flat
    }

    private static func projectName(fromDirectory name: String) -> String {
        name.split(separator: "-").last.map(String.init) ?? name
    }

    // MARK: Historique d'une conversation

    func thread(for url: URL, limit: Int = 14) -> [ChatMessage] {
        guard let (data, _) = readTail(url, bytes: 2_500_000) else { return [] }
        var turns: [(isUser: Bool, text: String)] = []

        for line in data.split(separator: 0x0A) {
            guard let entry = decode(line), entry.isConversation, let message = entry.message else { continue }
            if entry.type == "user" {
                guard !message.hasToolResult, let text = Self.realUserText(message.text) else { continue }
                turns.append((true, text))
            } else {
                let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                // Un tour de l'agent est loggé bloc par bloc : on recolle les blocs consécutifs.
                if let last = turns.last, !last.isUser {
                    turns[turns.count - 1].text += "\n\n" + text
                } else {
                    turns.append((false, text))
                }
            }
        }

        return turns.suffix(limit).enumerated().map { index, turn in
            ChatMessage(id: index, isUser: turn.isUser, text: String(turn.text.prefix(900)))
        }
    }
}
