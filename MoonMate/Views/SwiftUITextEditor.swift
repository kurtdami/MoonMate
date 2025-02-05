import SwiftUI
import AppKit

struct SwiftUITextEditor: View {
    @Binding var text: String
    @Binding var selectedText: String
    let font: Font
    
    // Local state for text handling
    @State private var localText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextEditor(text: $localText)
            .font(font)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .foregroundColor(Color(uiModel: .editorText))
            .focused($isFocused)
            // Handle text changes
            .onChange(of: localText) { newValue in
                text = newValue
            }
            // Handle external text changes
            .onChange(of: text) { newValue in
                if localText != newValue {
                    localText = newValue
                }
            }
            // Handle selection changes using NSTextView notification
            .background {
                GeometryReader { _ in
                    Color.clear
                        .onAppear {
                            // Setup selection change notification
                            NotificationCenter.default.addObserver(
                                forName: NSTextView.didChangeSelectionNotification,
                                object: nil,
                                queue: .main
                            ) { notification in
                                if let textView = notification.object as? NSTextView,
                                   textView.string == localText {
                                    let range = textView.selectedRange()
                                    if range.length > 0 {
                                        selectedText = (textView.string as NSString).substring(with: range)
                                    } else {
                                        selectedText = ""
                                    }
                                }
                            }
                        }
                }
            }
            // Add custom modifiers for appearance
            .modifier(TextEditorAppearanceModifier())
            .onAppear {
                // Initialize local text with binding
                localText = text
            }
    }
}

// Custom modifier for text editor appearance
struct TextEditorAppearanceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: 750)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(uiModel: .windowBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
    }
}

// Preview
struct SwiftUITextEditor_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUITextEditor(
            text: .constant("Sample text"),
            selectedText: .constant(""),
            font: .system(size: 14)
        )
        .padding()
    }
} 