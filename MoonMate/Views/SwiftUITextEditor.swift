import SwiftUI
import AppKit

struct SwiftUITextEditor: View {
    @Binding var text: String
    @Binding var selectedText: String
    let font: Font
    
    @State private var localText: String = ""
    @FocusState private var isFocused: Bool
    @State private var updateTimer: Timer? = nil
    
    var body: some View {
        TextEditor(text: $localText)
            .font(font)
            .foregroundColor(Color(uiModel: .editorText))
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
            .focused($isFocused)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
            .background {
                Color(uiModel: .windowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .background {
                TextSelectionMonitor(text: localText, selectedText: $selectedText)
            }
            .onChange(of: localText) { _, newValue in
                guard text != newValue else { return }
                updateTimer?.invalidate()
                updateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                    DispatchQueue.main.async {
                        text = localText
                    }
                }
            }
            .onChange(of: text) { _, newValue in
                if !isFocused && localText != newValue {
                    localText = newValue
                }
            }
            .onAppear { localText = text }
    }
}

// Selection monitoring
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
