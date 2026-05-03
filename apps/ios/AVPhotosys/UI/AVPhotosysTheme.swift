import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

final class AppThemeController: ObservableObject {
    @Published private(set) var currentTheme: AppTheme

    private let userDefaults: UserDefaults
    private let userDefaultsKey = "avphotosys.appTheme"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        currentTheme = AppTheme(rawValue: userDefaults.string(forKey: userDefaultsKey) ?? "") ?? .system
    }

    func select(_ theme: AppTheme) {
        guard currentTheme != theme else { return }
        currentTheme = theme
        userDefaults.set(theme.rawValue, forKey: userDefaultsKey)
    }
}

enum AVPhotosysTheme {
    static let brandBlack = Color(red: 13 / 255, green: 13 / 255, blue: 13 / 255)
    static let brandGreen = Color(red: 57 / 255, green: 181 / 255, blue: 74 / 255)
    static let brandGraphite = Color(red: 42 / 255, green: 42 / 255, blue: 42 / 255)
    static let brandWhite = Color.white

    static let highlight = brandGreen
    static let warning = Color(red: 210 / 255, green: 112 / 255, blue: 37 / 255)
    static let textPrimary = dynamicColor(
        light: UIColor(red: 13 / 255, green: 13 / 255, blue: 13 / 255, alpha: 1),
        dark: UIColor(red: 242 / 255, green: 245 / 255, blue: 243 / 255, alpha: 1)
    )
    static let textSecondary = dynamicColor(
        light: UIColor(red: 95 / 255, green: 104 / 255, blue: 98 / 255, alpha: 1),
        dark: UIColor(red: 161 / 255, green: 170 / 255, blue: 165 / 255, alpha: 1)
    )
    static let textInverse = brandWhite
    static let cardSurface = dynamicColor(
        light: UIColor(red: 251 / 255, green: 252 / 255, blue: 251 / 255, alpha: 1),
        dark: UIColor(red: 30 / 255, green: 34 / 255, blue: 31 / 255, alpha: 1)
    )
    static let mutedSurface = dynamicColor(
        light: UIColor(red: 238 / 255, green: 242 / 255, blue: 239 / 255, alpha: 1),
        dark: UIColor(red: 42 / 255, green: 46 / 255, blue: 43 / 255, alpha: 1)
    )
    static let borderSubtle = dynamicColor(
        light: UIColor(red: 200 / 255, green: 209 / 255, blue: 203 / 255, alpha: 1),
        dark: UIColor(red: 72 / 255, green: 79 / 255, blue: 74 / 255, alpha: 1)
    )
    static let borderStrong = dynamicColor(
        light: UIColor(red: 149 / 255, green: 159 / 255, blue: 152 / 255, alpha: 1),
        dark: UIColor(red: 108 / 255, green: 116 / 255, blue: 111 / 255, alpha: 1)
    )

    static let shellBackground = LinearGradient(
        colors: [
            dynamicColor(
                light: UIColor.white,
                dark: UIColor(red: 11 / 255, green: 13 / 255, blue: 12 / 255, alpha: 1)
            ),
            dynamicColor(
                light: UIColor(red: 247 / 255, green: 249 / 255, blue: 248 / 255, alpha: 1),
                dark: UIColor(red: 18 / 255, green: 22 / 255, blue: 20 / 255, alpha: 1)
            ),
            dynamicColor(
                light: UIColor(red: 238 / 255, green: 242 / 255, blue: 239 / 255, alpha: 1),
                dark: UIColor(red: 24 / 255, green: 29 / 255, blue: 26 / 255, alpha: 1)
            )
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let onboardingBackground = LinearGradient(
        colors: [brandBlack, brandGraphite],
        startPoint: .top,
        endPoint: .bottom
    )

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}
