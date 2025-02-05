import SwiftUI
import AppKit

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isSelectedText: Bool
    let isLoading: Bool
    let messageType: MessageType
    
    enum MessageType {
        case selectedText
        case prompt
        case response
    }
    
    static func loading() -> ChatMessage {
        ChatMessage(text: "Thinking...", isSelectedText: false, isLoading: true, messageType: .response)
    }
}

struct ChatSidebarView: View {
    @Binding var isVisible: Bool
    @ObservedObject var viewModel: DocumentViewModel
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isDragging: Bool = false
    @State private var isLoading: Bool = false
    let selectedText: String?
    
    // Use MockAPIClient for testing
    private let apiClient: APIClient = MockAPIClient()
    
    private var orderedMessages: [ChatMessage] {
        var ordered: [ChatMessage] = []
        
        // 1. Always show selected text at top if available
        if let selectedText = selectedText, !selectedText.isEmpty {
            ordered.append(ChatMessage(
                text: selectedText,
                isSelectedText: true,
                isLoading: false,
                messageType: .selectedText
            ))
        }
        
        // 2. Group messages by pairs (prompt and response)
        var promptResponsePairs: [(prompt: ChatMessage, response: ChatMessage?)] = []
        var currentPrompt: ChatMessage? = nil
        
        for message in messages {
            if currentPrompt == nil {
                currentPrompt = message
            } else {
                promptResponsePairs.append((prompt: currentPrompt!, response: message))
                currentPrompt = nil
            }
        }
        
        // Add any remaining prompt without response
        if let lastPrompt = currentPrompt {
            promptResponsePairs.append((prompt: lastPrompt, response: nil))
        }
        
        // Add the pairs to ordered messages (most recent first)
        for pair in promptResponsePairs.reversed() {
            ordered.append(pair.prompt)
            if let response = pair.response {
                ordered.append(response)
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
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(orderedMessages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }
                
                // Input Area
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        TextField("Ask about the selected text...", text: $inputText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(isLoading)
                        
                        Button(action: {
                            Task {
                                await sendMessage()
                            }
                        }) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.title2)
                            }
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
        
        isLoading = true
        // Add user's prompt to messages
        messages.append(ChatMessage(
            text: inputText,
            isSelectedText: false,
            isLoading: false,
            messageType: .prompt
        ))
        
        do {
            let request = TextImprovementRequest(selectedText: selectedText, prompt: inputText)
            let response = try await apiClient.improveText(request)
            
            // Add AI response to messages
            messages.append(ChatMessage(
                text: response.improvedText,
                isSelectedText: false,
                isLoading: false,
                messageType: .response
            ))
            inputText = ""
        } catch {
            messages.append(ChatMessage(
                text: "Error: \(error.localizedDescription)",
                isSelectedText: false,
                isLoading: false,
                messageType: .response
            ))
        }
        
        isLoading = false
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