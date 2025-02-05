import SwiftUI
import AppKit

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isSelectedText: Bool
    let isLoading: Bool
    let messageType: MessageType
    let selectedTextId: UUID?
    
    enum MessageType {
        case selectedText
        case prompt
        case response
    }
    
    static func loading() -> ChatMessage {
        ChatMessage(text: "Thinking...", isSelectedText: false, isLoading: true, messageType: .response, selectedTextId: nil)
    }
}

struct ChatSidebarView: View {
    @Binding var isVisible: Bool
    @ObservedObject var viewModel: DocumentViewModel
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isDragging: Bool = false
    @State private var isLoading: Bool = false
    @State private var currentSelectedTextId: UUID? = nil
    @FocusState private var isInputFocused: Bool
    let selectedText: String?
    
    // Use MockAPIClient for testing
    private let apiClient: APIClient = MockAPIClient()
    
    private var orderedMessages: [ChatMessage] {
        var ordered: [ChatMessage] = []
        
        // Add all existing messages first
        ordered.append(contentsOf: messages)
        
        // If there's a new selected text that's different from the last one, add it at the end
        if let selectedText = selectedText,
           !selectedText.isEmpty {
            // Check if this is a new selection different from the last one
            let isNewSelection = messages.last(where: { $0.messageType == .selectedText })?.text != selectedText
            
            if isNewSelection {
                // Create a new selected text message with a new ID
                let newSelectedTextId = UUID()
                currentSelectedTextId = newSelectedTextId
                ordered.append(ChatMessage(
                    text: selectedText,
                    isSelectedText: true,
                    isLoading: false,
                    messageType: .selectedText,
                    selectedTextId: newSelectedTextId
                ))
            }
        }
        
        return ordered
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Resize Handle
            ResizeHandle(isDragging: $isDragging) { dragAmount in
                let newWidth = viewModel.chatSidebarWidth - dragAmount.translation.width
                viewModel.updateChatSidebarWidth(newWidth)
            }
            
            // Main Content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Chat")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        withAnimation {
                            isVisible.toggle()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.separatorColor).opacity(0.1))
                
                // Messages List
                ScrollView {
                    ScrollViewReader { proxy in
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(orderedMessages) { message in
                                MessageBubble(message: message)
                            }
                            // Invisible bottom anchor view
                            Color.clear
                                .frame(height: 1)
                                .id("bottomID")
                        }
                        .padding()
                        .onChange(of: orderedMessages.count, initial: true) { oldCount, newCount in
                            // Scroll to bottom whenever messages change
                            withAnimation {
                                proxy.scrollTo("bottomID", anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input Area
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        TextEditor(text: $inputText)
                            .font(.body)
                            .frame(height: calculateTextEditorHeight(text: inputText))
                            .disabled(isLoading)
                            .focused($isInputFocused)
                            .onSubmit {
                                // Only send if the button would be enabled and Shift is not pressed
                                if !inputText.isEmpty && selectedText != nil && !isLoading && !NSEvent.modifierFlags.contains(.shift) {
                                    Task {
                                        await sendMessage()
                                    }
                                }
                            }
                            .onChange(of: inputText) { oldValue, newValue in
                                // If Shift+Enter was pressed, keep the newline
                                if NSEvent.modifierFlags.contains(.shift) && newValue.last == "\n" {
                                    return
                                }
                                // If regular Enter was pressed, remove the newline and send
                                if newValue.last == "\n" && !NSEvent.modifierFlags.contains(.shift) {
                                    inputText = newValue.trimmingCharacters(in: .newlines)
                                    if !inputText.isEmpty && selectedText != nil && !isLoading {
                                        Task {
                                            await sendMessage()
                                        }
                                    }
                                }
                            }
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(.separatorColor), lineWidth: 0.5)
                            )
                            .padding(.vertical, 1)  // Prevent stroke from being clipped
                        
                        Button(action: {
                            Task {
                                await sendMessage()
                            }
                        }) {
                            Image(systemName: isLoading ? "stop.circle" : "arrow.up.circle")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.secondary)
                                .font(.system(size: 22, weight: .regular))
                        }
                        .disabled(inputText.isEmpty || selectedText == nil || isLoading)
                    }
                    .padding()
                }
            }
        }
        .frame(width: viewModel.chatSidebarWidth)
        .background(Color(.textBackgroundColor))
    }
    
    private func sendMessage() async {
        guard let selectedText = selectedText, !selectedText.isEmpty else { return }
        
        // Set loading state on main thread
        await MainActor.run {
            isLoading = true
        }
        
        // If this is a new selected text, add it to messages first
        if let lastSelectedTextMessage = messages.last(where: { $0.messageType == .selectedText }),
           lastSelectedTextMessage.text != selectedText {
            let newSelectedTextId = UUID()
            currentSelectedTextId = newSelectedTextId
            await MainActor.run {
                messages.append(ChatMessage(
                    text: selectedText,
                    isSelectedText: true,
                    isLoading: false,
                    messageType: .selectedText,
                    selectedTextId: newSelectedTextId
                ))
            }
        } else if messages.isEmpty {
            let newSelectedTextId = UUID()
            currentSelectedTextId = newSelectedTextId
            await MainActor.run {
                messages.append(ChatMessage(
                    text: selectedText,
                    isSelectedText: true,
                    isLoading: false,
                    messageType: .selectedText,
                    selectedTextId: newSelectedTextId
                ))
            }
        }
        
        // Store input text locally before clearing
        let currentInput = inputText
        
        // Clear input and add user's prompt immediately
        await MainActor.run {
            inputText = ""
            messages.append(ChatMessage(
                text: currentInput,
                isSelectedText: false,
                isLoading: false,
                messageType: .prompt,
                selectedTextId: currentSelectedTextId
            ))
        }
        
        do {
            let request = TextImprovementRequest(selectedText: selectedText, prompt: currentInput)
            let response = try await apiClient.improveText(request)
            
            await MainActor.run {
                // Add AI response to messages
                messages.append(ChatMessage(
                    text: response.improvedText,
                    isSelectedText: false,
                    isLoading: false,
                    messageType: .response,
                    selectedTextId: currentSelectedTextId
                ))
                isInputFocused = true  // Keep focus after response
                isLoading = false
            }
        } catch {
            await MainActor.run {
                messages.append(ChatMessage(
                    text: "Error: \(error.localizedDescription)",
                    isSelectedText: false,
                    isLoading: false,
                    messageType: .response,
                    selectedTextId: currentSelectedTextId
                ))
                isInputFocused = true  // Keep focus even after error
                isLoading = false
            }
        }
    }
    
    private func calculateTextEditorHeight(text: String) -> CGFloat {
        let baseHeight: CGFloat = 36  // Minimum height
        let maxHeight: CGFloat = 150  // Maximum height
        
        if text.isEmpty {
            return baseHeight
        }
        
        // Calculate based on number of lines
        let lines = text.components(separatedBy: .newlines)
        let lineCount = lines.reduce(0) { count, line in
            // Account for line wrapping
            let lineHeight = ceil(Double(line.count) / 40.0)  // Assuming ~40 chars per line
            return count + max(1, Int(lineHeight))
        }
        
        let calculatedHeight = CGFloat(lineCount * 20 + 16)  // 20 points per line + padding
        return min(maxHeight, max(baseHeight, calculatedHeight))
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch message.messageType {
            case .selectedText:
                // Selected Text with two boxes
                VStack(alignment: .leading, spacing: 4) {
                    Text(labelForMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.underPageBackgroundColor))
                        .cornerRadius(6)
                    
                    Text(message.text)
                        .padding(10)
                        .background(backgroundColorForMessage)
                        .cornerRadius(10)
                }
                .padding(8)
                .background(Color(.underPageBackgroundColor))
                .cornerRadius(12)
                
            case .prompt:
                // You message with single box containing both label and text
                VStack(alignment: .leading, spacing: 4) {
                    Text(labelForMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    
                    Text(message.text)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                }
                .background(Color(.underPageBackgroundColor))
                .cornerRadius(12)
                
            case .response:
                // Response message with diff formatting
                VStack(alignment: .leading, spacing: 8) {
                    // Split the response into lines
                    ForEach(message.text.components(separatedBy: .newlines), id: \.self) { line in
                        if line.starts(with: "Suggested Edit") {
                            Text(line)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.underPageBackgroundColor))
                                .cornerRadius(6)
                        } else if line.starts(with: "-") {
                            Text(line.dropFirst()) // Remove the "-" prefix
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(Color.red.opacity(0.08))
                                .cornerRadius(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else if line.starts(with: "+") {
                            Text(line.dropFirst()) // Remove the "+" prefix
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(Color(red: 0.2, green: 0.8, blue: 0.2).opacity(0.08))
                                .cornerRadius(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(line)
                        }
                    }
                }
                .padding(12)
                .background(backgroundColorForMessage)
                .cornerRadius(10)
            }
            
            if message.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
    }
    
    private var labelForMessage: String {
        switch message.messageType {
        case .selectedText:
            return "Selected Text"
        case .prompt:
            return "You"
        case .response:
            return ""
        }
    }
    
    private var backgroundColorForMessage: Color {
        switch message.messageType {
        case .selectedText:
            return Color(.windowBackgroundColor)
        case .prompt:
            return Color(.windowBackgroundColor)
        case .response:
            return Color(.windowBackgroundColor).opacity(0.5)
        }
    }
}

// Resize Handle Component
struct ResizeHandle: View {
    @Binding var isDragging: Bool
    let onDrag: (DragGesture.Value) -> Void
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 8)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        isDragging = true
                        onDrag(value)
                    }
                    .onEnded { _ in
                        isDragging = false
                        NSCursor.pop()
                    }
            )
            .overlay(
                Rectangle()
                    .fill(Color(.separatorColor))
                    .frame(width: 1)
                    .padding(.horizontal, 3.5)
            )
    }
}

#Preview {
    ChatSidebarView(
        isVisible: .constant(true),
        viewModel: DocumentViewModel(),
        selectedText: "This is some selected text"
    )
} 