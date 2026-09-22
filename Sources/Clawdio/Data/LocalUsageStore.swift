import Foundation
import Observation

/// Stats tokens / coût / modèles calculées depuis les logs locaux de Claude Code.
@MainActor @Observable
final class LocalUsageStore {
    private(set) var stats: UsageStats?
    private(set) var isLoading = false

    @ObservationIgnored private let scanner = LogScanner()
    @ObservationIgnored private var loop: Task<Void, Never>?
    /// 60 s en fond (les chiffres ne sont visibles que popup ouvert, et l'ouverture force un refresh),
    /// 20 s tant que le popup est ouvert.
    @ObservationIgnored var interval: Duration = .seconds(60)

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: self?.interval ?? .seconds(60))
            }
        }
    }

#if DEBUG
    /// Données d'exemple pour les captures du README (voir `DemoData`). Debug uniquement.
    func setDemo(_ stats: UsageStats) { self.stats = stats }
#endif

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let fresh = await scanner.scan()
        if fresh != stats { stats = fresh } // évite de relancer les animations pour rien
    }
}
