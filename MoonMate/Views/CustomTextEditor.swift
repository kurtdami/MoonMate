import SwiftUI
import AppKit

struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedText: String
    var font: NSFont?
    @Binding var searchText: String
    @Binding var isSearchVisible: Bool
    var onCoordinatorCreated: (Coordinator) -> Void
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self)
        onCoordinatorCreated(coordinator)
        return coordinator
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        
        textView.delegate = context.coordinator
        context.coordinator.textView = textView // Store textView reference
        
        // Add notification observer for real-time selection changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleSelectionChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )
        
        // Setup find/replace functionality
        textView.isIncrementalSearchingEnabled = true
        textView.usesFindBar = false // We'll use our custom search UI
        
        textView.isRichText = false // Disable rich text to prevent formatted text
        textView.font = font ?? .systemFont(ofSize: NSFont.systemFontSize)
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        
        // Configure text container to center text
        textView.textContainer?.size = NSSize(width: 750, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.lineFragmentPadding = 0  // Remove padding since we're handling it in the container
        
        // Configure line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8  // Adjust this value to increase/decrease line spacing
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes[.paragraphStyle] = paragraphStyle
        
        // Configure background colors
        textView.backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        
        // Customize scroll bar appearance
        scrollView.scrollerStyle = .overlay // Makes the scroller overlay the content
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false // Disable horizontal scrolling
        scrollView.autohidesScrollers = true // Hide when not scrolling
        
        // Make scroll bar thinner and more transparent
        if let verticalScroller = scrollView.verticalScroller {
            verticalScroller.controlSize = .mini // Make the scroll bar thinner
            verticalScroller.alphaValue = 0.15 // Make it very transparent
        }
        
        // Remove content insets to place scroll bar at the edge
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        // Center the text view content
        textView.alignment = .left
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.textContainer?.containerSize = NSSize(width: 750, height: CGFloat.greatestFiniteMagnitude)
        
        // Set dimmed white text color
        textView.textColor = NSColor(Color(uiModel: .editorText))
        
        // Configure search highlighting
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // Update search if text changed
        context.coordinator.performSearch()
        
        if textView.string != text {
            textView.string = text
            
            // Ensure paragraph style is maintained after updates
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 8  // Same value as in makeNSView
            textView.defaultParagraphStyle = paragraphStyle
            textView.typingAttributes[.paragraphStyle] = paragraphStyle
            
            // Apply paragraph style to entire text
            let range = NSRange(location: 0, length: textView.string.count)
            textView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        }
        
        if let font = font {
            textView.font = font
        }
        
        // Ensure text color is maintained after updates
        textView.textColor = NSColor(Color(uiModel: .editorText))
        
        // Ensure scroll bar settings are maintained
        if let verticalScroller = nsView.verticalScroller {
            verticalScroller.controlSize = .mini
            verticalScroller.alphaValue = 0.15
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextEditor
        private var lastSearchText: String = ""
        private var currentSearchRange: NSRange?
        private var highlightedRanges: [NSRange] = []
        weak var textView: NSTextView? // Make it internal instead of private
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
            super.init()
        }
        
        func performSearch() {
            guard let textView = self.textView else { return }
            
            // Clear highlights if search is not visible
            if !parent.isSearchVisible {
                clearHighlights(in: textView)
                return
            }
            
            // Only search if text has changed
            guard parent.searchText != lastSearchText else { return }
            lastSearchText = parent.searchText
            
            // Clear previous highlights
            clearHighlights(in: textView)
            
            guard !parent.searchText.isEmpty else { return }
            
            let content = textView.string as NSString
            var searchRange = NSRange(location: 0, length: content.length)
            var foundRanges: [NSRange] = []
            
            // Find all matches
            while searchRange.location < content.length {
                let range = content.range(
                    of: parent.searchText,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: searchRange
                )
                
                if range.location != NSNotFound {
                    foundRanges.append(range)
                    searchRange.location = range.location + range.length
                    searchRange.length = content.length - searchRange.location
                } else {
                    break
                }
            }
            
            // Highlight all matches
            highlightRanges(foundRanges, in: textView)
            
            // Select the first match if any
            if let firstRange = foundRanges.first {
                textView.setSelectedRange(firstRange)
                textView.scrollRangeToVisible(firstRange)
                currentSearchRange = firstRange
            }
            
            highlightedRanges = foundRanges
        }
        
        private func clearHighlights(in textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: textStorage.length)
            
            // Remove all search highlights
            textStorage.removeAttribute(.backgroundColor, range: fullRange)
            
            // Restore original text color
            textStorage.addAttribute(.foregroundColor, value: NSColor(Color(uiModel: .editorText)), range: fullRange)
            
            // Clear highlighted ranges
            highlightedRanges = []
            currentSearchRange = nil
        }
        
        private func highlightRanges(_ ranges: [NSRange], in textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            
            for range in ranges {
                // Add yellow highlight with some transparency
                textStorage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.3), range: range)
            }
        }
        
        func findNext() {
            guard let textView = self.textView,
                  !highlightedRanges.isEmpty else { return }
            
            let currentLocation = textView.selectedRange().location
            
            // Find the next range after current selection
            if let nextRange = highlightedRanges.first(where: { $0.location > currentLocation }) {
                textView.setSelectedRange(nextRange)
                textView.scrollRangeToVisible(nextRange)
                currentSearchRange = nextRange
            } else if let firstRange = highlightedRanges.first {
                // Wrap around to the beginning
                textView.setSelectedRange(firstRange)
                textView.scrollRangeToVisible(firstRange)
                currentSearchRange = firstRange
            }
        }
        
        func findPrevious() {
            guard let textView = self.textView,
                  !highlightedRanges.isEmpty else { return }
            
            let currentLocation = textView.selectedRange().location
            
            // Find the previous range before current selection
            if let previousRange = highlightedRanges.last(where: { $0.location < currentLocation }) {
                textView.setSelectedRange(previousRange)
                textView.scrollRangeToVisible(previousRange)
                currentSearchRange = previousRange
            } else if let lastRange = highlightedRanges.last {
                // Wrap around to the end
                textView.setSelectedRange(lastRange)
                textView.scrollRangeToVisible(lastRange)
                currentSearchRange = lastRange
            }
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
        
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            // Handle paste operation
            if let pasteboard = NSPasteboard.general.string(forType: .string),
               replacementString == pasteboard {
                // Replace the selected text with plain text from pasteboard
                textView.replaceCharacters(in: affectedCharRange, with: pasteboard)
                // Update the text binding and trigger save
                parent.text = textView.string
                // Trigger text change notification to ensure save
                textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
                return false // We handled the paste operation ourselves
            }
            return true // Allow other text changes
        }
        
        @objc func handleSelectionChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let selectedRange = textView.selectedRange()
            let newSelection = selectedRange.length > 0 ? 
                (textView.string as NSString).substring(with: selectedRange) : ""
            
            // Only update if the selection actually changed
            if newSelection != parent.selectedText {
                parent.selectedText = newSelection
            }
        }
    }
} 