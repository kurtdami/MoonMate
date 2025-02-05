import SwiftUI
import AppKit

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isSelectedText: Bool
}

struct ChatSidebarView: View {
    @Binding var isVisible: Bool
    @ObservedObject var viewModel: DocumentViewModel
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isDragging: Bool = false
    let selectedText: String?
    
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
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }
                        
                        if let selectedText = selectedText, !selectedText.isEmpty {
                            MessageBubble(message: ChatMessage(text: selectedText, isSelectedText: true))
                                .transition(.opacity.combined(with: .scale))
                                .animation(.spring(response: 0.2), value: selectedText)
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
                        
                        Button(action: {
                            // Will implement send action later
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.accentColor)
                                .font(.title2)
                        }
                        .disabled(inputText.isEmpty)
                    }
                    .padding()
                }
            }
        }
        .frame(width: viewModel.chatSidebarWidth)
        .background(Color(.textBackgroundColor))
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if message.isSelectedText {
                Text("Selected Text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
            
            Text(message.text)
                .padding(10)
                .background(
                    message.isSelectedText ? 
                        Color.secondary.opacity(0.1) : 
                        Color.accentColor.opacity(0.1)
                )
                .cornerRadius(10)
                .animation(.easeInOut(duration: 0.2), value: message.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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