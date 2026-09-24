import CoreText
import Foundation
import Observation
import ServiceManagement
import SwiftUI

/// Police de l'heure de reset affichée à droite du donut.
enum TimeFont: String, CaseIterable, Identifiable {
    case minecraft, system, mono

    var id: String { rawValue }

    func label(_ t: Strings) -> String {
        switch self {
        case .minecraft: t(.fontMinecraft)
        case .system: t(.fontSystem)
        case .mono: t(.fontMono)
        }
    }

    func font(size: CGFloat) -> Font {
        switch self {
        case .minecraft: .custom("Monocraft-Bold", size: size)
        case .system: .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
        case .mono: .system(size: size, weight: .semibold, design: .monospaced)
        }
    }
}

/// Comportement de la pastille au survol.
enum HoverStyle: String, CaseIterable, Identifiable {
    case off      // la pastille ne bouge pas (Clawd fait juste un petit saut)
    case subtle   // léger grossissement, sans rebond
    case bouncy   // grossissement marqué avec rebond

    var id: String { rawValue }

    var grow: CGSize {
        switch self {
        case .off: .zero
        case .subtle: CGSize(width: 10, height: 2)
        case .bouncy: NotchGeometry.maxHoverGrow
        }
    }
}

/// Matière du fond du popup.
enum PopupStyle: String, CaseIterable, Identifiable {
    case glass, black
    var id: String { rawValue }
}

/// Préférences de l'app (UserDefaults).
@MainActor @Observable
final class AppSettings {
    private(set) var timeFont: TimeFont
    private(set) var language: AppLanguage
    private(set) var popupStyle: PopupStyle
    private(set) var hoverStyle: HoverStyle
    /// Personnage de l'avatar (notch et popup).
    private(set) var avatar: AvatarCharacter
    /// Halo autour du notch (au lancement et tant qu'un agent attend).
    private(set) var haloEnabled: Bool
    private(set) var launchAtLogin: Bool
    private(set) var launchError: String?

    init() {
        let stored = UserDefaults.standard.string(forKey: "clawdio.timeFont")
        timeFont = stored.flatMap(TimeFont.init(rawValue:)) ?? .minecraft
        language = UserDefaults.standard.string(forKey: "clawdio.language").flatMap(AppLanguage.init(rawValue:)) ?? .system
        popupStyle = UserDefaults.standard.string(forKey: "clawdio.popupStyle").flatMap(PopupStyle.init(rawValue:)) ?? .glass
        hoverStyle = UserDefaults.standard.string(forKey: "clawdio.hoverStyle").flatMap(HoverStyle.init(rawValue:)) ?? .off
        avatar = UserDefaults.standard.string(forKey: "clawdio.avatar").flatMap(AvatarCharacter.init(rawValue:)) ?? .clawd
        haloEnabled = UserDefaults.standard.object(forKey: "clawdio.halo") as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled
        Fmt.locale = language.locale
    }

    func setHaloEnabled(_ enabled: Bool) {
        haloEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "clawdio.halo")
    }

    func setAvatar(_ character: AvatarCharacter) {
        avatar = character
        UserDefaults.standard.set(character.rawValue, forKey: "clawdio.avatar")
    }

    func setHoverStyle(_ style: HoverStyle) {
        hoverStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: "clawdio.hoverStyle")
    }

    func setPopupStyle(_ style: PopupStyle) {
        popupStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: "clawdio.popupStyle")
    }

    /// Chaînes de l'interface dans la langue choisie. Lue dans `body` : SwiftUI redessine au changement.
    var t: Strings { Strings(language) }

    func setLanguage(_ newValue: AppLanguage) {
        // `Fmt.locale` d'abord : les vues qui se redessinent formatent déjà avec la nouvelle langue.
        Fmt.locale = newValue.locale
        language = newValue
        UserDefaults.standard.set(newValue.rawValue, forKey: "clawdio.language")
    }

    func setTimeFont(_ font: TimeFont) {
        timeFont = font
        UserDefaults.standard.set(font.rawValue, forKey: "clawdio.timeFont")
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchError = nil
        } catch {
            launchError = Strings(language)(.launchError)
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

/// Enregistre les polices embarquées (Monocraft, licence OFL) pour ce processus.
enum FontRegistry {
    static func registerBundledFonts() {
        var folders: [URL] = []
        if let resources = Bundle.main.resourceURL { folders.append(resources.appending(path: "Fonts")) }
        #if DEBUG
        // `swift run` / snapshots : pas de bundle .app, on lit le dossier du dépôt.
        folders.append(URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appending(path: "Resources/Fonts"))
        #endif

        for folder in folders {
            guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { continue }
            for url in files where ["ttf", "ttc", "otf"].contains(url.pathExtension.lowercased()) {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) // erreur "déjà enregistrée" sans conséquence
            }
        }
    }
}

/// L'app s'appelait Claudio (`dev.claudio.notch`, clés `claudio.*`). Au premier lancement de Clawdio, reprend ses
/// préférences et le dernier quota connu, une seule fois. Rien n'est supprimé côté ancienne app.
enum PreferencesMigration {
    private static let doneKey = "clawdio.migratedFromClaudio"

    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        defer { defaults.set(true, forKey: doneKey) }
        guard let old = UserDefaults(suiteName: "dev.claudio.notch")?.persistentDomain(forName: "dev.claudio.notch") else { return }
        for (key, value) in old where key.hasPrefix("claudio.") {
            let renamed = "clawdio." + key.dropFirst("claudio.".count)
            if defaults.object(forKey: renamed) == nil { defaults.set(value, forKey: renamed) }
        }
    }
}
