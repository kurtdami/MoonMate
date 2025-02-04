import SwiftUI

struct EditorView: View {
    @ObservedObject var viewModel: DocumentViewModel
    @FocusState private var isEditorFocused: Bool
    @FocusState private var isTitleFocused: Bool
    @State private var enterKeyCount: Int = 0
    @Environment(\.presentationMode) private var presentationMode
    @State private var isFullscreen: Bool = false
    @State private var sidebarVisibilityBeforeFullscreen: Bool = false
    
    var body: some View {
        NavigationSplitView(
            columnVisibility: Binding(
                get: { 
                    isFullscreen ? .detailOnly : 
                    (viewModel.isSidebarVisible ? .all : .detailOnly)
                },
                set: { newValue in
                    if !isFullscreen {
                        viewModel.isSidebarVisible = (newValue == .all)
                    }
                }
            )
        ) {
            if !isFullscreen && viewModel.isSidebarVisible {
                DocumentListView(viewModel: viewModel)
                    .onChange(of: viewModel.selectedDocumentId) { id in
                        viewModel.updateSelectedDocument(id)
                    }
            }
        } detail: {
            if let document = viewModel.selectedDocument {
                VStack(spacing: 0) {
                    if isFullscreen {
                        Spacer()
                            .frame(height: 40)
                    }
                    
                    // Title Field
                    TextField("Title", text: Binding(
                        get: { document.title },
                        set: { viewModel.updateTitle($0) }
                    ))
                    .font(.title)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .focused($isTitleFocused)
                    .padding(.vertical, 20)
                    .padding(.horizontal)
                    .padding(.top, isFullscreen ? 20 : 0)
                    .onSubmit {
                        enterKeyCount += 1
                        if enterKeyCount >= 2 {
                            isTitleFocused = false
                            isEditorFocused = true
                            enterKeyCount = 0
                        }
                    }
                    
                    // Content Area
                    TextEditor(text: Binding(
                        get: { document.content },
                        set: { viewModel.updateContent($0) }
                    ))
                    .font(.system(size: viewModel.settings.fontSize))
                    .focused($isEditorFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(maxWidth: 750)
                    .padding(.horizontal, 80)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    
                    // Status Bar
                    if !isFullscreen {
                        HStack {
                            if viewModel.settings.showWordCount {
                                Text("\(document.wordCount) words")
                                    .foregroundColor(.secondary)
                            }
                            if viewModel.settings.showCharacterCount {
                                Text("\(document.characterCount) characters")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.separatorColor).opacity(0.1))
                    }
                }
            } else {
                Text("Select or create a document")
                    .foregroundColor(.secondary)
            }
        }
        .toolbar(isFullscreen ? .hidden : .visible)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
            sidebarVisibilityBeforeFullscreen = viewModel.isSidebarVisible
            isFullscreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullscreen = false
            viewModel.isSidebarVisible = sidebarVisibilityBeforeFullscreen
        }
    }
}

#Preview {
    EditorView(viewModel: DocumentViewModel())
} 