import Foundation

class DocumentManager {
    static let shared = DocumentManager()
    private let fileManager = FileManager.default
    
    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MoonMate", isDirectory: true)
    }
    
    private init() {
        createDocumentsDirectoryIfNeeded()
    }
    
    private func createDocumentsDirectoryIfNeeded() {
        do {
            try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        } catch {
            print("Error creating documents directory: \(error)")
        }
    }
    
    func saveDocument(_ document: Document) throws {
        let fileURL = documentsURL.appendingPathComponent("\(document.id.uuidString).json")
        let data = try JSONEncoder().encode(document)
        try data.write(to: fileURL)
    }
    
    func loadDocument(id: UUID) async throws -> Document {
        let fileURL = documentsURL.appendingPathComponent("\(id.uuidString).json")
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(Document.self, from: data)
    }
    
    func listDocuments() async throws -> [Document] {
        let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
        return try fileURLs.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Document.self, from: data)
        }
    }
    
    func deleteDocument(id: UUID) throws {
        let fileURL = documentsURL.appendingPathComponent("\(id.uuidString).json")
        try fileManager.removeItem(at: fileURL)
    }
    
    func exportDocument(_ document: Document, as format: ExportFormat, to url: URL) async throws {
        switch format {
        case .txt:
            try document.content.write(to: url, atomically: true, encoding: .utf8)
        case .rtf:
            throw DocumentError.exportError
        case .pdf:
            throw DocumentError.exportError
        }
    }
} 