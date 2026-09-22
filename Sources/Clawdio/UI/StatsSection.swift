import Charts
import SwiftUI

// MARK: - Formatage (respecte la locale : "3,7B", "$9,83")

enum Fmt {
    /// Locale des nombres ("3,8B" en français, "3.8B" en anglais) : suit la langue choisie dans les réglages.
    static var locale = Locale.current

    static func dollars(_ v: Double) -> String {
        "$" + v.formatted(.number.precision(.fractionLength(v >= 100 ? 0 : 2)).locale(locale))
    }

    static func tokens(_ n: Double) -> String {
        let (value, suffix): (Double, String) =
            n >= 1e9 ? (n / 1e9, "B") : n >= 1e6 ? (n / 1e6, "M") : n >= 1e3 ? (n / 1e3, "k") : (n, "")
        let digits = (suffix.isEmpty || value >= 10) ? 0 : 1
        return value.formatted(.number.precision(.fractionLength(digits)).locale(locale)) + suffix
    }

    /// Borne haute "ronde" (1, 2, 5 × 10ⁿ) pour une échelle Y stable.
    static func niceCeil(_ v: Double) -> Double {
        guard v > 0 else { return 1 }
        let exponent = pow(10, floor(log10(v)))
        let m = v / exponent
        return (m <= 1 ? 1 : m <= 2 ? 2 : m <= 5 ? 5 : 10) * exponent
    }
}

/// Teintes d'orange Claude : le modèle le plus utilisé est le plus soutenu, les suivants s'éclaircissent.
enum ModelPalette {
    private static let shades: [Color] = [
        Color(red: 0.79, green: 0.36, blue: 0.20),
        Color(red: 0.89, green: 0.56, blue: 0.40),
        Color(red: 0.95, green: 0.74, blue: 0.62),
        Color(red: 0.62, green: 0.62, blue: 0.72),
    ]

    static func colors(for models: [ModelTotal]) -> [String: Color] {
        Dictionary(uniqueKeysWithValues: models.enumerated().map { ($1.model, shades[min($0, shades.count - 1)]) })
    }
}

/// Nombre qui défile jusqu'à sa valeur (interpolation de `value` pendant l'animation).
struct CountUp: View, Animatable {
    var value: Double
    let format: (Double) -> String
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    var body: some View { Text(format(value)) }
}

/// "à l'instant", "il y a 3 min", "il y a 2 h 05" (dans la langue choisie). Mis à jour toutes les 30 s au plus :
/// `Text(date, style: .relative)` se rafraîchit chaque seconde, et chaque rafraîchissement invalide la fenêtre
/// (verre liquide = recomposition coûteuse).
struct AgeText: View {
    let date: Date
    @Environment(\.t) private var t

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text(Self.phrase(from: date, to: context.date, t: t))
        }
    }

    static func phrase(from date: Date, to now: Date, t: Strings) -> String {
        let seconds = max(now.timeIntervalSince(date), 0)
        if seconds < 45 { return t(.ageNow) }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return t(.ageMinutes, max(minutes, 1)) }
        let hours = minutes / 60
        if hours < 24 { return t(.ageHours, hours, minutes % 60) }
        return t(.ageDays, hours / 24)
    }
}

// MARK: - Rangée d'étiquettes

struct StatsRow: View {
    let stats: UsageStats?
    @Environment(\.t) private var t

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            cell(t(.today), stats.map { Fmt.dollars($0.todayCost) })
            cell(t(.tokensToday), stats.map { Fmt.tokens(Double($0.todayTokens)) })
            cell(t(.period30), stats.map { Fmt.dollars($0.periodCost) })
            cell(t(.tokens30), stats.map { Fmt.tokens(Double($0.periodTokens)) })
            cell(t(.topModel), stats.flatMap { $0.topModel?.model })
        }
        .frame(height: ExpandedLayout.statsRowHeight)
    }

    private func cell(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
            Text(value ?? "–")
                .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(value == nil ? .white.opacity(0.3) : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                // Les chiffres qui changent au fil des mises à jour "roulent" doucement.
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.45), value: value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Graphique minimaliste (30 jours, sans axes) + survol jour par jour

/// Deux couches indépendantes :
/// - `ChartCanvas` : le tracé Swift Charts. Ses entrées ne contiennent PAS l'index survolé, et `.equatable()`
///   lui interdit tout recalcul tant que données / métrique ne changent pas (un `Chart` complet coûte cher).
/// - `HoverLayer` : bandeau + bulle, quelques rectangles. Seule cette couche suit la souris.
struct MinimalChart: View {
    let stats: UsageStats?
    let metric: ChartMetric
    let state: NotchState
    @State private var shown = Reveal.instant
    @Environment(\.t) private var t

    var body: some View {
        GeometryReader { geo in
            if let stats, !stats.isEmpty {
                ZStack(alignment: .topLeading) {
                    ChartCanvas(stats: stats, metric: metric, shown: shown).equatable()
                    HoverLayer(stats: stats, state: state, size: geo.size)
                }
            } else {
                Text(stats == nil ? t(.analyzing) : t(.noActivity))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: ExpandedLayout.chartHeight)
        .onAppear { withAnimation(.smooth(duration: 0.4)) { shown = true } }
    }
}

private struct ChartCanvas: View, Equatable {
    let stats: UsageStats
    let metric: ChartMetric
    let shown: Bool

    var body: some View {
        let colors = ModelPalette.colors(for: stats.models)
        let names = stats.models.map(\.model)
        let value: (UsagePoint) -> Double = { metric == .cost ? $0.cost : Double($0.tokens) }
        let daily = Dictionary(grouping: stats.points, by: \.day).values.map { $0.reduce(0) { $0 + value($1) } }
        let top = max((daily.max() ?? 0) * 1.06, 0.0001) // axe masqué → pas besoin d'une borne "ronde"

        Chart(stats.points) { point in
            BarMark(
                x: .value("Jour", point.day, unit: .day),
                y: .value(metric.rawValue, shown ? value(point) : 0),
                width: .ratio(0.7)
            )
            .foregroundStyle(by: .value("Modèle", point.model))
            .cornerRadius(2.5)
        }
        .chartForegroundStyleScale(domain: names, range: names.map { colors[$0] ?? .gray })
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...top)
        // Quand les chiffres se mettent à jour, les barres glissent vers leur nouvelle hauteur.
        .animation(.smooth(duration: 0.6), value: stats)
        .animation(.smooth(duration: 0.6), value: metric)
    }
}

private struct HoverLayer: View {
    let stats: UsageStats
    let state: NotchState
    let size: CGSize
    @Environment(\.t) private var t

    var body: some View {
        // `hoveredDay` n'est publié par le controller que quand la barre survolée change.
        if let index = state.hoveredDay, index < stats.dayTotals.count {
            let slot = size.width / CGFloat(stats.dayTotals.count)
            ZStack(alignment: .topLeading) {
                // Bandeau de mise en valeur : le tracé dessous n'est jamais touché.
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.white.opacity(0.13))
                    .frame(width: slot, height: size.height)
                    .offset(x: slot * CGFloat(index))
                tooltip(index: index, slot: slot)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func tooltip(index: Int, slot: CGFloat) -> some View {
        let day = stats.dayTotals[index]
        let tipWidth: CGFloat = 196
        // À côté de la barre survolée (jamais dessus) : à droite s'il reste de la place, sinon à gauche.
        let slotLeft = slot * CGFloat(index)
        let x = slotLeft + slot + 8 + tipWidth <= size.width ? slotLeft + slot + 8 : max(slotLeft - tipWidth - 8, 0)
        let perModel = stats.points.filter { $0.day == day.day && $0.cost > 0 }

        return VStack(alignment: .leading, spacing: 2) {
            Text(day.day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(t.locale)))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text("\(Fmt.dollars(day.cost)) · \(Fmt.tokens(Double(day.totalTokens))) \(t(.tokensWord))")
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
            if perModel.count > 1 {
                Text(perModel.map { "\($0.model) \(Fmt.dollars($0.cost))" }.joined(separator: " · "))
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(width: tipWidth, alignment: .leading)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 0.5))
        .offset(x: x, y: -2)
    }
}

/// Ligne sous le graphique : avertissement de prix partiel (orange) ou légende, + sélecteur Coût/Tokens.
struct ChartNote: View {
    let stats: UsageStats?
    @Binding var metric: ChartMetric
    @Environment(\.t) private var t

    var body: some View {
        HStack(spacing: 10) {
            if let stats, stats.hasUnpricedModels {
                Text(t(.partialCost))
                    .foregroundStyle(Color(red: 1.0, green: 0.60, blue: 0.22))
            } else if let stats, !stats.isEmpty {
                let colors = ModelPalette.colors(for: stats.models)
                ForEach(stats.models.prefix(3)) { model in
                    HStack(spacing: 4) {
                        Circle().fill(colors[model.model] ?? .gray).frame(width: 6, height: 6)
                        Text(model.model).foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                ForEach(ChartMetric.allCases, id: \.self) { item in
                    Text(item == .cost ? t(.metricCost) : t(.metricTokens))
                        .foregroundStyle(.white.opacity(metric == item ? 0.95 : 0.4))
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(.snappy(duration: 0.3)) { metric = item } }
                }
            }
        }
        .font(.system(size: 10, weight: .medium))
        .lineLimit(1)
        .frame(height: ExpandedLayout.noteHeight)
    }
}

// MARK: - Jauge de quota

struct QuotaRow: View {
    let row: UsageRow
    let revealed: Bool
    @Environment(\.t) private var t

    var body: some View {
        let level = UsageLevel(percent: row.percent)
        let percent = Int(row.percent.rounded())
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(t.quotaTitle(id: row.id, fallback: row.title))
                    .font(.system(size: 14, weight: .semibold))
                if let resetsAt = row.resetsAt {
                    TimelineView(.periodic(from: .now, by: 15)) { context in
                        Text(t(.resetFmt, Self.remaining(until: resetsAt, from: context.date, t: t)))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(level.color)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.45), value: percent)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(level.color)
                        .frame(width: proxy.size.width * (revealed ? min(max(row.percent / 100, 0.012), 1) : 0))
                        .animation(.smooth(duration: 0.35), value: revealed)
                        .animation(.smooth(duration: 0.6), value: row.percent)
                }
            }
            .frame(height: 4)
        }
        .frame(height: ExpandedLayout.rowHeight)
    }

    /// "dans 2 h 51", "dans 12 min", "dans 3 j 4 h" (dans la langue choisie)
    private static func remaining(until date: Date, from now: Date, t: Strings) -> String {
        let minutes = max(Int(date.timeIntervalSince(now) / 60), 0)
        let (days, hours, mins) = (minutes / 1440, minutes % 1440 / 60, minutes % 60)
        if days > 0 { return t(.inDaysHours, days, hours) }
        if hours > 0 { return t(.inHoursMinutes, hours, mins) }
        return t(.inMinutes, mins)
    }
}
