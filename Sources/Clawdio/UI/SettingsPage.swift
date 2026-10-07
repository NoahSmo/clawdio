import SwiftUI

/// Page Paramètres : police de l'heure, personnage de l'avatar, son des notifications, démarrage automatique.
struct SettingsPage: View {
    let settings: AppSettings
    let sessions: SessionStore
    @Environment(\.t) private var t

    var body: some View {
        ScrollIfLive { content }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(t(.fontTitle))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 8) {
                    ForEach(TimeFont.allCases) { option in
                        fontChip(option)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(t(.avatarTitle))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 8) {
                    ForEach(AvatarFamily.allCases) { family in
                        AvatarFamilyCard(family: family, settings: settings)
                    }
                }
            }

            toggleRow(t(.soundToggle), isOn: sessions.soundEnabled) {
                sessions.setSoundEnabled($0)
            }
            toggleRow(t(.launchToggle), isOn: settings.launchAtLogin) {
                settings.setLaunchAtLogin($0)
            }
            toggleRow(t(.haloToggle), isOn: settings.haloEnabled) {
                settings.setHaloEnabled($0)
            }
            languageRow
            styleRow
            hoverRow
            if let error = settings.launchError {
                Text(error).font(.system(size: 10)).foregroundStyle(.orange)
            }
            Spacer(minLength: 0)
        }
    }

    private func fontChip(_ option: TimeFont) -> some View {
        let selected = settings.timeFont == option
        return VStack(spacing: 5) {
            Text("20:00")
                .font(option.font(size: 13))
                .foregroundStyle(.white)
            Text(option.label(t))
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(selected ? 0.9 : 0.45))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(.white.opacity(selected ? 0.14 : 0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(selected ? 0.5 : 0), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.snappy(duration: 0.25)) { settings.setTimeFont(option) } }
    }

    private func toggleRow(_ title: String, isOn: Bool, set: @escaping (Bool) -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 12))
            Spacer()
            Toggle("", isOn: Binding(get: { isOn }, set: set))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(height: 22)
    }

    /// Sélecteur de langue : pastilles Auto / FR / EN / ES / DE (le nom complet est en info-bulle).
    private var languageRow: some View {
        HStack {
            Text(t(.language)).font(.system(size: 12))
            Spacer()
            HStack(spacing: 4) {
                ForEach(AppLanguage.allCases) { option in
                    let selected = settings.language == option
                    Text(option == .system ? t(.languageAuto) : option.shortCode)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(selected ? 1 : 0.5))
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(.white.opacity(selected ? 0.18 : 0.06), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(selected ? 0.45 : 0), lineWidth: 1))
                        .contentShape(Capsule())
                        .help(option.nativeName)
                        .onTapGesture { withAnimation(.snappy(duration: 0.25)) { settings.setLanguage(option) } }
                }
            }
        }
        .frame(height: 24)
    }

    /// Fond du popup : verre liquide ou noir plein (comme le notch).
    private var styleRow: some View {
        HStack {
            Text(t(.popupStyle)).font(.system(size: 12))
            Spacer()
            HStack(spacing: 4) {
                ForEach(PopupStyle.allCases) { option in
                    let selected = settings.popupStyle == option
                    Text(option == .glass ? t(.styleGlass) : t(.styleBlack))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(selected ? 1 : 0.5))
                        .padding(.horizontal, 10)
                        .frame(height: 22)
                        .background(.white.opacity(selected ? 0.18 : 0.06), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(selected ? 0.45 : 0), lineWidth: 1))
                        .contentShape(Capsule())
                        .onTapGesture { withAnimation(.snappy(duration: 0.25)) { settings.setPopupStyle(option) } }
                }
            }
        }
        .frame(height: 24)
    }

    /// Survol du notch : Fixe (rien ne bouge) / Léger / Bouncy.
    private var hoverRow: some View {
        HStack {
            Text(t(.hoverStyle)).font(.system(size: 12))
            Spacer()
            HStack(spacing: 4) {
                ForEach(HoverStyle.allCases) { option in
                    let selected = settings.hoverStyle == option
                    Text(option == .off ? t(.hoverOff) : option == .subtle ? t(.hoverSubtle) : t(.hoverBouncy))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(selected ? 1 : 0.5))
                        .padding(.horizontal, 10)
                        .frame(height: 22)
                        .background(.white.opacity(selected ? 0.18 : 0.06), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(selected ? 0.45 : 0), lineWidth: 1))
                        .contentShape(Capsule())
                        .onTapGesture { withAnimation(.snappy(duration: 0.25)) { settings.setHoverStyle(option) } }
                }
            }
        }
        .frame(height: 24)
    }
}

/// Carte d'un univers, même style que les polices : une variante à la fois, une petite flèche au-dessus et une en
/// dessous de l'avatar pour passer à la précédente ou à la suivante (en boucle) — ce qui la choisit aussitôt. Un clic sur la carte choisit
/// la variante affichée.
private struct AvatarFamilyCard: View {
    let family: AvatarFamily
    let settings: AppSettings
    @State private var shown: AvatarCharacter?
    /// Sens du dernier changement : la nouvelle variante arrive par le bas (suivante) ou par le haut (précédente).
    @State private var forward = true

    private static let height: CGFloat = 58
    private var selected: Bool { settings.avatar.family == family }
    private var current: AvatarCharacter { shown ?? (selected ? settings.avatar : family.variants[0]) }

    var body: some View {
        VStack(spacing: 0) {
            arrow("chevron.compact.up", step: -1)
            page(current)
                .id(current)
                .transition(.push(from: forward ? .bottom : .top))
                .frame(height: Self.height)
                .clipped()
            arrow("chevron.compact.down", step: 1)
        }
        .frame(maxWidth: .infinity)
        .background(.white.opacity(selected ? 0.14 : 0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(selected ? 0.5 : 0), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { choose(current) }
    }

    /// Le personnage en taille notch, immobile, et son nom. Le duo, bien plus large, passe à l'échelle 1.
    private func page(_ option: AvatarCharacter) -> some View {
        let cast = option.repertoire
        let isCurrent = settings.avatar == option
        return VStack(spacing: 4) {
            AvatarCanvas(frame: cast.stand, scale: cast.points(CGFloat(cast.width) * cast.pixelScale > 24 ? 1 : 1.5), shadow: cast.shadow, overlay: cast.overlay, width: cast.width, height: cast.height)
            Text(option.name)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(isCurrent ? 0.9 : 0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
    }

    /// Flèche au-dessus ou en dessous de l'avatar ; invisible (place gardée) quand l'univers n'a qu'une variante,
    /// pour que toutes les cartes restent alignées.
    private func arrow(_ symbol: String, step: Int) -> some View {
        let active = family.variants.count > 1
        return Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(active ? 0.55 : 0))
            .frame(maxWidth: .infinity)
            .frame(height: 16)
            .contentShape(Rectangle())
            .onTapGesture { if active { move(step) } }
            .allowsHitTesting(active)
    }

    private func move(_ step: Int) {
        let variants = family.variants
        let index = variants.firstIndex(of: current) ?? 0
        let next = variants[(index + step + variants.count) % variants.count]
        forward = step > 0
        withAnimation(.snappy(duration: 0.3)) { shown = next }
        choose(next)
    }

    private func choose(_ variant: AvatarCharacter) {
        withAnimation(.snappy(duration: 0.25)) { settings.setAvatar(variant) }
    }
}
