import Foundation
import SwiftUI

// MARK: - Document Model
public struct Document: Identifiable, Codable {
    public var id: UUID
    public var title: String
    public var content: String
    public var createdAt: Date
    public var modifiedAt: Date
    
    public var wordCount: Int {
        content.split(separator: " ").count
    }
    
    public var characterCount: Int {
        content.count
    }
    
    public init(id: UUID = UUID(), title: String = "Untitled", content: String = "") {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

// MARK: - Theme Settings
public enum ThemeType: String, Codable {
    case light
    case dark
}

public struct DocumentSettings: Codable {
    public var fontSize: CGFloat
    public var fontName: String
    public var theme: ThemeType
    public var showWordCount: Bool
    public var showCharacterCount: Bool
    public var lastOpenedDocumentId: UUID?
    
    public init(fontSize: CGFloat = 16,
         fontName: String = "SF Pro",
         theme: ThemeType = .light,
         showWordCount: Bool = true,
         showCharacterCount: Bool = false,
         lastOpenedDocumentId: UUID? = nil) {
        self.fontSize = fontSize
        self.fontName = fontName
        self.theme = theme
        self.showWordCount = showWordCount
        self.showCharacterCount = showCharacterCount
        self.lastOpenedDocumentId = lastOpenedDocumentId
    }
    
    public static let `default` = DocumentSettings()
}

// MARK: - Export Format
public enum ExportFormat: String, Codable {
    case pdf
    case txt
    case rtf
}

// MARK: - Errors
public enum DocumentError: LocalizedError {
    case saveError
    case loadError
    case exportError
    
    public var errorDescription: String? {
        switch self {
        case .saveError:
            return "Failed to save document"
        case .loadError:
            return "Failed to load document"
        case .exportError:
            return "Failed to export document"
        }
    }
} 