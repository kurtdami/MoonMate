import SwiftUI

// Add any custom View extensions here
extension View {
    func hideOnDeactivate(_ shouldHide: Bool) -> some View {
        self.opacity(shouldHide ? 0 : 1)
            .animation(.easeInOut, value: shouldHide)
    }
}

// Add keyboard shortcut modifiers
extension View {
    func addCommandShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command, action: @escaping () -> Void) -> some View {
        self.keyboardShortcut(key, modifiers: modifiers)
    }
} 