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
    
    // Add a new property to track window state
    @State private var windowState: WindowState = .normal

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
                    .onChange(of: viewModel.selectedDocumentId) { oldValue, id in
                        viewModel.updateSelectedDocument(id)
                    }
            }
        } detail: {
            if let document = viewModel.selectedDocument {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ScrollView(.vertical, showsIndicators: true) {
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

                                    // Right side with chat toggle
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
                                    VStack(spacing: 0) {
                                        SwiftUITextEditor(
                                            text: Binding(
                                                get: { document.content },
                                                set: { viewModel.updateContent($0) }
                                            ),
                                            selectedText: $selectedText,
                                            font: .system(size: viewModel.settings.fontSize)
                                        )
                                        .focused($isEditorFocused)
                                        .onChange(of: selectedText) { oldValue, newSelection in
                                            if !newSelection.isEmpty && !viewModel.isChatSidebarVisible {
                                                withAnimation {
                                                    viewModel.isChatSidebarVisible = true
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxWidth: 750)
                                    
                                    if showFontSizeIndicator {
                                        VStack {
                                            Spacer()
                                            FontSizeIndicatorView(fontSize: viewModel.settings.fontSize, isVisible: $showFontSizeIndicator)
                                            Spacer()
                                        }
                                    }
                                }
                                .background(Color(uiModel: .windowBackground))
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
                        }
                        .frame(maxWidth: .infinity)
                        .clipShape(Rectangle())
                        
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