/// Ce que l'avatar fait pendant que l'agent travaille, selon l'outil en cours (voir `SessionStore.headlineTool`).
/// Chaque activité a sa pose de repos (visible même immobile) et son clip (voir `AvatarSprites.activity`).
enum AvatarActivity: Hashable, CaseIterable {
    case think      // aucun outil (il réfléchit / écrit sa réponse), ou outil sans mise en scène dédiée
    case read       // lit un livre tenu devant lui : parcourt des fichiers
    case write      // tape sur un laptop (dos du capot vers nous) : modifie des fichiers
    case run        // tape dans une fenêtre Terminal : lance des commandes
    case web        // fait tourner un globe : cherche sur le web
    case delegate   // invoque des mini-Clawd : sous-agents

    /// Noms d'outils tels qu'ils apparaissent dans les transcripts (`tool_use.name`) : "Read", "Grep", "Glob",
    /// "Edit", "MultiEdit", "Write", "NotebookEdit", "Bash", "BashOutput", "KillShell", "WebFetch", "WebSearch",
    /// "Task", "Agent", "TodoWrite", "Skill", "ToolSearch", et les outils MCP préfixés "mcp__<serveur>__<outil>".
    init(tool: String?) {
        switch tool {
        case "Read", "Grep", "Glob", "LS", "NotebookRead":
            self = .read
        case "Edit", "MultiEdit", "Write", "NotebookEdit":
            self = .write
        case "Bash", "BashOutput", "KillShell", "KillBash":
            self = .run
        case "WebFetch", "WebSearch":
            self = .web
        case "Task", "Agent":
            self = .delegate
        case let mcp? where mcp.hasPrefix("mcp__"):
            // MCP : seuls les outils qui naviguent ou cherchent sur le web ont une mise en scène évidente.
            let name = mcp.lowercased()
            let webby = ["browser", "playwright", "chrome", "puppeteer", "fetch", "search", "web"]
            self = webby.contains(where: name.contains) ? .web : .think
        default:
            // Aucun outil (il rédige sa réponse), TodoWrite, Skill, outil inconnu… : il réfléchit.
            self = .think
        }
    }
}
