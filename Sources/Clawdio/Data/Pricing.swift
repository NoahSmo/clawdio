import Foundation

/// Tarifs API en $ par million de tokens.
/// Les logs de Claude Code ne contiennent pas de prix : le coût affiché est une *estimation
/// au tarif API* (ce qu'aurait coûté le même usage en pay-as-you-go), pas ta facture d'abonnement.
struct Rates {
    let input: Double
    let output: Double
    let cacheRead: Double
    let cacheWrite5m: Double
    let cacheWrite1h: Double

    /// Multiplicateurs standards : écriture cache 5 min = 1,25×, 1 h = 2×, lecture = 0,1×.
    init(input: Double, output: Double, cacheRead: Double? = nil) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead ?? input * 0.1
        self.cacheWrite5m = input * 1.25
        self.cacheWrite1h = input * 2
    }

    func cost(_ r: TokenRecord) -> Double {
        (Double(r.input) * input
            + Double(r.output) * output
            + Double(r.cacheRead) * cacheRead
            + Double(r.write5m) * cacheWrite5m
            + Double(r.write1h) * cacheWrite1h) / 1_000_000
    }
}

struct ModelInfo {
    let family: String       // "sonnet", "opus", "fable", "haiku"…
    let displayName: String  // "Sonnet 5", "Fable 5.1"
    let rates: Rates
    /// false = famille inconnue, tarif de repli → le coût affiché est partiel.
    let isPriced: Bool
}

enum Pricing {
    /// "claude-fable-5-1" → Fable 5.1 · "claude-opus-4-5-20251101" → Opus 4.5 · "claude-3-5-sonnet-…" → Sonnet 3.5
    static func info(for modelID: String) -> ModelInfo {
        let base = modelID.components(separatedBy: "[")[0]
        var parts = base.split(separator: "-").map(String.init)
        if parts.first == "claude" { parts.removeFirst() }
        parts.removeAll { $0.count == 8 && Int($0) != nil } // suffixe de date

        let family = parts.first { Int($0) == nil } ?? base
        let numbers = parts.compactMap(Int.init)
        let version = numbers.map(String.init).joined(separator: ".")
        let versionValue = Double(numbers.first ?? 0) + Double(numbers.dropFirst().first ?? 0) / 10

        let rates: Rates
        var isPriced = true
        switch family {
        case "fable", "mythos": rates = Rates(input: 10, output: 50, cacheRead: 0.25)
        case "opus": rates = versionValue >= 4.5 ? Rates(input: 5, output: 25) : Rates(input: 15, output: 75)
        case "sonnet": rates = versionValue >= 5 ? Rates(input: 2, output: 10) : Rates(input: 3, output: 15)
        case "haiku":
            rates = versionValue >= 4.5 ? Rates(input: 1, output: 5)
                : versionValue >= 3.5 ? Rates(input: 0.8, output: 4)
                : Rates(input: 0.25, output: 1.25)
        default:
            rates = Rates(input: 3, output: 15)
            isPriced = false
        }
        let name = version.isEmpty ? family.capitalized : "\(family.capitalized) \(version)"
        return ModelInfo(family: family, displayName: name, rates: rates, isPriced: isPriced)
    }
}
