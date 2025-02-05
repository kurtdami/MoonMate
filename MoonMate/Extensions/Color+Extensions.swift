import SwiftUI

// Color model for our UI
enum UIColorModel {
    case windowBackground
    case editorText
    case secondaryText
    case dimmedText
}

extension Color {
    init(uiModel: UIColorModel) {
        switch uiModel {
        case .windowBackground:
            // Dark background color
            self = Color(red: 0.11, green: 0.11, blue: 0.12)
        case .editorText:
            // Bright white text with slight dimming
            self = Color.white.opacity(0.87)
        case .secondaryText:
            // More dimmed white for secondary elements
            self = Color.white.opacity(0.7)
        case .dimmedText:
            // Most dimmed for less important elements
            self = Color.white.opacity(0.5)
        }
    }
}

// Additional color utilities
extension Color {
    static func textColor(white: Double, alpha: Double) -> Color {
        return Color.white.opacity(alpha)
    }
    
    // Convenience static properties with adjusted opacities
    static let dimmedWhite = Color.white.opacity(0.87)
    static let moreDimmedWhite = Color.white.opacity(0.7)
    static let mostDimmedWhite = Color.white.opacity(0.5)
} 