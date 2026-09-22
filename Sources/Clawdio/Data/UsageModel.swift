import Foundation
import Observation

struct UsageRow: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let percent: Double
    let resetsAt: Date?
}

struct UsageSnapshot: Equatable, Codable {
    let rows: [UsageRow]
    let plan: String?
    let fetchedAt: Date

    var session: UsageRow? { rows.first { $0.id == "session" } }
    var weekly: UsageRow? { rows.first { $0.id == "weekly" } }

    init(rows: [UsageRow], plan: String?, fetchedAt: Date) {
        self.rows = rows
        self.plan = plan
        self.fetchedAt = fetchedAt
    }

    init(response: UsageResponse, plan: String?, fetchedAt: Date = .now) {
        let candidates: [(String, String, UsageResponse.Window?)] = [
            ("session", "Session", response.fiveHour),
            ("weekly", "Semaine", response.sevenDay),
            ("opus", "Opus", response.sevenDayOpus),
            ("sonnet", "Sonnet", response.sevenDaySonnet),
        ]
        rows = candidates.compactMap { id, title, window in
            guard let window, let percent = window.utilization else { return nil }
            return UsageRow(id: id, title: title, percent: percent, resetsAt: window.resetsAt)
        }
        self.plan = plan
        self.fetchedAt = fetchedAt
    }
}

@MainActor @Observable
final class UsageModel {
    private(set) var snapshot: UsageSnapshot?
    private(set) var error: UsageError?
    private(set) var isRefreshing = false

    /// Appelé quand le nombre de lignes peut avoir changé (→ le panel doit se redimensionner).
    @ObservationIgnored var onLayoutChange: (() -> Void)?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var lastAttempt = Date.distantPast
    @ObservationIgnored private var rateLimitStreak = 0

    /// Prochaine tentative autorisée après une erreur (nil = pas de recul en cours).
    private(set) var retryAt: Date?

    init() {
        snapshot = Self.loadCached()
        // Valeurs récentes déjà en cache : pas de requête immédiate au lancement (évite de marteler l'API).
        lastAttempt = snapshot?.fetchedAt ?? .distantPast
    }

#if DEBUG
    /// Données d'exemple pour les captures du README (voir `DemoData`). Debug uniquement.
    func setDemo(_ snapshot: UsageSnapshot) {
        self.snapshot = snapshot
        error = nil
        retryAt = nil
    }
#endif

    // MARK: Cache disque : les dernières valeurs survivent aux 429 et aux relancements

    private static let cacheKey = "clawdio.lastUsageSnapshot"

    private static func loadCached() -> UsageSnapshot? {
        guard
            let data = UserDefaults.standard.data(forKey: cacheKey),
            var cached = try? JSONDecoder().decode(UsageSnapshot.self, from: data),
            Date.now.timeIntervalSince(cached.fetchedAt) < 12 * 3600
        else { return nil }
        // Une fenêtre déjà réinitialisée n'a plus de sens : on ne garde que celles encore en cours.
        let live = cached.rows.filter { $0.resetsAt.map { $0 > .now } ?? true }
        guard !live.isEmpty else { return nil }
        cached = UsageSnapshot(rows: live, plan: cached.plan, fetchedAt: cached.fetchedAt)
        return cached
    }

    private func saveCache() {
        guard let snapshot, let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.cacheKey)
    }

    var isRateLimited: Bool {
        if case .rateLimited = error { return true }
        return false
    }

    /// Message complet pour l'utilisateur. Un 429 ne veut PAS dire que sa limite Claude est atteinte :
    /// c'est l'API de consultation du quota qui refuse trop de requêtes.
    func statusMessage(_ t: Strings) -> String? {
        guard let error else { return nil }
        switch error {
        case .rateLimited:
            return t(.rateLimitedFull, retryAt.map(t.time) ?? t(.retrySoon))
        default:
            return error.message(t)
        }
    }

    /// Nombre de lignes visibles dans la vue étendue (1 = message d'état).
    var rowCount: Int { max(snapshot?.rows.count ?? 0, 1) }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let delay = await self.refresh()
                try? await Task.sleep(for: delay)
            }
        }
    }

    /// Un fetch. Retourne le délai avant le suivant.
    ///
    /// L'endpoint d'usage est strict et non documenté : trop de requêtes → 429 (avec `retry-after: 0`,
    /// donc inutilisable). On se limite donc à 1 requête / 45 s (10 s pour un clic manuel), rien du tout
    /// pendant un recul, et un recul exponentiel (5 → 10 → 20 → 30 min) après chaque 429.
    @discardableResult
    func refresh(force: Bool = false) async -> Duration {
        if let retryAt, retryAt > .now { return .seconds(max(retryAt.timeIntervalSinceNow, 1)) }
        let gap: TimeInterval = force ? 10 : 45
        let sinceLast = Date.now.timeIntervalSince(lastAttempt)
        guard sinceLast >= gap else { return .seconds(gap - sinceLast + 1) }
        guard !isRefreshing else { return .seconds(gap) }
        lastAttempt = .now
        isRefreshing = true
        defer { isRefreshing = false }

        let before = rowCount
        defer { if rowCount != before { onLayoutChange?() } }

        do {
            // Lecture bloquante (sous-processus) : hors du thread principal.
            let credentials = try await Task.detached { try ClaudeCredentials.load() }.value
            let response = try await UsageAPI.fetch(token: credentials.accessToken)
            snapshot = UsageSnapshot(response: response, plan: credentials.subscriptionType)
            saveCache()
            error = nil
            retryAt = nil
            rateLimitStreak = 0
            return .seconds(120)
        } catch let failure as UsageError {
            return recordFailure(failure)
        } catch {
            return recordFailure(.network(error.localizedDescription))
        }
    }

    /// Mémorise l'erreur (en gardant les dernières valeurs affichées) et calcule le délai avant réessai.
    private func recordFailure(_ failure: UsageError) -> Duration {
        error = failure
        var delay: TimeInterval
        if case .rateLimited(let after) = failure {
            rateLimitStreak += 1
            let backoff = min(300 * pow(2, Double(rateLimitStreak - 1)), 1800)
            delay = max(after ?? 0, backoff) + Double.random(in: 0...30)
        } else {
            let (seconds, attoseconds) = failure.retryDelay.components
            delay = Double(seconds) + Double(attoseconds) / 1e18
        }
        retryAt = Date.now.addingTimeInterval(delay)
        return .seconds(delay)
    }
}
