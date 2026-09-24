#if DEBUG
import AppKit
import SwiftUI

/// `Clawdio --snapshot <dossier>` : rend chaque état de la pastille en PNG (vraies données)
/// puis quitte. Sert à vérifier l'UI sans permission "Enregistrement d'écran". Debug uniquement.
/// (`ImageRenderer` ne rend pas le Liquid Glass : le fond est un aplat sombre dans ces captures.)
@MainActor
enum Snapshot {
    static func run(outputDirectory: String) async {
        guard let screen = NotchGeometry.preferredScreen() else { return print("aucun écran") }
        Reveal.instant = true
        FontRegistry.registerBundledFonts()
        let settings = AppSettings()

        let usage = UsageModel()
        let local = LocalUsageStore()
        await usage.refresh()
        await local.refresh()
        print("quota:", usage.snapshot?.rows.map { "\($0.title)=\($0.percent)" } ?? [], "error:", usage.error?.errorDescription ?? "none")
        if let stats = local.stats {
            print("30 j: coût \(Fmt.dollars(stats.periodCost)), tokens \(Fmt.tokens(Double(stats.periodTokens)))")
            for m in stats.models { print("  \(m.model): \(Fmt.dollars(m.cost)) · \(Fmt.tokens(Double(m.tokens))) tokens, sortie \(Fmt.tokens(Double(m.output)))") }
            for d in stats.dayTotals { print("  \(d.day.formatted(.dateTime.month().day())): \(Fmt.dollars(d.cost))") }
        } else {
            print("stats: nil")
        }

        // Planche contact de chaque avatar : tailles réelles (notch ×1, popup ×2), puis chaque clip image par image (×6).
        for character in AvatarCharacter.allCases {
            writeSheet(character, to: outputDirectory)
        }

        let sessions = SessionStore()
        // Captures publiées (README) : données d'exemple, jamais les vraies (voir scripts/make-screenshot.sh).
        let demo = ProcessInfo.processInfo.environment["CLAWDIO_DEMO"] != nil
        if demo {
            DemoData.fill(usage: usage, local: local, sessions: sessions, settings: settings)
        } else {
            await sessions.poll()
        }
        print("sessions:", sessions.sessions.map { "\($0.title) [\($0.state)]" })

        var snapshotGeometry = NotchGeometry(screen: screen)
        snapshotGeometry.hoverGrow = HoverStyle.bouncy.grow
        let state = NotchState(geometry: snapshotGeometry)
        try? FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

        // (nom, mode, page, besoin forcé)
        let shots: [(String, NotchMode, PopupPage, AgentState?)] = demo ? [
            ("demo-collapsed", .collapsed, .stats, .waitingReply),
            ("demo-expanded", .expanded, .stats, .waitingReply),
            ("demo-history", .expanded, .history, .waitingReply),
        ] : [
            ("collapsed-idle", .collapsed, .stats, .idle),
            ("collapsed-reply", .collapsed, .stats, .waitingReply),
            ("collapsed-approval", .collapsed, .stats, .needsApproval),
            ("collapsed-working", .collapsed, .stats, .working),
            ("hovered", .hovered, .stats, .waitingReply),
            ("expanded-stats", .expanded, .stats, .waitingReply),
            ("expanded-history", .expanded, .history, .waitingReply),
            ("expanded-settings", .expanded, .settings, .waitingReply),
            ("expanded-charthover", .expanded, .stats, .waitingReply),
        ]
        for (name, mode, page, need) in shots {
            sessions.forcedHeadline = need
            state.setHovering(mode == .hovered)
            state.setExpanded(mode == .expanded)
            state.page = page
            state.setHoveredDay(name == "expanded-charthover" ? 9 : nil)
            let size = state.geometry.size(for: mode, rows: usage.rowCount)
            let content = NotchRootView(usage: usage, local: local, sessions: sessions, settings: settings, state: state)
                .frame(width: size.width + 40, height: size.height + 20, alignment: .top)
                .background(demo ? Color(red: 0.094, green: 0.094, blue: 0.106) : Color(white: 0.4))
            let renderer = ImageRenderer(content: content)
            renderer.scale = 3
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
            else { print("échec rendu \(name)"); continue }
            try? png.write(to: URL(fileURLWithPath: "\(outputDirectory)/\(name).png"))
            print("écrit", name, "(\(Int(size.width))×\(Int(size.height)) pt)")
        }

        if demo { print("captures de démo écrites"); return }

        // Chaque activité dans le vrai notch (×1) et dans le popup (×2) : l'accessoire tient-il la place ?
        sessions.forcedHeadline = .working
        // Le repli est asynchrone (`isClosing`) : pour les captures repliées, un état neuf, jamais ouvert.
        for (suffix, expanded) in [("collapsed", false), ("expanded", true)] {
            for tool in ["Read", "Edit", "Bash", "WebSearch", "Task", "TodoWrite"] {
                sessions.forcedTool = tool
                let shotState = expanded ? state : NotchState(geometry: snapshotGeometry)
                shotState.setHovering(false)
                shotState.setExpanded(expanded)
                shotState.page = .stats
                let size = shotState.geometry.size(for: expanded ? .expanded : .collapsed, rows: usage.rowCount)
                let content = NotchRootView(usage: usage, local: local, sessions: sessions, settings: settings, state: shotState)
                    .frame(width: size.width + 40, height: size.height + 20, alignment: .top)
                    .background(Color(white: 0.4))
                let renderer = ImageRenderer(content: content)
                renderer.scale = 3
                if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                   let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: "\(outputDirectory)/activity-\(tool)-\(suffix).png"))
                    print("écrit activity-\(tool)-\(suffix)")
                }
            }
        }
        sessions.forcedTool = nil

        // Autres langues : le popup et les paramètres
        for language in [AppLanguage.en, .de, .es] {
            settings.setLanguage(language)
            sessions.forcedHeadline = .waitingReply
            for (suffix, page) in [("stats", PopupPage.stats), ("settings", PopupPage.settings)] {
                state.setHovering(false)
                state.setExpanded(true)
                state.page = page
                state.setHoveredDay(nil)
                let size = state.geometry.size(for: .expanded, rows: usage.rowCount)
                let content = NotchRootView(usage: usage, local: local, sessions: sessions, settings: settings, state: state)
                    .frame(width: size.width + 40, height: size.height + 20, alignment: .top)
                    .background(Color(white: 0.4))
                let renderer = ImageRenderer(content: content)
                renderer.scale = 2
                if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                   let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: "\(outputDirectory)/lang-\(language.rawValue)-\(suffix).png"))
                    print("écrit lang-\(language.rawValue)-\(suffix)")
                }
            }
        }
        // Mise en page dans la fenêtre RÉELLE (528 × 450, taille fixe) : où se place la pastille ?
        do {
            settings.setPopupStyle(.black)
            sessions.forcedHeadline = .waitingReply
            for (name, warm) in [("window-collapsed", false), ("window-collapsed-warm", true)] {
                state.setExpanded(false)
                state.setHovering(false)
                state.setWarm(warm)
                let content = NotchRootView(usage: usage, local: local, sessions: sessions, settings: settings, state: state)
                    .frame(width: 528, height: 450, alignment: .topLeading)
                    .background(Color(white: 0.3))
                let renderer = ImageRenderer(content: content)
                renderer.scale = 1
                if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                   let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: "\(outputDirectory)/\(name).png"))
                    print("écrit", name)
                }
            }
            state.setWarm(false)
            settings.setPopupStyle(.glass)
        }

        // Style "Noir"
        settings.setLanguage(.system)
        settings.setPopupStyle(.black)
        sessions.forcedHeadline = .working
        state.setHovering(false)
        state.setExpanded(true)
        state.page = .stats
        do {
            let size = state.geometry.size(for: .expanded, rows: usage.rowCount)
            let content = NotchRootView(usage: usage, local: local, sessions: sessions, settings: settings, state: state)
                .frame(width: size.width + 40, height: size.height + 20, alignment: .top)
                .background(Color(white: 0.4))
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: "\(outputDirectory)/style-black.png"))
                print("écrit style-black")
            }
        }
        settings.setPopupStyle(.glass)
    }

    private static func writeSheet(_ character: AvatarCharacter, to outputDirectory: String) {
        let cast = character.repertoire
        let label = { (text: String) in Text(text).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5)) }
        let sheet = VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .bottom, spacing: 30) {
                label("taille réelle").frame(width: 90, alignment: .leading)
                AvatarCanvas(frame: cast.stand, scale: 1, shadow: cast.shadow, overlay: cast.overlay, width: cast.width, height: cast.height)
                AvatarCanvas(frame: cast.stand, scale: 2, shadow: cast.shadow, overlay: cast.overlay, width: cast.width, height: cast.height)
                AvatarCanvas(frame: cast.stand, scale: 6, shadow: cast.shadow, overlay: cast.overlay, width: cast.width, height: cast.height)
            }
            HStack(alignment: .bottom, spacing: 14) {
                label("repos").frame(width: 90, alignment: .leading)
                ForEach(AvatarMood.gallery, id: \.self) { mood in
                    VStack(spacing: 6) {
                        AvatarCanvas(frame: cast.rest(mood), scale: 6, shadow: cast.shadow, overlay: cast.overlay, width: cast.width, height: cast.height)
                        label(mood.label)
                    }
                }
            }
            ForEach(cast.allClips, id: \.name) { clip in
                HStack(alignment: .bottom, spacing: 14) {
                    label("\(clip.name)\n\(clip.fps.formatted()) i/s · \(clip.duration.formatted(.number.precision(.fractionLength(2)))) s")
                        .frame(width: 90, alignment: .leading)
                    ForEach(Array(clip.frames.enumerated()), id: \.offset) { i, frame in
                        VStack(spacing: 6) {
                            AvatarCanvas(frame: frame, scale: 6, shadow: cast.shadow, overlay: cast.overlay, width: cast.width, height: cast.height).padding(.top, 20) // place pour les sauts
                            label("\(i) ×\(frame.hold)")
                        }
                    }
                }
            }
        }
        .padding(30)
        .background(Color(white: 0.12))
        .environment(\.colorScheme, .dark)
        let sheetRenderer = ImageRenderer(content: sheet)
        sheetRenderer.scale = 2
        if let image = sheetRenderer.nsImage, let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
            try? png.write(to: URL(fileURLWithPath: "\(outputDirectory)/avatar-sheet-\(character.rawValue).png"))
            print("écrit avatar-sheet-\(character.rawValue)")
        }
    }
}
#endif
