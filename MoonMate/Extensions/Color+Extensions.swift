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
            self = Color(.windowBackgroundColor)
        case .editorText:
            // More dimmed white for better focus
            self = Color.white.opacity(0.75)
        case .secondaryText:
            // Even more dimmed for secondary elements
            self = Color.white.opacity(0.6)
        case .dimmedText:
            // Most dimmed for less important elements
            self = Color.white.opacity(0.45)
        }
    }
}

// Additional color utilities
extension Color {
    static func textColor(white: Double, alpha: Double) -> Color {
        return Color.white.opacity(alpha)
    }
    
    // Convenience static properties
    static let dimmedWhite = Color.white.opacity(0.75)
    static let moreDimmedWhite = Color.white.opacity(0.6)
    static let mostDimmedWhite = Color.white.opacity(0.45)
} 