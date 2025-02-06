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
        ScrollView(.vertical, showsIndicators: false) {
            TextEditor(text: $localText)
                .font(font)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .background(Color.clear)
                .foregroundColor(Color(uiModel: .editorText))
                .focused($isFocused)
                .onChange(of: localText) { newValue in
                    text = newValue
                }
                .onChange(of: text) { newValue in
                    if localText != newValue {
                        localText = newValue
                    }
                }
                // Add the selection monitor
                .background(
                    TextSelectionMonitor(text: localText, selectedText: $selectedText)
                )
        }
        .modifier(TextEditorAppearanceModifier())
        .onAppear {
            localText = text
        }
    }
}

// NSViewRepresentable wrapper for text selection monitoring
struct TextSelectionMonitor: NSViewRepresentable {
    let text: String
    @Binding var selectedText: String
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.startMonitoring()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: text, selectedText: $selectedText)
    }
    
    class Coordinator: NSObject {
        var text: String
        var selectedText: Binding<String>
        var observer: NSObjectProtocol?
        
        init(text: String, selectedText: Binding<String>) {
            self.text = text
            self.selectedText = selectedText
            super.init()
        }
        
        func startMonitoring() {
            observer = NotificationCenter.default.addObserver(
                forName: NSTextView.didChangeSelectionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self,
                      let textView = notification.object as? NSTextView,
                      textView.string == self.text else { return }
                
                let range = textView.selectedRange()
                if range.length > 0 {
                    self.selectedText.wrappedValue = (textView.string as NSString).substring(with: range)
                } else {
                    self.selectedText.wrappedValue = ""
                }
            }
        }
        
        deinit {
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
            }
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