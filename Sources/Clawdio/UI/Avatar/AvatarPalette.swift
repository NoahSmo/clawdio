/// Palette commune à tous les sprites de l'avatar et des badges. Une lettre = un ton ; `.` = transparent (voir `PixelGrid`).
/// Lumière zénithale : le dessus de la tête (vu d'en haut) est le plus clair, le bas du corps le plus sombre.
enum AvatarPalette {
    static let standard: [Character: PixelColor] = [
        "K": PixelColor(0x4A1E14),              // contour
        "H": PixelColor(0xF2A283),              // dessus de la tête, éclairé
        "O": PixelColor(0xD97757),              // orange Claude
        "S": PixelColor(0xA9503A),              // ombre propre (bas du corps, bras)
        "E": PixelColor(0x140B0A),              // yeux
        "s": PixelColor(0x000000, alpha: 0.28), // ombre portée au sol
        "Y": PixelColor(0xFFD37A),              // étincelles
        "W": PixelColor(0xFFFFFF),              // bulle, reflet
        "D": PixelColor(0x1E1E1E),              // texte dans une bulle claire
        "B": PixelColor(0xFF9A38),              // bulle d'alerte
        // Accessoires des activités
        "N": PixelColor(0x3E5C9A),              // couverture de livre
        "n": PixelColor(0x27396B),              // dos du livre
        "P": PixelColor(0xE6DAC4),              // pages, creux près du dos
        "L": PixelColor(0x9C8F7A),              // lignes de texte
        "G": PixelColor(0xA7B0BA),              // capot du laptop ; barre de titre du Terminal
        "g": PixelColor(0x5A626C),              // tranche du capot ; sortie du Terminal
        "Z": PixelColor(0x1B2330),              // fond du Terminal
        "l": PixelColor(0x9EC3D4),              // lumière de l'écran sur le visage
        "r": PixelColor(0xFF5F57),              // pastille rouge de la fenêtre Terminal
        "w": PixelColor(0xFFFFFF, alpha: 0.5),  // « z » du sommeil qui s'efface
        "R": PixelColor(0xE0284A),              // rubis
        "q": PixelColor(0xFF93A6),              // rubis, reflet
        "U": PixelColor(0x4F8FE0),              // océans du globe
        "V": PixelColor(0x5CBF6A),              // terres du globe
    ]
}
