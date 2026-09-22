#if DEBUG
import Foundation

/// Données d'exemple pour les captures publiées (README) : aucune donnée réelle — ni quota, ni coût, ni titre de
/// conversation. Voir `scripts/make-screenshot.sh`. Debug uniquement.
@MainActor
enum DemoData {
    static func fill(usage: UsageModel, local: LocalUsageStore, sessions: SessionStore, settings: AppSettings) {
        settings.setLanguage(.en) // les captures publiées sont en anglais, comme le README
        usage.setDemo(UsageSnapshot(
            rows: [
                UsageRow(id: "session", title: "Session", percent: 42, resetsAt: .now.addingTimeInterval(3 * 3600 + 12 * 60)),
                UsageRow(id: "weekly", title: "Semaine", percent: 61, resetsAt: .now.addingTimeInterval(4 * 86400 + 9 * 3600)),
            ],
            plan: "Max",
            fetchedAt: .now
        ))
        local.setDemo(stats())
        sessions.setDemo(demoSessions(), thread: demoThread())
    }

    /// 30 jours de coûts plausibles, répartis sur trois modèles.
    private static func stats() -> UsageStats {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let families = [("Sonnet 5", "sonnet", 0.55), ("Opus 5", "opus", 0.3), ("Fable 5.1", "fable", 0.15)]
        // Suite déterministe : la capture est reproductible.
        var seed = 7.0
        func next() -> Double {
            seed = (seed * 9301 + 49297).truncatingRemainder(dividingBy: 233280)
            return seed / 233280
        }

        var days: [DayTotal] = []
        var points: [UsagePoint] = []
        var totals: [String: (cost: Double, tokens: Int, output: Int)] = [:]
        for offset in stride(from: 29, through: 0, by: -1) {
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let weekend = calendar.isDateInWeekend(day)
            let dayCost = (weekend ? 1.5 : 6.0) + next() * (weekend ? 4 : 16)
            var total = DayTotal(day: day)
            for (model, family, share) in families {
                let cost = dayCost * share
                let tokens = Int(cost * 420_000)
                points.append(UsagePoint(day: day, model: model, family: family, cost: cost, tokens: tokens))
                total.cost += cost
                total.input += tokens / 6
                total.output += tokens / 24
                total.cacheRead += tokens - tokens / 6 - tokens / 24
                let running = totals[model] ?? (0, 0, 0)
                totals[model] = (running.cost + cost, running.tokens + tokens, running.output + tokens / 24)
            }
            days.append(total)
        }
        let models = families.map { model, family, _ in
            let running = totals[model] ?? (0, 0, 0)
            return ModelTotal(model: model, family: family, isPriced: true,
                              cost: running.cost, tokens: running.tokens, output: running.output)
        }.sorted { $0.cost > $1.cost }
        return UsageStats(dayTotals: days, points: points, models: models)
    }

    private static func demoSessions() -> [AgentSession] {
        let url = URL(fileURLWithPath: "/tmp/clawdio-demo.jsonl")
        return [
            AgentSession(id: "demo-1", url: url, title: "Pixel art avatar for the notch", project: "clawdio",
                         lastActivity: .now.addingTimeInterval(-40), state: .waitingReply, pendingTool: nil,
                         snippet: "Done — the sprite sheet now covers every tool state."),
            AgentSession(id: "demo-2", url: url, title: "Checkout API rate limits", project: "billing-api",
                         lastActivity: .now.addingTimeInterval(-6 * 60), state: .working, pendingTool: "Read",
                         snippet: "Reading the middleware to find where the retry budget is spent."),
            AgentSession(id: "demo-3", url: url, title: "Postgres 16 migration", project: "infra",
                         lastActivity: .now.addingTimeInterval(-52 * 60), state: .idle, pendingTool: nil,
                         snippet: "Migration finished, 42 tables moved."),
        ]
    }

    private static func demoThread() -> [ChatMessage] {
        [
            ChatMessage(id: 0, isUser: true, text: "Make the avatar react to the tool Claude is using."),
            ChatMessage(id: 1, isUser: false, text: "The scanner already exposes the pending tool — I'll map each tool to an activity and draw one prop per activity."),
            ChatMessage(id: 2, isUser: true, text: "Keep it calm, no flailing arms."),
            ChatMessage(id: 3, isUser: false, text: "Done — the sprite sheet now covers every tool state."),
        ]
    }
}

#endif
