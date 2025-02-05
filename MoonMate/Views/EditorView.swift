import SwiftUI

struct EditorView: View {
    @ObservedObject var viewModel: DocumentViewModel
    @FocusState private var isEditorFocused: Bool
    @FocusState private var isTitleFocused: Bool
    @State private var enterKeyCount: Int = 0
    @Environment(\.presentationMode) private var presentationMode
    @State private var isFullscreen: Bool = false
    @State private var sidebarVisibilityBeforeFullscreen: Bool = false
    @State private var selectedText: String = ""
    @State private var showFontSizeIndicator: Bool = false
    @State private var fontSizeIndicatorTimer: Timer?
    @Environment(\.scenePhase) private var scenePhase
    @State private var searchText: String = ""
    @State private var isSearchVisible: Bool = false
    
    // Add a new property to track window state
    @State private var windowState: WindowState = .normal
    
    // Reference to text editor coordinator for search operations
    @State private var textEditorCoordinator: CustomTextEditor.Coordinator?

    enum WindowState {
        case normal
        case fullscreen
    }

    var body: some View {
        NavigationSplitView(
            columnVisibility: Binding(
                get: { 
                    isFullscreen ? .detailOnly : viewModel.isSidebarVisible ? .all : .detailOnly
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
                    if isSearchVisible {
                        SearchBarView(
                            searchText: $searchText,
                            isVisible: $isSearchVisible,
                            onNext: {
                                textEditorCoordinator?.findNext()
                            },
                            onPrevious: {
                                textEditorCoordinator?.findPrevious()
                            },
                            onClose: {
                                isSearchVisible = false
                                searchText = ""
                            }
                        )
                    }
                    
                    HStack(spacing: 0) {
                        VStack(spacing: 0) {
                            if isFullscreen {
                                Spacer()
                                    .frame(height: 40)
                            } else {
                                Spacer()
                                    .frame(height: 20)
                            }
                            
                            // Title Field with Chat Toggle
                            HStack {
                                // Left spacer (equal width to right side)
                                HStack {
                                    Spacer()
                                }
                                .frame(width: 100)
                                
                                // Center title
                                TextField("Title", text: Binding(
                                    get: { document.title },
                                    set: { viewModel.updateTitle($0) }
                                ))
                                .font(.title)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.center)
                                .focused($isTitleFocused)
                                .frame(maxWidth: 500)
                                .foregroundColor(Color(uiModel: .editorText))
                                .onSubmit {
                                    enterKeyCount += 1
                                    if enterKeyCount >= 2 {
                                        isTitleFocused = false
                                        isEditorFocused = true
                                        enterKeyCount = 0
                                    }
                                }
                                
                                // Right side with chat toggle (fixed width for balance)
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        withAnimation {
                                            viewModel.isChatSidebarVisible.toggle()
                                        }
                                    }) {
                                        Image(systemName: viewModel.isChatSidebarVisible ? "message.fill" : "message")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 18))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(8)
                                    .background(Color(.separatorColor).opacity(0.1))
                                    .cornerRadius(6)
                                }
                                .frame(width: 100)
                            }
                            .padding(.vertical, 20)
                            .padding(.horizontal)
                            .padding(.top, isFullscreen ? 20 : 0)
                            
                            // Content Area
                            ZStack {
                                HStack {
                                    Spacer()
                                    CustomTextEditor(
                                        text: Binding(
                                            get: { document.content },
                                            set: { viewModel.updateContent($0) }
                                        ),
                                        selectedText: $selectedText,
                                        font: .systemFont(ofSize: viewModel.settings.fontSize),
                                        searchText: $searchText,
                                        isSearchVisible: $isSearchVisible,
                                        onCoordinatorCreated: { coordinator in
                                            textEditorCoordinator = coordinator
                                        }
                                    )
                                    .focused($isEditorFocused)
                                    .frame(maxWidth: 750)
                                    .onChange(of: selectedText) { newSelection in
                                        if !newSelection.isEmpty && !viewModel.isChatSidebarVisible {
                                            withAnimation {
                                                viewModel.isChatSidebarVisible = true
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .background(Color(uiModel: .windowBackground))
                                
                                if showFontSizeIndicator {
                                    VStack {
                                        Spacer()
                                        FontSizeIndicatorView(fontSize: viewModel.settings.fontSize, isVisible: $showFontSizeIndicator)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.vertical)
                            
                            // Status Bar
                            if !isFullscreen {
                                HStack {
                                    if viewModel.settings.showWordCount {
                                        Text("\(document.wordCount) words")
                                            .foregroundColor(Color(uiModel: .dimmedText))
                                    }
                                    if viewModel.settings.showCharacterCount {
                                        Text("\(document.characterCount) characters")
                                            .foregroundColor(Color(uiModel: .dimmedText))
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color(.separatorColor).opacity(0.1))
                            }
                        }
                        
                        // Chat Sidebar
                        if viewModel.isChatSidebarVisible {
                            ChatSidebarView(
                                isVisible: $viewModel.isChatSidebarVisible,
                                viewModel: viewModel,
                                selectedText: selectedText
                            )
                            .transition(.move(edge: .trailing))
                        }
                    }
                }
            } else {
                Text("Select or create a document")
                    .foregroundColor(Color(uiModel: .secondaryText))
            }
        }
        .toolbar(isFullscreen ? .hidden : .visible)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
            sidebarVisibilityBeforeFullscreen = viewModel.isSidebarVisible
            isFullscreen = true
            windowState = .fullscreen
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullscreen = false
            windowState = .normal
            viewModel.isSidebarVisible = sidebarVisibilityBeforeFullscreen
        }
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) {
                    if event.characters == "+" || event.characters == "=" {
                        increaseFontSize()
                        return nil
                    } else if event.characters == "-" {
                        decreaseFontSize()
                        return nil
                    } else if event.characters == "f" {
                        withAnimation {
                            isSearchVisible.toggle()
                            if !isSearchVisible {
                                searchText = ""
                            }
                        }
                        return nil
                    }
                }
                return event
            }
        }
    }
    
    private func showFontSizeIndicatorBriefly() {
        showFontSizeIndicator = true
        fontSizeIndicatorTimer?.invalidate()
        fontSizeIndicatorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            withAnimation {
                showFontSizeIndicator = false
            }
        }
    }
    
    private func increaseFontSize() {
        viewModel.settings.fontSize = min(viewModel.settings.fontSize + 1, 72)
        showFontSizeIndicatorBriefly()
    }
    
    private func decreaseFontSize() {
        viewModel.settings.fontSize = max(viewModel.settings.fontSize - 1, 8)
        showFontSizeIndicatorBriefly()
    }
}

#Preview {
    EditorView(viewModel: DocumentViewModel())
} 