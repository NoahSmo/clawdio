import Foundation

// MARK: - Modèles

/// Un message assistant tel que loggé par Claude Code (`~/.claude/projects/**/*.jsonl`).
struct TokenRecord {
    let key: String        // message.id + requestId
    let date: Date
    let day: Date          // début du jour local, calculé une seule fois au parsing (Calendar coûte cher)
    let modelID: String
    var input = 0
    var output = 0
    var cacheRead = 0
    var write5m = 0
    var write1h = 0

    /// Claude Code répète un même message une fois par bloc de contenu, avec un usage
    /// identique ou de plus en plus complet → on garde le max champ par champ.
    mutating func absorb(_ other: TokenRecord) {
        input = max(input, other.input)
        output = max(output, other.output)
        cacheRead = max(cacheRead, other.cacheRead)
        write5m = max(write5m, other.write5m)
        write1h = max(write1h, other.write1h)
    }
}

struct UsagePoint: Identifiable, Equatable {
    let day: Date
    let model: String
    let family: String
    var cost: Double
    var tokens: Int        // total, cache inclus
    var id: String { "\(day.timeIntervalSinceReferenceDate)|\(model)" }
}

struct DayTotal: Identifiable, Equatable {
    let day: Date
    var cost = 0.0
    var input = 0          // tokens "neufs" : entrée + écriture de cache
    var output = 0
    var cacheRead = 0
    var totalTokens: Int { input + output + cacheRead }
    var id: Date { day }
}

struct ModelTotal: Identifiable, Equatable {
    let model: String
    let family: String
    let isPriced: Bool
    var cost = 0.0
    var tokens = 0
    var output = 0
    var id: String { model }
}

struct UsageStats: Equatable {
    let dayTotals: [DayTotal]     // toujours `days` entrées, jours vides inclus
    let points: [UsagePoint]      // coût/tokens par jour × modèle
    let models: [ModelTotal]      // triés par coût décroissant

    var isEmpty: Bool { models.isEmpty }
    var topModel: ModelTotal? { models.first }
    var hasUnpricedModels: Bool { models.contains { !$0.isPriced } }
    var todayCost: Double { dayTotals.last?.cost ?? 0 }
    var todayTokens: Int { dayTotals.last?.totalTokens ?? 0 }
    var periodCost: Double { dayTotals.reduce(0) { $0 + $1.cost } }
    var periodTokens: Int { dayTotals.reduce(0) { $0 + $1.totalTokens } }

#if DEBUG
    /// Données d'exemple pour les captures du README (voir `DemoData`). Debug uniquement.
    init(dayTotals: [DayTotal], points: [UsagePoint], models: [ModelTotal]) {
        self.dayTotals = dayTotals
        self.points = points
        self.models = models
    }
#endif

    init(records: [TokenRecord], now: Date, days: Int, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        let dayList = (0..<days).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }

        var perDay = Dictionary(uniqueKeysWithValues: dayList.map { ($0, DayTotal(day: $0)) })
        var perPoint: [String: UsagePoint] = [:]
        var perModel: [String: ModelTotal] = [:]

        for record in records {
            let day = record.day
            guard perDay[day] != nil else { continue }
            let info = Pricing.info(for: record.modelID)
            let cost = info.rates.cost(record)
            let fresh = record.input + record.write5m + record.write1h
            let total = fresh + record.output + record.cacheRead

            perDay[day]?.cost += cost
            perDay[day]?.input += fresh
            perDay[day]?.output += record.output
            perDay[day]?.cacheRead += record.cacheRead

            let point = UsagePoint(day: day, model: info.displayName, family: info.family, cost: 0, tokens: 0)
            perPoint[point.id, default: point].cost += cost
            perPoint[point.id]?.tokens += total

            var model = perModel[info.displayName]
                ?? ModelTotal(model: info.displayName, family: info.family, isPriced: info.isPriced)
            model.cost += cost
            model.tokens += total
            model.output += record.output
            perModel[info.displayName] = model
        }

        dayTotals = dayList.compactMap { perDay[$0] }
        models = perModel.values.sorted { $0.cost > $1.cost }

        // Un point à 0 pour les jours vides, sinon l'axe X du graphique saute ces jours.
        var points = Array(perPoint.values)
        if let first = models.first {
            let covered = Set(points.map(\.day))
            for day in dayList where !covered.contains(day) {
                points.append(UsagePoint(day: day, model: first.model, family: first.family, cost: 0, tokens: 0))
            }
        }
        self.points = points.sorted { ($0.day, $0.model) < ($1.day, $1.model) }
    }
}

// MARK: - Scanner de logs

/// Parcourt les JSONL de Claude Code. Les fichiers non modifiés depuis le dernier passage
/// ne sont pas relus (cache par chemin + date de modif + taille).
actor LogScanner {
    private struct Cached {
        let modified: Date
        let size: Int
        let records: [TokenRecord]
    }

    private var cache: [URL: Cached] = [:]
    private let roots: [URL]
    private let decoder = JSONDecoder()
    private let calendar = Calendar.current
    private let isoFraction: ISO8601DateFormatter
    private let isoPlain = ISO8601DateFormatter()

    init() {
        roots = ClaudePaths.projectRoots
        isoFraction = ISO8601DateFormatter()
        isoFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func scan(days: Int = 30, now: Date = .now) -> UsageStats {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) ?? now

        var seen = Set<URL>()
        var merged: [String: TokenRecord] = [:]

        for root in roots {
            guard let walker = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in walker where url.pathExtension == "jsonl" {
                guard
                    let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                    let modified = values.contentModificationDate,
                    modified >= cutoff // un fichier pas touché depuis la fenêtre ne contient rien de récent
                else { continue }
                let size = values.fileSize ?? 0
                seen.insert(url)

                let records: [TokenRecord]
                if let hit = cache[url], hit.modified == modified, hit.size == size {
                    records = hit.records
                } else {
                    records = parse(url)
                    cache[url] = Cached(modified: modified, size: size, records: records)
                }

                for record in records {
                    if var existing = merged[record.key] {
                        existing.absorb(record)
                        merged[record.key] = existing
                    } else {
                        merged[record.key] = record
                    }
                }
            }
        }

        cache = cache.filter { seen.contains($0.key) }
        return UsageStats(records: Array(merged.values), now: now, days: days, calendar: calendar)
    }

    // MARK: Parsing

    private struct LogLine: Decodable {
        struct Message: Decodable {
            let id: String?
            let model: String?
            let usage: Usage?
        }
        struct Usage: Decodable {
            struct CacheSplit: Decodable {
                let fiveMinutes: Int?
                let oneHour: Int?
                enum CodingKeys: String, CodingKey {
                    case fiveMinutes = "ephemeral_5m_input_tokens"
                    case oneHour = "ephemeral_1h_input_tokens"
                }
            }
            let input: Int?
            let output: Int?
            let cacheRead: Int?
            let cacheCreation: Int?
            let cacheSplit: CacheSplit?
            enum CodingKeys: String, CodingKey {
                case input = "input_tokens"
                case output = "output_tokens"
                case cacheRead = "cache_read_input_tokens"
                case cacheCreation = "cache_creation_input_tokens"
                case cacheSplit = "cache_creation"
            }
        }
        let requestId: String?
        let timestamp: String?
        let message: Message?
    }

    private static let needle = Array("\"output_tokens\"".utf8)

    private func parse(_ url: URL) -> [TokenRecord] {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return [] }
        var out: [TokenRecord] = []

        // Une ligne = un JSON. Recherche mémoire (memchr/memmem) : on ne décode que les lignes
        // qui portent un usage, ce qui évite de parser des centaines de Mo de tool results.
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            let total = raw.count
            var start = 0
            while start < total {
                let line = base + start
                let remaining = total - start
                var length = remaining
                if let newline = memchr(line, 0x0A, remaining) {
                    length = UnsafeRawPointer(newline) - line
                }
                defer { start += length + 1 }
                guard length > 0, memmem(line, length, Self.needle, Self.needle.count) != nil else { continue }

                guard
                    let entry = try? decoder.decode(LogLine.self, from: Data(bytes: line, count: length)),
                    let message = entry.message,
                    let id = message.id,
                    let model = message.model, model != "<synthetic>",
                    let usage = message.usage,
                    let stamp = entry.timestamp,
                    let date = isoFraction.date(from: stamp) ?? isoPlain.date(from: stamp)
                else { continue }

                var record = TokenRecord(
                    key: "\(id)|\(entry.requestId ?? "")",
                    date: date,
                    day: calendar.startOfDay(for: date),
                    modelID: model
                )
                record.input = usage.input ?? 0
                record.output = usage.output ?? 0
                record.cacheRead = usage.cacheRead ?? 0
                if let split = usage.cacheSplit {
                    record.write5m = split.fiveMinutes ?? 0
                    record.write1h = split.oneHour ?? 0
                } else {
                    record.write5m = usage.cacheCreation ?? 0
                }
                out.append(record)
            }
        }
        return out
    }
}

/// Où Claude Code range ses transcripts.
enum ClaudePaths {
    static var projectRoots: [URL] {
        var dirs: [URL] = []
        if let custom = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"] {
            dirs += custom.split(separator: ",").map { URL(fileURLWithPath: String($0)).appending(path: "projects") }
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        dirs.append(home.appending(path: ".claude/projects"))
        dirs.append(home.appending(path: ".config/claude/projects"))
        return dirs
    }
}
