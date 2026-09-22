import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared

    #if DEBUG
    if let flag = CommandLine.arguments.firstIndex(of: "--export-sprites"), flag + 1 < CommandLine.arguments.count {
        SpriteExport.run(to: CommandLine.arguments[flag + 1])
        exit(0)
    }
    if let flag = CommandLine.arguments.firstIndex(of: "--snapshot"), flag + 1 < CommandLine.arguments.count {
        let directory = CommandLine.arguments[flag + 1]
        Task { @MainActor in
            await Snapshot.run(outputDirectory: directory)
            exit(0)
        }
        app.run()
    }
    #endif

    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory) // pas d'icône Dock, pas de menu bar propre
    app.run() // bloque ; `delegate` reste vivant tant que run() tourne
}
