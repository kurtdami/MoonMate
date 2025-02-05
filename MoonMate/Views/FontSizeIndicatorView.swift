import SwiftUI

struct FontSizeIndicatorView: View {
    let fontSize: CGFloat
    @Binding var isVisible: Bool
    
    var body: some View {
        Text("\(Int(fontSize))pt")
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(Color(uiModel: .editorText))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)
            .opacity(isVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isVisible)
    }
} 