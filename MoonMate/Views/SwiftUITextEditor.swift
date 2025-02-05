import SwiftUI

struct SwiftUITextEditor: View {
    @Binding var text: String
    @Binding var selectedText: String
    var font: Font
    @Binding var searchText: String
    @Binding var isSearchVisible: Bool
    @Binding var currentMatchIndex: Int
    @Binding var totalMatches: Int
    
    // State for handling search highlights
    @State private var highlightRanges: [Range<String.Index>] = []
    
    var body: some View {
        ScrollView {
            TextEditor(text: $text)
                .font(font)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .foregroundColor(Color(uiModel: .editorText))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: text) { newValue in
                    if isSearchVisible {
                        updateSearchHighlights()
                    }
                }
                .onChange(of: searchText) { _ in
                    if isSearchVisible {
                        updateSearchHighlights()
                    }
                }
                // Custom selection handling
                .onAppear {
                    NotificationCenter.default.addObserver(
                        forName: UITextView.textDidChangeNotification,
                        object: nil,
                        queue: .main
                    ) { notification in
                        if let textView = notification.object as? UITextView {
                            if let selectedRange = textView.selectedTextRange {
                                selectedText = textView.text(in: selectedRange) ?? ""
                            }
                        }
                    }
                }
        }
        .overlay(
            // Search highlight overlay
            GeometryReader { geometry in
                ForEach(Array(highlightRanges.enumerated()), id: \.offset) { index, range in
                    let highlightRect = calculateHighlightRect(for: range, in: geometry)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.yellow.opacity(0.3))
                        .frame(width: highlightRect.width, height: highlightRect.height)
                        .position(x: highlightRect.midX, y: highlightRect.midY)
                }
            }
        )
    }
    
    private func updateSearchHighlights() {
        guard !searchText.isEmpty else {
            highlightRanges = []
            totalMatches = 0
            currentMatchIndex = 0
            return
        }
        
        var ranges: [Range<String.Index>] = []
        var searchRange = text.startIndex..<text.endIndex
        
        while let range = text.range(
            of: searchText,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: searchRange
        ) {
            ranges.append(range)
            searchRange = range.upperBound..<text.endIndex
        }
        
        highlightRanges = ranges
        totalMatches = ranges.count
        currentMatchIndex = min(currentMatchIndex, totalMatches - 1)
    }
    
    private func calculateHighlightRect(for range: Range<String.Index>, in geometry: GeometryProxy) -> CGRect {
        // This is a simplified calculation - in a real implementation,
        // you would need to calculate the actual position based on text layout
        let start = text.distance(from: text.startIndex, to: range.lowerBound)
        let length = text.distance(from: range.lowerBound, to: range.upperBound)
        
        let lineHeight: CGFloat = 20 // Approximate line height
        let charWidth: CGFloat = 8 // Approximate character width
        
        let line = start / Int(geometry.size.width / charWidth)
        let column = start % Int(geometry.size.width / charWidth)
        
        return CGRect(
            x: CGFloat(column) * charWidth,
            y: CGFloat(line) * lineHeight,
            width: CGFloat(length) * charWidth,
            height: lineHeight
        )
    }
}

// Preview provider for development
struct SwiftUITextEditor_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUITextEditor(
            text: .constant("Sample text"),
            selectedText: .constant(""),
            font: .system(.body),
            searchText: .constant(""),
            isSearchVisible: .constant(false),
            currentMatchIndex: .constant(0),
            totalMatches: .constant(0)
        )
    }
} 