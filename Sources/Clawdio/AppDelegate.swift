import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notch: NotchController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        PreferencesMigration.run() // avant toute lecture des préférences
        FontRegistry.registerBundledFonts()
        notch = NotchController()
    }
}
