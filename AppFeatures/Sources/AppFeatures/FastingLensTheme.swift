import SwiftUI

public enum FastingLensTheme {
    // MARK: - Core Palette

    public static let lavender = Color(hex: 0xF0F4FF)
    public static let snow = Color.white
    public static let flame = Color(hex: 0x3B82F6)
    public static let mint = Color(hex: 0x34D399)
    public static let lemon = Color(hex: 0x60A5FA)
    public static let ink = Color(hex: 0x1A1A2E)
    public static let slate = Color(hex: 0x6B7280)
    public static let cloud = Color(hex: 0xE2E8F0)
    public static let coral = Color(hex: 0xEF4444)
    public static let lime = Color(hex: 0xA3E635)

    // Legacy aliases
    public static let paper = lavender
    public static let sage = mint
    public static let tomato = flame
    public static let citron = lemon
    public static let fog = cloud
    public static let charcoal = ink.opacity(0.08)

    // MARK: - Gradients

    public static let flameGradient = LinearGradient(
        colors: [Color(hex: 0x3B82F6), Color(hex: 0x6366F1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let mintGradient = LinearGradient(
        colors: [Color(hex: 0x34D399), Color(hex: 0x6EE7B7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let lemonGradient = LinearGradient(
        colors: [Color(hex: 0x60A5FA), Color(hex: 0x93C5FD)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let cardGradient = LinearGradient(
        colors: [snow, lavender.opacity(0.5)],
        startPoint: .top,
        endPoint: .bottom
    )

    public static let limeGradient = LinearGradient(
        colors: [Color(hex: 0xA3E635), Color(hex: 0xD9F99D)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Corner Radii

    public static let cornerGrid: CGFloat = 24
    public static let cornerS: CGFloat = 14
    public static let cornerM: CGFloat = 20
    public static let cornerL: CGFloat = 28
    public static let cornerXL: CGFloat = 32
}

// MARK: - Shadow Modifiers

public extension View {
    func softShadow() -> some View {
        self.shadow(color: FastingLensTheme.ink.opacity(0.06), radius: 8, y: 3)
    }

    func cardShadow() -> some View {
        self.shadow(color: FastingLensTheme.ink.opacity(0.08), radius: 16, y: 6)
    }
}

// MARK: - Fonts

public extension Font {
    static let fastingHero = Font.system(size: 34, weight: .bold, design: .rounded)
    static let fastingDigits = Font.system(size: 28, weight: .heavy, design: .rounded).monospacedDigit()
    static let fastingLabel = Font.system(size: 13, weight: .semibold, design: .rounded)
    static let fastingSection = Font.system(size: 20, weight: .bold, design: .rounded)
    static let fastingBody = Font.system(size: 16, weight: .regular)
    static let fastingCaption = Font.system(size: 11, weight: .medium, design: .rounded)
}

// MARK: - Color Hex Init

private extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
