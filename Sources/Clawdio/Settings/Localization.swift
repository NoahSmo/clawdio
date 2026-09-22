import Foundation
import SwiftUI

/// Langues de l'interface. `.system` suit la langue du Mac (repli : anglais).
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, fr, en, es, de

    var id: String { rawValue }

    /// Langue effective (jamais `.system`).
    var resolved: AppLanguage {
        guard self == .system else { return self }
        for preferred in Locale.preferredLanguages {
            let code = String(preferred.prefix(2))
            if let match = AppLanguage(rawValue: code), match != .system { return match }
        }
        return .en
    }

    var locale: Locale {
        switch resolved {
        case .fr: Locale(identifier: "fr_FR")
        case .es: Locale(identifier: "es_ES")
        case .de: Locale(identifier: "de_DE")
        default: Locale(identifier: "en_US")
        }
    }

    /// Nom dans sa propre langue (info-bulle du sélecteur).
    var nativeName: String {
        switch self {
        case .system: "Auto"
        case .fr: "Français"
        case .en: "English"
        case .es: "Español"
        case .de: "Deutsch"
        }
    }

    /// Code court affiché dans le sélecteur.
    var shortCode: String { self == .system ? "Auto" : rawValue.uppercased() }
}

/// Toutes les chaînes de l'interface. Ajouter une langue = ajouter une table dans `Strings.tables`
/// (une clé manquante retombe sur l'anglais, puis sur le français).
enum L10n: String, CaseIterable {
    // Général
    case quit, history, back, loading, soundHelp
    // Paramètres
    case fontTitle, soundToggle, launchToggle, launchError, language, languageAuto
    case popupStyle, styleGlass, styleBlack
    case hoverStyle, hoverOff, hoverSubtle, hoverBouncy
    case haloToggle
    case fontSystem, fontMono, fontMinecraft
    // Stats
    case today, tokensToday, period30, tokens30, topModel, analyzing, noActivity, partialCost
    case metricCost, metricTokens, tokensWord
    // Quotas
    case quotaSession, quotaWeekly, quotaOpus, quotaSonnet, resetFmt
    case inDaysHours, inHoursMinutes, inMinutes
    // Âge / dates
    case ageNow, ageMinutes, ageHours, ageDays
    // Pied de page
    case updatedFmt, planUpdatedFmt, rateLimitFooter, retrySoon, genericError
    // Erreurs
    case errNoCredentials, errUnreadable, errKeychain, errUnauthorized, errRateLimited
    case errHTTP, errNetwork, errBadResponse, rateLimitedFull
    // Agents
    case statusNone, statusWorking, statusWaiting, statusApprovalTool, statusApprovalAction
    case noConversations, untitled
}

/// Résolveur de chaînes pour une langue donnée. Valeur légère, passée par l'environnement SwiftUI.
struct Strings {
    let language: AppLanguage
    var locale: Locale { language.locale }

    init(_ language: AppLanguage) { self.language = language.resolved }

    /// `t(.key)` ou `t(.key, arg1, arg2)` : `%@`, `%d`, `%02d` dans les modèles.
    func callAsFunction(_ key: L10n, _ args: CVarArg...) -> String {
        let template = Self.tables[language]?[key] ?? Self.tables[.en]?[key] ?? Self.tables[.fr]?[key] ?? key.rawValue
        return args.isEmpty ? template : String(format: template, locale: locale, arguments: args)
    }

    func quotaTitle(id: String, fallback: String) -> String {
        switch id {
        case "session": self(.quotaSession)
        case "weekly": self(.quotaWeekly)
        case "opus": self(.quotaOpus)
        case "sonnet": self(.quotaSonnet)
        default: fallback
        }
    }

    /// Heure courte dans la langue choisie ("20:00" / "8:00 PM").
    func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(locale))
    }

    // MARK: Tables

    private static let tables: [AppLanguage: [L10n: String]] = [.fr: fr, .en: en, .es: es, .de: de]

    private static let fr: [L10n: String] = [
        .haloToggle: "Halo autour du notch",
        .hoverStyle: "Survol du notch", .hoverOff: "Fixe", .hoverSubtle: "Léger", .hoverBouncy: "Bouncy",
        .popupStyle: "Fond du popup", .styleGlass: "Verre", .styleBlack: "Noir",
        .quit: "Quitter", .history: "Historique", .back: "Retour", .loading: "Chargement…",
        .soundHelp: "Son des notifications d'agent",
        .fontTitle: "Police de l'heure", .soundToggle: "Son des notifications d'agent",
        .launchToggle: "Lancer Clawdio au démarrage", .launchError: "Impossible de modifier le démarrage auto",
        .language: "Langue", .languageAuto: "Auto",
        .fontSystem: "Système", .fontMono: "Mono", .fontMinecraft: "Minecraft",
        .today: "Aujourd'hui", .tokensToday: "Tokens auj.", .period30: "30 jours", .tokens30: "Tokens 30 j",
        .topModel: "Top modèle", .analyzing: "Analyse des logs…", .noActivity: "Aucune activité sur 30 jours",
        .partialCost: "Certains modèles sans tarif — coût partiel",
        .metricCost: "Coût", .metricTokens: "Tokens", .tokensWord: "tokens",
        .quotaSession: "Session", .quotaWeekly: "Semaine", .quotaOpus: "Opus", .quotaSonnet: "Sonnet",
        .resetFmt: "reset %@",
        .inDaysHours: "dans %d j %d h", .inHoursMinutes: "dans %d h %02d", .inMinutes: "dans %d min",
        .ageNow: "à l'instant", .ageMinutes: "il y a %d min", .ageHours: "il y a %d h %02d", .ageDays: "il y a %d j",
        .updatedFmt: "mis à jour %@", .planUpdatedFmt: "%@ · mis à jour %@",
        .rateLimitFooter: "dernières valeurs : %@ · l'API d'usage limite les requêtes, réessai %@",
        .retrySoon: "bientôt", .genericError: "Erreur",
        .errNoCredentials: "Claude Code introuvable — connecte-toi avec `claude`",
        .errUnreadable: "Credentials Claude Code illisibles", .errKeychain: "Accès au Trousseau refusé",
        .errUnauthorized: "Token expiré — lance Claude Code pour le renouveler",
        .errRateLimited: "L'API d'usage limite les requêtes", .errHTTP: "Erreur HTTP %d", .errNetwork: "Réseau : %@",
        .errBadResponse: "réponse inattendue",
        .rateLimitedFull: "L'API d'usage limite les requêtes (ta limite Claude n'est pas atteinte). Nouvel essai à %@.",
        .statusNone: "Aucun agent en attente", .statusWorking: "Claude travaille… %@",
        .statusWaiting: "%@ · attend ta réponse", .statusApprovalTool: "%@ · autorisation requise",
        .statusApprovalAction: "%@ · action requise",
        .noConversations: "Aucune conversation Claude Code récente", .untitled: "Conversation",
    ]

    private static let en: [L10n: String] = [
        .haloToggle: "Notch glow",
        .hoverStyle: "Notch hover", .hoverOff: "Still", .hoverSubtle: "Subtle", .hoverBouncy: "Bouncy",
        .popupStyle: "Popup background", .styleGlass: "Glass", .styleBlack: "Black",
        .quit: "Quit", .history: "History", .back: "Back", .loading: "Loading…",
        .soundHelp: "Agent notification sound",
        .fontTitle: "Time font", .soundToggle: "Agent notification sound",
        .launchToggle: "Launch Clawdio at login", .launchError: "Couldn't change launch at login",
        .language: "Language", .languageAuto: "Auto",
        .fontSystem: "System", .fontMono: "Mono", .fontMinecraft: "Minecraft",
        .today: "Today", .tokensToday: "Tokens today", .period30: "30 days", .tokens30: "Tokens 30 d",
        .topModel: "Top model", .analyzing: "Analyzing logs…", .noActivity: "No activity in 30 days",
        .partialCost: "Some models lack pricing — cost is partial",
        .metricCost: "Cost", .metricTokens: "Tokens", .tokensWord: "tokens",
        .quotaSession: "Session", .quotaWeekly: "Weekly", .quotaOpus: "Opus", .quotaSonnet: "Sonnet",
        .resetFmt: "resets %@",
        .inDaysHours: "in %dd %dh", .inHoursMinutes: "in %dh %02d", .inMinutes: "in %d min",
        .ageNow: "just now", .ageMinutes: "%d min ago", .ageHours: "%dh %02d ago", .ageDays: "%dd ago",
        .updatedFmt: "updated %@", .planUpdatedFmt: "%@ · updated %@",
        .rateLimitFooter: "last values: %@ · usage API rate limit, retry %@",
        .retrySoon: "soon", .genericError: "Error",
        .errNoCredentials: "Claude Code not found — sign in with `claude`",
        .errUnreadable: "Unreadable Claude Code credentials", .errKeychain: "Keychain access denied",
        .errUnauthorized: "Token expired — run Claude Code to renew it",
        .errRateLimited: "The usage API is rate-limiting requests", .errHTTP: "HTTP error %d", .errNetwork: "Network: %@",
        .errBadResponse: "unexpected response",
        .rateLimitedFull: "The usage API is rate-limiting requests (your Claude limit is not reached). Retrying at %@.",
        .statusNone: "No agent waiting", .statusWorking: "Claude is working… %@",
        .statusWaiting: "%@ · waiting for your reply", .statusApprovalTool: "%@ · permission required",
        .statusApprovalAction: "%@ · action required",
        .noConversations: "No recent Claude Code conversation", .untitled: "Conversation",
    ]

    private static let es: [L10n: String] = [
        .haloToggle: "Halo alrededor del notch",
        .hoverStyle: "Al pasar el ratón", .hoverOff: "Fijo", .hoverSubtle: "Sutil", .hoverBouncy: "Elástico",
        .popupStyle: "Fondo del popup", .styleGlass: "Cristal", .styleBlack: "Negro",
        .quit: "Salir", .history: "Historial", .back: "Volver", .loading: "Cargando…",
        .soundHelp: "Sonido de notificaciones de agente",
        .fontTitle: "Fuente de la hora", .soundToggle: "Sonido de notificaciones de agente",
        .launchToggle: "Abrir Clawdio al iniciar sesión", .launchError: "No se pudo cambiar el inicio automático",
        .language: "Idioma", .languageAuto: "Auto",
        .fontSystem: "Sistema", .fontMono: "Mono", .fontMinecraft: "Minecraft",
        .today: "Hoy", .tokensToday: "Tokens hoy", .period30: "30 días", .tokens30: "Tokens 30 d",
        .topModel: "Modelo top", .analyzing: "Analizando registros…", .noActivity: "Sin actividad en 30 días",
        .partialCost: "Algunos modelos sin tarifa — coste parcial",
        .metricCost: "Coste", .metricTokens: "Tokens", .tokensWord: "tokens",
        .quotaSession: "Sesión", .quotaWeekly: "Semana", .quotaOpus: "Opus", .quotaSonnet: "Sonnet",
        .resetFmt: "reinicio %@",
        .inDaysHours: "en %d d %d h", .inHoursMinutes: "en %d h %02d", .inMinutes: "en %d min",
        .ageNow: "ahora mismo", .ageMinutes: "hace %d min", .ageHours: "hace %d h %02d", .ageDays: "hace %d d",
        .updatedFmt: "actualizado %@", .planUpdatedFmt: "%@ · actualizado %@",
        .rateLimitFooter: "últimos valores: %@ · límite de la API de uso, reintento %@",
        .retrySoon: "pronto", .genericError: "Error",
        .errNoCredentials: "Claude Code no encontrado — inicia sesión con `claude`",
        .errUnreadable: "Credenciales de Claude Code ilegibles", .errKeychain: "Acceso al llavero denegado",
        .errUnauthorized: "Token caducado — abre Claude Code para renovarlo",
        .errRateLimited: "La API de uso limita las solicitudes", .errHTTP: "Error HTTP %d", .errNetwork: "Red: %@",
        .errBadResponse: "respuesta inesperada",
        .rateLimitedFull: "La API de uso limita las solicitudes (tu límite de Claude no se ha alcanzado). Nuevo intento a las %@.",
        .statusNone: "Ningún agente en espera", .statusWorking: "Claude está trabajando… %@",
        .statusWaiting: "%@ · espera tu respuesta", .statusApprovalTool: "%@ · permiso requerido",
        .statusApprovalAction: "%@ · acción requerida",
        .noConversations: "Ninguna conversación reciente de Claude Code", .untitled: "Conversación",
    ]

    private static let de: [L10n: String] = [
        .haloToggle: "Leuchtrand um den Notch",
        .hoverStyle: "Hover-Effekt", .hoverOff: "Ruhig", .hoverSubtle: "Dezent", .hoverBouncy: "Federnd",
        .popupStyle: "Popup-Hintergrund", .styleGlass: "Glas", .styleBlack: "Schwarz",
        .quit: "Beenden", .history: "Verlauf", .back: "Zurück", .loading: "Lädt…",
        .soundHelp: "Ton für Agent-Benachrichtigungen",
        .fontTitle: "Schrift der Uhrzeit", .soundToggle: "Ton für Agent-Benachrichtigungen",
        .launchToggle: "Clawdio bei der Anmeldung starten", .launchError: "Autostart konnte nicht geändert werden",
        .language: "Sprache", .languageAuto: "Auto",
        .fontSystem: "System", .fontMono: "Mono", .fontMinecraft: "Minecraft",
        .today: "Heute", .tokensToday: "Tokens heute", .period30: "30 Tage", .tokens30: "Tokens 30 T",
        .topModel: "Top-Modell", .analyzing: "Protokolle werden analysiert…", .noActivity: "Keine Aktivität in 30 Tagen",
        .partialCost: "Einige Modelle ohne Preis — Kosten unvollständig",
        .metricCost: "Kosten", .metricTokens: "Tokens", .tokensWord: "Tokens",
        .quotaSession: "Sitzung", .quotaWeekly: "Woche", .quotaOpus: "Opus", .quotaSonnet: "Sonnet",
        .resetFmt: "Reset %@",
        .inDaysHours: "in %d T %d Std", .inHoursMinutes: "in %d Std %02d", .inMinutes: "in %d Min",
        .ageNow: "gerade eben", .ageMinutes: "vor %d Min", .ageHours: "vor %d Std %02d", .ageDays: "vor %d T",
        .updatedFmt: "aktualisiert %@", .planUpdatedFmt: "%@ · aktualisiert %@",
        .rateLimitFooter: "letzte Werte: %@ · Limit der Nutzungs-API, nächster Versuch %@",
        .retrySoon: "bald", .genericError: "Fehler",
        .errNoCredentials: "Claude Code nicht gefunden — mit `claude` anmelden",
        .errUnreadable: "Claude-Code-Zugangsdaten nicht lesbar", .errKeychain: "Zugriff auf den Schlüsselbund verweigert",
        .errUnauthorized: "Token abgelaufen — Claude Code starten, um ihn zu erneuern",
        .errRateLimited: "Die Nutzungs-API begrenzt die Anfragen", .errHTTP: "HTTP-Fehler %d", .errNetwork: "Netzwerk: %@",
        .errBadResponse: "unerwartete Antwort",
        .rateLimitedFull: "Die Nutzungs-API begrenzt die Anfragen (dein Claude-Limit ist nicht erreicht). Neuer Versuch um %@.",
        .statusNone: "Kein Agent wartet", .statusWorking: "Claude arbeitet… %@",
        .statusWaiting: "%@ · wartet auf deine Antwort", .statusApprovalTool: "%@ · Berechtigung erforderlich",
        .statusApprovalAction: "%@ · Aktion erforderlich",
        .noConversations: "Keine aktuellen Claude-Code-Unterhaltungen", .untitled: "Unterhaltung",
    ]
}

// MARK: - Environnement SwiftUI

private struct StringsKey: EnvironmentKey {
    static let defaultValue = Strings(.system)
}

extension EnvironmentValues {
    /// `@Environment(\.t) var t` puis `t(.quit)`.
    var t: Strings {
        get { self[StringsKey.self] }
        set { self[StringsKey.self] = newValue }
    }
}
