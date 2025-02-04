import SwiftUI

struct DocumentListView: View {
    @ObservedObject var viewModel: DocumentViewModel
    
    var body: some View {
        List(selection: $viewModel.selectedDocumentId) {
            ForEach(viewModel.documents) { document in
                DocumentRowView(document: document)
                    .tag(document.id)
                    .contextMenu {
                        Button(role: .destructive, action: {
                            viewModel.deleteDocument(document)
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200, maxWidth: 250)
        .toolbar {
            // Create (+) Button moved to primaryAction (right side)
            ToolbarItem(placement: .primaryAction) {
                Button(action: viewModel.createNewDocument) {
                    Label("New Document", systemImage: "plus")
                }
            }
            
            // Trash Can Button moved to after the create button
            ToolbarItem(placement: .primaryAction) {
                if let selectedDocument = viewModel.selectedDocument {
                    Button(role: .destructive, action: {
                        viewModel.deleteDocument(selectedDocument)
                    }) {
                        Label("Delete Document", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        }
    }
}

struct DocumentRowView: View {
    let document: Document
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(document.title)
                .font(.headline)
                .lineLimit(1)
            
            Text("\(document.wordCount) words")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}

#Preview {
    DocumentListView(viewModel: DocumentViewModel())
} 