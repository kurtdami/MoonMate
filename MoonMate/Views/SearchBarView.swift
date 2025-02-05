import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var isVisible: Bool
    var currentMatch: Int
    var totalMatches: Int
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
                        print("Debug: Search submit pressed")
                        onNext()
                    }
                    .onChange(of: searchText) { oldValue, newValue in
                        print("Debug: Search text changed to: '\(newValue)'")
                    }
                
                if !searchText.isEmpty {
                    // Show match count when there are matches
                    if totalMatches > 0 {
                        Text("\(currentMatch) of \(totalMatches)")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                            .padding(.horizontal, 4)
                    }
                    
                    Button(action: { 
                        print("Debug: Clear search text button pressed")
                        searchText = ""
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
                .disabled(searchText.isEmpty || totalMatches == 0)
                .keyboardShortcut(.return, modifiers: [.shift])
                
                Button(action: onNext) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.plain)
                .disabled(searchText.isEmpty || totalMatches == 0)
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
            print("Debug: SearchBarView appeared")
            isFocused = true
        }
    }
}

#Preview {
    SearchBarView(
        searchText: .constant(""),
        isVisible: .constant(true),
        currentMatch: 1,
        totalMatches: 5,
        onNext: {},
        onPrevious: {},
        onClose: {}
    )
} 