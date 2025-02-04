# MoonMate

MoonMate is an elegant, distraction-free writing application built with SwiftUI for macOS. It provides a clean, focused environment for writers to concentrate on their content creation.

## Features

- 🌗 Dark/Light theme toggle for comfortable writing in any lighting condition
- 📝 Minimalist, distraction-free writing interface
- 📚 Document management with sidebar navigation
- 💾 Automatic document saving
- 📊 Word and character count tracking
- ⌨️ Keyboard shortcuts for enhanced productivity
- 🖥️ Full-screen mode support
- 📐 Adjustable font size
- 📱 Responsive layout with minimum window size constraints

## Keyboard Shortcuts

- `⌘ + S`: Save document
- `⌘ + ⇧ + S`: Toggle sidebar
- `⌘ + ⇧ + T`: Toggle theme

## System Requirements

- macOS (Built with SwiftUI)
- Xcode 15.0 or later for development

## Development Setup

1. Clone the repository:
```bash
git clone https://github.com/kurtdami/MoonMate.git
```

2. Open the project in Xcode:
```bash
cd MoonMate
open MoonMate.xcodeproj
```

3. Build and run the project in Xcode

## Project Structure

- `MoonMate/`: Main application source code
  - `Views/`: SwiftUI views including EditorView and DocumentListView
  - `ViewModels/`: Contains the DocumentViewModel for state management
  - `Services/`: Core services like DocumentManager
  - `Extensions/`: Swift extensions for enhanced functionality
  - `Shared/`: Shared models and utilities

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

Created by Kurt Mi

---

*MoonMate - Your companion for distraction-free writing* 