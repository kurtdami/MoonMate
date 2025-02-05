import SwiftUI
import AppKit

struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedText: String
    var font: NSFont?
    @Binding var searchText: String
    @Binding var isSearchVisible: Bool
    @Binding var currentMatchIndex: Int
    @Binding var totalMatches: Int
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
        
        // Customize insertion point (cursor)
        textView.insertionPointColor = NSColor(red: 0.86, green: 0.08, blue: 0.24, alpha: 0.9) // Crimson color
        
        // Configure text container for stable text handling
        textView.textContainer?.size = NSSize(width: 750, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.lineFragmentPadding = 0
        
        // Ensure smooth text layout updates
        textView.layoutManager?.allowsNonContiguousLayout = false
        textView.layoutManager?.typesetterBehavior = .behavior_10_2_WithCompatibility
        textView.layoutManager?.showsInvisibleCharacters = false
        textView.layoutManager?.showsControlCharacters = false
        
        // Disable layout/display optimizations that can cause flickering
        textView.enclosingScrollView?.hasVerticalRuler = false
        textView.enclosingScrollView?.hasHorizontalRuler = false
        textView.enclosingScrollView?.rulersVisible = false
        
        // Configure line spacing and paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 12
        paragraphStyle.minimumLineHeight = (textView.font?.pointSize ?? 14) * 1.5
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.baseWritingDirection = .leftToRight
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes[.paragraphStyle] = paragraphStyle
        
        // Improve text layout behavior
        textView.layoutManager?.hyphenationFactor = 0.0
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        // Configure for stable text editing
        textView.isRichText = false
        textView.font = font ?? .systemFont(ofSize: NSFont.systemFontSize)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        
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
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else {
            print("Debug: Failed to get textView in updateNSView")
            return
        }
        
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            let visibleRect = textView.visibleRect
            
            // Store cursor position relative to the visible text
            let cursorRect = textView.firstRect(forCharacterRange: selectedRange, actualRange: nil)
            let cursorOffset = cursorRect.minY - visibleRect.minY
            
            // Update text content
            let previousLength = textView.string.count
            textView.string = text
            
            // Ensure paragraph style is maintained
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 12
            paragraphStyle.minimumLineHeight = (textView.font?.pointSize ?? 14) * 1.5
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.baseWritingDirection = .leftToRight
            
            // Apply style to entire text
            if let textStorage = textView.textStorage {
                let fullRange = NSRange(location: 0, length: textView.string.count)
                textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
                textStorage.addAttribute(.font, value: textView.font ?? .systemFont(ofSize: NSFont.systemFontSize), range: fullRange)
                textStorage.addAttribute(.foregroundColor, value: NSColor(Color(uiModel: .editorText)), range: fullRange)
            }
            
            // Restore cursor position intelligently
            if selectedRange.location <= previousLength {
                let newPosition = min(selectedRange.location, textView.string.count)
                let newRange = NSRange(location: newPosition, length: 0)
                textView.selectedRange = newRange
                
                // Calculate new cursor position
                let newCursorRect = textView.firstRect(forCharacterRange: newRange, actualRange: nil)
                if !visibleRect.contains(newCursorRect) {
                    // If cursor would be outside view, adjust scroll position to maintain relative position
                    let newVisibleRect = NSRect(
                        x: visibleRect.minX,
                        y: newCursorRect.minY - cursorOffset,
                        width: visibleRect.width,
                        height: visibleRect.height
                    )
                    textView.scrollToVisible(newVisibleRect)
                } else {
                    // Otherwise maintain current scroll position
                    textView.scrollToVisible(visibleRect)
                }
            }
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
        weak var textView: NSTextView?
        private var searchDebouncer: Timer?
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
            super.init()
        }
        
        func debouncedSearch() {
            searchDebouncer?.invalidate()
            searchDebouncer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                self?.performSearch()
            }
        }
        
        func performSearch() {
            guard let textView = self.textView else {
                print("Debug: textView not available in performSearch")
                return
            }
            
            print("Debug: Performing search - searchText: '\(parent.searchText)', isVisible: \(parent.isSearchVisible)")
            print("Debug: Current text length: \(textView.string.count)")
            
            // Clear highlights if search is not visible
            if !parent.isSearchVisible {
                print("Debug: Search not visible, clearing highlights")
                clearHighlights(in: textView)
                return
            }
            
            // Always perform search when search is visible
            lastSearchText = parent.searchText
            
            guard !parent.searchText.isEmpty else {
                print("Debug: Search text is empty")
                clearHighlights(in: textView)
                return
            }
            
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
                    print("Debug: Found match at range: \(range)")
                    foundRanges.append(range)
                    searchRange.location = range.location + range.length
                    searchRange.length = content.length - searchRange.location
                } else {
                    break
                }
            }
            
            print("Debug: Found \(foundRanges.count) matches")
            highlightedRanges = foundRanges
            
            // Update match counts
            parent.totalMatches = foundRanges.count
            if foundRanges.isEmpty {
                parent.currentMatchIndex = 0
            } else if parent.currentMatchIndex == 0 {
                parent.currentMatchIndex = 1
            }
            
            // Apply highlights
            applyHighlights(in: textView)
        }
        
        private func applyHighlights(in textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            
            // First remove any existing highlights
            let fullRange = NSRange(location: 0, length: textStorage.length)
            let attributesToRemove: [NSAttributedString.Key] = [
                .backgroundColor,
                .strokeColor,
                .strokeWidth,
                .foregroundColor
            ]
            for attribute in attributesToRemove {
                textStorage.removeAttribute(attribute, range: fullRange)
            }
            
            // Restore text color
            textStorage.addAttribute(.foregroundColor, value: NSColor(Color(uiModel: .editorText)), range: fullRange)
            
            // Add outline to all matches except current
            for (index, range) in highlightedRanges.enumerated() {
                if index != parent.currentMatchIndex - 1 {
                    // Create a clean white border effect
                    let borderAttributes: [NSAttributedString.Key: Any] = [
                        .strokeColor: NSColor.white,
                        .strokeWidth: 1.0,  // Positive value creates only stroke (outline)
                    ]
                    textStorage.addAttributes(borderAttributes, range: range)
                }
            }
            
            // Highlight current match if exists
            if !highlightedRanges.isEmpty && parent.currentMatchIndex > 0 {
                let currentRange = highlightedRanges[parent.currentMatchIndex - 1]
                let currentAttributes: [NSAttributedString.Key: Any] = [
                    .backgroundColor: NSColor.systemYellow,  // Solid yellow
                    .foregroundColor: NSColor.black  // Black text for contrast
                ]
                textStorage.addAttributes(currentAttributes, range: currentRange)
                
                // Ensure current match is visible
                textView.scrollRangeToVisible(currentRange)
                currentSearchRange = currentRange
            }
        }
        
        func findNext() {
            guard let textView = self.textView,
                  !highlightedRanges.isEmpty else { return }
            
            // Update current match index
            parent.currentMatchIndex = (parent.currentMatchIndex % parent.totalMatches) + 1
            
            // Apply updated highlights
            applyHighlights(in: textView)
        }
        
        func findPrevious() {
            guard let textView = self.textView,
                  !highlightedRanges.isEmpty else { return }
            
            // Update current match index
            parent.currentMatchIndex = ((parent.currentMatchIndex - 2 + parent.totalMatches) % parent.totalMatches) + 1
            
            // Apply updated highlights
            applyHighlights(in: textView)
        }
        
        private func clearHighlights(in textView: NSTextView) {
            guard let textStorage = textView.textStorage else {
                print("Debug: textStorage not available in clearHighlights")
                return
            }
            
            print("Debug: Clearing highlights")
            let fullRange = NSRange(location: 0, length: textStorage.length)
            
            // Remove all search highlights and borders
            let attributesToRemove: [NSAttributedString.Key] = [
                .backgroundColor,
                .strokeColor,
                .strokeWidth,
                .foregroundColor
            ]
            
            for attribute in attributesToRemove {
                textStorage.removeAttribute(attribute, range: fullRange)
            }
            
            // Restore original text color
            textStorage.addAttribute(.foregroundColor, value: NSColor(Color(uiModel: .editorText)), range: fullRange)
            
            // Reset search state
            highlightedRanges = []
            currentSearchRange = nil
            
            // Only reset match counts if search is not visible or text is empty
            if !parent.isSearchVisible || parent.searchText.isEmpty {
                parent.totalMatches = 0
                parent.currentMatchIndex = 0
            }
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Store current state
            let selectedRange = textView.selectedRange()
            let visibleRect = textView.visibleRect
            
            // Update binding
            parent.text = textView.string
            
            // Restore state after update
            DispatchQueue.main.async {
                if selectedRange.location < textView.string.count {
                    textView.selectedRange = selectedRange
                    let cursorRect = textView.firstRect(forCharacterRange: selectedRange, actualRange: nil)
                    
                    // Only scroll if cursor is outside visible area
                    if !visibleRect.contains(cursorRect) {
                        textView.scrollRangeToVisible(selectedRange)
                    } else {
                        textView.scrollToVisible(visibleRect)
                    }
                }
            }
        }
        
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            // Special handling for Backspace key (when replacementString is empty and range length is 0)
            if replacementString == "" && affectedCharRange.length == 1 {
                // Store the current visible rect and cursor position
                let visibleRect = textView.visibleRect
                let cursorRect = textView.firstRect(forCharacterRange: affectedCharRange, actualRange: nil)
                
                // Update text in a single operation
                textView.textStorage?.beginEditing()
                
                // Delete the character
                textView.replaceCharacters(in: affectedCharRange, with: "")
                
                // Update attributes for the entire affected area
                if let textStorage = textView.textStorage {
                    let affectedLength = textStorage.length - affectedCharRange.location
                    let affectedRange = NSRange(location: affectedCharRange.location, length: affectedLength)
                    
                    // Ensure consistent paragraph style
                    if let defaultStyle = textView.defaultParagraphStyle {
                        let paragraphStyle = defaultStyle.mutableCopy() as! NSMutableParagraphStyle
                        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: affectedRange)
                        textStorage.addAttribute(.font, value: textView.font ?? .systemFont(ofSize: NSFont.systemFontSize), range: affectedRange)
                        textStorage.addAttribute(.foregroundColor, value: NSColor(Color(uiModel: .editorText)), range: affectedRange)
                    }
                }
                
                textView.textStorage?.endEditing()
                
                // Update binding
                parent.text = textView.string
                
                // Set cursor position
                let newPosition = affectedCharRange.location
                textView.selectedRange = NSRange(location: newPosition, length: 0)
                
                // Force immediate layout update
                textView.layoutManager?.ensureLayout(for: textView.textContainer!)
                
                // Get the new cursor rect after the update
                let newCursorRect = textView.firstRect(forCharacterRange: textView.selectedRange(), actualRange: nil)
                
                // Check if we need to adjust scroll position
                if !visibleRect.contains(newCursorRect) {
                    // Calculate the ideal scroll position
                    let scrollToRect = NSRect(
                        x: visibleRect.minX,
                        y: newCursorRect.midY - (visibleRect.height / 2), // Center cursor vertically
                        width: visibleRect.width,
                        height: visibleRect.height
                    )
                    
                    // Perform a single, smooth scroll animation
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.2
                        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        textView.scrollToVisible(scrollToRect)
                    }, completionHandler: nil)
                }
                
                textView.needsDisplay = true
                return false
            }
            
            // Special handling for Enter key
            if replacementString == "\n" {
                // Store the current visible rect
                let visibleRect = textView.visibleRect
                
                // Get the current line range
                let currentLine = textView.string as NSString
                let lineRange = currentLine.lineRange(for: affectedCharRange)
                
                // Calculate the indentation of the current line
                var indentation = ""
                if lineRange.location < currentLine.length {
                    let currentLineText = currentLine.substring(with: lineRange)
                    let whitespaceSet = CharacterSet.whitespaces
                    indentation = String(currentLineText.prefix(while: { char in
                        if let scalar = String(char).unicodeScalars.first {
                            return whitespaceSet.contains(scalar)
                        }
                        return false
                    }))
                }
                
                // Prepare the new line text
                let newLineText = "\n" + indentation
                
                // Calculate where the new cursor will be
                let newPosition = affectedCharRange.location + newLineText.count
                
                // Update text in a single operation
                textView.textStorage?.beginEditing()
                textView.replaceCharacters(in: affectedCharRange, with: newLineText)
                textView.textStorage?.endEditing()
                
                // Update binding
                parent.text = textView.string
                
                // Set cursor position
                textView.selectedRange = NSRange(location: newPosition, length: 0)
                
                // Force layout update synchronously
                textView.layoutManager?.ensureLayout(for: textView.textContainer!)
                textView.layoutManager?.glyphRange(for: textView.textContainer!) // Force glyph generation
                
                // Important: Use DispatchQueue.main.async to ensure layout is complete
                DispatchQueue.main.async {
                    // Get the current visible rect
                    let visibleRect = textView.visibleRect
                    
                    // Get the new cursor rect after layout is complete
                    let newCursorRect = textView.firstRect(forCharacterRange: textView.selectedRange(), actualRange: nil)
                    
                    // Calculate the ideal scroll position to center the cursor
                    let idealOffset = newCursorRect.midY - (visibleRect.height / 2)
                    
                    // Ensure we don't scroll past content bounds
                    let maxScrollY = max(0, textView.frame.height - visibleRect.height)
                    let adjustedY = min(max(0, idealOffset), maxScrollY)
                    
                    let adjustedRect = NSRect(
                        x: visibleRect.minX,
                        y: adjustedY,
                        width: visibleRect.width,
                        height: visibleRect.height
                    )
                    
                    // Perform smooth scroll animation
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.2
                        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        textView.scrollToVisible(adjustedRect)
                    })
                }
                
                textView.needsDisplay = true
                return false
            }
            
            // Handle paste operation
            if let pasteboard = NSPasteboard.general.string(forType: .string),
               replacementString == pasteboard {
                // Update text in a single operation
                textView.textStorage?.beginEditing()
                textView.replaceCharacters(in: affectedCharRange, with: pasteboard)
                
                // Update attributes for pasted text
                if let textStorage = textView.textStorage {
                    let pastedRange = NSRange(location: affectedCharRange.location, length: pasteboard.count)
                    if let defaultStyle = textView.defaultParagraphStyle {
                        let paragraphStyle = defaultStyle.mutableCopy() as! NSMutableParagraphStyle
                        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: pastedRange)
                        textStorage.addAttribute(.font, value: textView.font ?? .systemFont(ofSize: NSFont.systemFontSize), range: pastedRange)
                        textStorage.addAttribute(.foregroundColor, value: NSColor(Color(uiModel: .editorText)), range: pastedRange)
                    }
                }
                
                textView.textStorage?.endEditing()
                
                parent.text = textView.string
                return false
            }
            
            return true
        }
        
        @objc func handleSelectionChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let selectedRange = textView.selectedRange()
            
            // Only handle selection changes, not cursor movements within visible area
            if selectedRange.length > 0 {
                let newSelection = (textView.string as NSString).substring(with: selectedRange)
                
                // Only update if the selection actually changed
                if newSelection != parent.selectedText {
                    parent.selectedText = newSelection
                }
            }
        }
    }
} 