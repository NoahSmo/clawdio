import Carbon.HIToolbox
import Foundation

/// Touche Échap globale, active seulement tant que le popup est ouvert.
///
/// Un `NSPanel` non activant ne reçoit pas le clavier (il ne doit pas voler le focus à l'app au premier plan), et un
/// moniteur global de touches (`addGlobalMonitorForEvents(.keyDown)`) exige la permission Accessibilité. Un raccourci
/// Carbon (`RegisterEventHotKey`) n'exige aucune permission. Il n'est enregistré que popup ouvert : Échap redevient
/// normal pour toutes les apps dès la fermeture.
@MainActor
final class EscapeHotKey {
    var onPress: (() -> Void)?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func register() {
        guard hotKey == nil else { return }
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let context = Unmanaged.passUnretained(self).toOpaque()
            InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
                guard let userData else { return noErr }
                let me = Unmanaged<EscapeHotKey>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in me.onPress?() }
                return noErr
            }, 1, &spec, context, &handler)
        }
        let id = EventHotKeyID(signature: OSType(0x434C_4449), id: 1) // 'CLDI'
        let status = RegisterEventHotKey(UInt32(kVK_Escape), 0, id, GetApplicationEventTarget(), 0, &hotKey)
        if ProcessInfo.processInfo.environment["CLAWDIO_TRACE"] != nil {
            try? "RegisterEventHotKey(Escape) -> OSStatus \(status) (0 = OK)\n".appendLine(to: "/tmp/clawdio_esc.log")
        }
    }

    func unregister() {
        guard let hotKey else { return }
        UnregisterEventHotKey(hotKey)
        self.hotKey = nil
    }
}

private extension String {
    func appendLine(to path: String) throws {
        let url = URL(fileURLWithPath: path)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try handle.write(contentsOf: Data(utf8))
        } else {
            try write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
