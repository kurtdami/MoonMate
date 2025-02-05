//
//  MoonMateApp.swift
//  MoonMate
//
//  Created by Kurt Mi on 2/3/25.
//

import SwiftUI

@main
struct MoonMateApp: App {
    @StateObject private var viewModel = DocumentViewModel()
    
    var body: some Scene {
        WindowGroup {
            EditorView(viewModel: viewModel)
                .frame(minWidth: 600, minHeight: 400)
                .background(viewModel.backgroundColor)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Save") {
                    viewModel.saveDocument()
                }
                .keyboardShortcut("S", modifiers: .command)
                
                Button("Toggle Sidebar") {
                    viewModel.toggleSidebar()
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])
                
                Button("Toggle Theme") {
                    viewModel.toggleTheme()
                }
                .keyboardShortcut("T", modifiers: [.command, .shift])
            }
        }
    }
}
