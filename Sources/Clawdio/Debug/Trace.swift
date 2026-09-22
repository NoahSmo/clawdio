import AppKit
import CoreGraphics

/// Outil de mesure (CLAWDIO_TRACE=1) : capture la fenêtre du notch en boucle (une app peut capturer ses propres
/// fenêtres sans permission "Enregistrement d'écran") et écrit dans /tmp/clawdio_trace.log la taille de la forme
/// dessinée (bbox des pixels non transparents) à chaque image. Sert à vérifier la courbe réelle de l'animation.
@MainActor
enum Trace {
    static var enabled: Bool { ProcessInfo.processInfo.environment["CLAWDIO_TRACE"] != nil }

    /// La capture et l'analyse tournent HORS du thread principal : sur le thread principal elles retardaient
    /// l'animation mesurée (paliers artificiels dans la courbe).
    static func record(window: NSWindow, duration: Double, label: String, dumpEveryMs: Double = 0) {
        let id = CGWindowID(window.windowNumber)
        let scale = window.backingScaleFactor
        Task.detached(priority: .userInitiated) {
            let start = CFAbsoluteTimeGetCurrent()
            var lines: [String] = ["# \(label) — t(ms)  largeur×hauteur (pt)  x0  y1"]
            var n = 0
            var lastDump = -1e9
            try? FileManager.default.createDirectory(atPath: "/tmp/clawdio_frames", withIntermediateDirectories: true)
            while CFAbsoluteTimeGetCurrent() - start < duration {
                if let image = CGWindowListCreateImage(.null, .optionIncludingWindow, id, [.boundsIgnoreFraming]) {
                    let t = (CFAbsoluteTimeGetCurrent() - start) * 1000
                    lines.append(String(format: "%6.0f  %@", t, bbox(of: image, scale: scale)))
                    n += 1
                    if dumpEveryMs > 0 ? (t - lastDump >= dumpEveryMs) : (t < 420 && n % 2 == 0) {
                        lastDump = t
                        try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?
                            .write(to: URL(fileURLWithPath: String(format: "/tmp/clawdio_frames/f_%04.0f.png", t)))
                    }
                }
            }
            try? lines.joined(separator: "\n").appending("\n").write(toFile: "/tmp/clawdio_trace.log", atomically: true, encoding: .utf8)
        }
    }

    /// Boîte englobante des pixels non transparents, en points.
    nonisolated private static func bbox(of image: CGImage, scale: CGFloat) -> String {
        let w = image.width, h = image.height
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data else { return "?" }
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var minX = w, maxX = -1, maxY = -1
        for y in stride(from: 0, to: h, by: 3) {
            var rowHit = false
            for x in stride(from: 0, to: w, by: 3) where px[(y * w + x) * 4 + 3] > 60 {
                rowHit = true
                if x < minX { minX = x }
                if x > maxX { maxX = x }
            }
            if rowHit { maxY = y }
        }
        guard maxX >= 0 else { return "vide" }
        let s = Double(scale)
        return String(format: "%4.0f x %4.0f   x0=%4.0f  y1=%4.0f", Double(maxX - minX) / s, Double(maxY) / s, Double(minX) / s, Double(maxY) / s)
    }
}
