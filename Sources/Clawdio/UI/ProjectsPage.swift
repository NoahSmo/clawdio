import SwiftUI

// MARK: - Coût / tokens par projet (30 jours)

struct ProjectsPage: View {
    let stats: UsageStats?
    @Bindable var state: NotchState
    @State private var shown = Reveal.instant
    @Environment(\.t) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(t(.projects)).font(.system(size: 12, weight: .semibold))
                Text("· \(t(.period30))").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                Spacer(minLength: 0)
                MetricToggle(metric: $state.metric)
            }
            .lineLimit(1)
            .frame(height: 20)

            if let stats, !stats.projects.isEmpty {
                let projects = sorted(stats.projects)
                let top = projects.map(value).max() ?? 0
                let total = projects.reduce(0) { $0 + value($1) }
                ScrollIfLive {
                    VStack(spacing: 6) {
                        ForEach(projects) { project in
                            ProjectRow(project: project, metric: state.metric,
                                       fill: shown && top > 0 ? value(project) / top : 0,
                                       share: total > 0 ? value(project) / total : 0)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else {
                Text(stats == nil ? t(.analyzing) : t(.noActivity))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { withAnimation(.smooth(duration: 0.5)) { shown = true } }
    }

    private func value(_ project: ProjectTotal) -> Double {
        state.metric == .cost ? project.cost : Double(project.tokens)
    }

    /// Le classement suit la métrique affichée : un projet peut coûter peu (cache) mais brasser beaucoup de tokens.
    private func sorted(_ projects: [ProjectTotal]) -> [ProjectTotal] {
        projects.sorted { value($0) > value($1) }
    }
}

private struct ProjectRow: View {
    let project: ProjectTotal
    let metric: ChartMetric
    let fill: Double
    let share: Double
    @Environment(\.t) private var t

    var body: some View {
        let main = metric == .cost ? Fmt.dollars(project.cost) : Fmt.tokens(Double(project.tokens))
        let other = metric == .cost ? "\(Fmt.tokens(Double(project.tokens))) \(t(.tokensWord))" : Fmt.dollars(project.cost)
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(project.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(share.formatted(.percent.precision(.fractionLength(0)).locale(Fmt.locale)))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.4))
                Spacer(minLength: 6)
                Text(main)
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(ModelPalette.accent)
                        .frame(width: proxy.size.width * min(max(fill, fill > 0 ? 0.012 : 0), 1))
                }
            }
            .frame(height: 3)
            .animation(.smooth(duration: 0.5), value: fill)
            HStack(spacing: 4) {
                Text(other)
                if project.todayCost > 0 {
                    Text("·")
                    Text("\(t(.today)) \(Fmt.dollars(project.todayCost))")
                }
                Text("·")
                AgeText(date: project.lastActive)
            }
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(.white.opacity(0.45))
            .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
