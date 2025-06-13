# CCP Clipboard Manager

A powerful macOS clipboard manager that supports text, images, and file clipboard history management.

## Features

- ✅ **Text Clipboard History** - Automatically saves all copied text
- ✅ **Image Clipboard Support** - Supports screenshots and image data
- ✅ **Image File Copy Support** - Automatically reads file content when copying image files
- ✅ **Hotkey Support** - Use `Cmd+Shift+V` to quickly open clipboard history
- ✅ **System Tray Integration** - Resides in system tray for easy access
- ✅ **Auto Paste Function** - Automatically pastes after selecting history items
- ✅ **Native macOS Integration** - Uses native APIs for optimal performance

## Quick Start

### Using Makefile (Recommended)

```bash
# View all available commands
make help

# Development mode (kill existing processes + build + run)
make dev

# Run application only
make run

# Build debug version
make build

# Kill all ccp processes
make kill
```

### Release and Installation

```bash
# Build release version
make release

# Build and install to Applications folder
make install

# Complete deployment process (build + install + run)
make deploy
```

## Usage

1. **Launch Application** - The app automatically minimizes to system tray
2. **Copy Content** - Copy text, take screenshots, or copy image files normally
3. **View History** - Press `Cmd+Shift+V` to open clipboard history
4. **Select Items** - Use arrow keys or mouse to select, press Enter or click to paste
5. **Quick Access** - Use `Cmd+1-9` and `Cmd+0` to quickly select the first 10 items

## Permissions

The application requires the following permissions to work properly:

1. **Accessibility Permission** - For simulating keystrokes and auto-paste
   - Path: System Preferences > Security & Privacy > Accessibility
   - Add application: `/path/to/ccp.app`

2. **File Access Permission** - For reading copied image files
   - The app is configured to disable sandbox for file system access

## License

MIT License
