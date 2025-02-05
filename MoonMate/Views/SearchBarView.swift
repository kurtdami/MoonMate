import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var isVisible: Bool
    var onNext: () -> Void
    var onPrevious: () -> Void
    var onClose: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search in document", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit {
                        onNext()
                    }
                    .onChange(of: searchText) { _ in
                        // Trigger search on each character change
                        if isVisible {
                            onNext()
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: { 
                        searchText = ""
                        // Trigger search when clearing text
                        onNext()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            
            HStack(spacing: 8) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.plain)
                .disabled(searchText.isEmpty)
                .keyboardShortcut(.return, modifiers: [.shift])
                
                Button(action: onNext) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.plain)
                .disabled(searchText.isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            }
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(12)
        .background(Color(.windowBackgroundColor).opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separatorColor))
                .opacity(0.5),
            alignment: .bottom
        )
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    SearchBarView(
        searchText: .constant(""),
        isVisible: .constant(true),
        onNext: {},
        onPrevious: {},
        onClose: {}
    )
} 