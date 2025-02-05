import SwiftUI
import Foundation

@MainActor
class DocumentViewModel: ObservableObject {
    @Published var documents: [Document] = []
    @Published var selectedDocumentId: UUID?
    @Published var settings = DocumentSettings.default
    @Published var isSidebarVisible = true
    @Published var isChatSidebarVisible: Bool = false
    @Published var chatSidebarWidth: CGFloat = 300 // Default width
    @Published var selectedText: String = ""
    @Published var isEditing: Bool = false
    @Published var showingSidebar: Bool = false
    @Published var error: Error?
    
    private let fileManager = FileManager.default
    private let documentsURL: URL
    private let documentManager = DocumentManager.shared
    private let saveQueue = DispatchQueue(label: "com.moonmate.saveQueue")
    private var lastSaveDate = Date()
    private let autoSaveInterval: TimeInterval = 30 // seconds
    private let minChatSidebarWidth: CGFloat = 250
    private let maxChatSidebarWidth: CGFloat = 500
    
    var selectedDocument: Document? {
        documents.first { $0.id == selectedDocumentId }
    }
    
    var backgroundColor: Color {
        // Always return the dark background color since we're matching the previous setup
        return Color(red: 0.11, green: 0.11, blue: 0.12)
    }
    
    var textColor: Color {
        // Return the main text color
        return Color.white.opacity(0.87)
    }
    
    init() {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        documentsURL = paths[0].appendingPathComponent("MoonMate")
        
        try? fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        loadSettings()
        loadDocuments()
        
        // Set the selected document to the last opened one or the first available
        if let lastOpenedId = settings.lastOpenedDocumentId,
           documents.contains(where: { $0.id == lastOpenedId }) {
            selectedDocumentId = lastOpenedId
        } else {
            selectedDocumentId = documents.first?.id
        }
        
        setupAutoSave()
    }
    
    private func setupAutoSave() {
        Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            self?.autoSave()
        }
    }
    
    func autoSave() {
        guard Date().timeIntervalSince(lastSaveDate) >= autoSaveInterval else { return }
        saveDocuments()
        saveSettings()
    }
    
    func updateSelectedDocument(_ id: UUID?) {
        selectedDocumentId = id
        settings.lastOpenedDocumentId = id
        saveSettings()
    }
    
    func createNewDocument() {
        let newDocument = Document()
        documents.append(newDocument)
        selectedDocumentId = newDocument.id
        saveDocuments()
    }
    
    func updateTitle(_ newTitle: String) {
        guard var document = selectedDocument else { return }
        document.title = newTitle
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index] = document
            saveDocuments()
        }
    }
    
    func updateContent(_ newContent: String) {
        guard var document = selectedDocument else { return }
        document.content = newContent
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index] = document
            saveDocuments()
        }
    }
    
    func updateShowWordCount(_ show: Bool) {
        var updatedSettings = settings
        updatedSettings.showWordCount = show
        settings = updatedSettings
        saveSettings()
    }
    
    func updateShowCharacterCount(_ show: Bool) {
        var updatedSettings = settings
        updatedSettings.showCharacterCount = show
        settings = updatedSettings
        saveSettings()
    }
    
    func saveDocument() {
        saveDocuments()
    }
    
    func deleteDocument(_ document: Document) {
        documents.removeAll { $0.id == document.id }
        if selectedDocumentId == document.id {
            selectedDocumentId = documents.first?.id
        }
        saveDocuments()
    }
    
    func toggleSidebar() {
        isSidebarVisible.toggle()
        objectWillChange.send() // Force UI update
    }
    
    func toggleTheme() {
        settings.theme = settings.theme == .light ? .dark : .light
        saveSettings()
    }
    
    func updateChatSidebarWidth(_ width: CGFloat) {
        chatSidebarWidth = max(minChatSidebarWidth, min(width, maxChatSidebarWidth))
    }
    
    private func loadDocuments() {
        let decoder = JSONDecoder()
        let documentsFileURL = documentsURL.appendingPathComponent("documents.json")
        
        do {
            let data = try Data(contentsOf: documentsFileURL)
            documents = try decoder.decode([Document].self, from: data)
        } catch {
            print("Failed to load documents: \(error)")
            if documents.isEmpty {
                createNewDocument()
            }
        }
    }
    
    private func saveDocuments() {
        let encoder = JSONEncoder()
        let documentsFileURL = documentsURL.appendingPathComponent("documents.json")
        
        do {
            let data = try encoder.encode(documents)
            try data.write(to: documentsFileURL)
        } catch {
            print("Failed to save documents: \(error)")
        }
    }
    
    private func loadSettings() {
        let decoder = JSONDecoder()
        let settingsFileURL = documentsURL.appendingPathComponent("settings.json")
        
        do {
            let data = try Data(contentsOf: settingsFileURL)
            settings = try decoder.decode(DocumentSettings.self, from: data)
        } catch {
            print("Failed to load settings: \(error)")
            settings = .default
        }
    }
    
    private func saveSettings() {
        let encoder = JSONEncoder()
        let settingsFileURL = documentsURL.appendingPathComponent("settings.json")
        
        do {
            let data = try encoder.encode(settings)
            try data.write(to: settingsFileURL)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    func loadDocument(id: UUID) {
        Task {
            do {
                let loadedDocument = try await documentManager.loadDocument(id: id)
                await MainActor.run {
                    self.documents.append(loadedDocument)
                    self.selectedDocumentId = loadedDocument.id
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
    
    func exportDocument(as format: ExportFormat, to url: URL) {
        Task {
            do {
                try await documentManager.exportDocument(selectedDocument ?? Document(), as: format, to: url)
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
} 