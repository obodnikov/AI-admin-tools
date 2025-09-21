# System Management Tools

This project contains utility applications designed to help with system administration, maintenance tasks, web development, and productivity.

## Applications

### 🐳 Docker Container Update Checker
**Directory:** `Docker Container Update Checker/`

A comprehensive Python script that automatically monitors running Docker containers and checks for available image updates across multiple container registries. Sends notifications via Telegram when updates are detected.

**Key Features:**
- **Multi-Registry Support**: Docker Hub, LinuxServer.io (lscr.io), GitHub Container Registry (ghcr.io), Red Hat Quay (quay.io)
- **Smart Update Detection**: Semantic version comparison for Docker Hub, digest-based comparison for other registries
- **Telegram Integration**: Formatted notifications with update details
- **Intelligent Filtering**: Skips pre-release tags (latest, rc, beta, alpha, dev, etc.)
- **Configurable**: Ignore specific containers, customize skip tags
- **Cron Compatible**: Designed for automated scheduled execution
- **Comprehensive Logging**: Debug mode for troubleshooting

**Requirements:** Python 3.6+, Docker, Telegram Bot

### 🧹 Ubuntu Kernel Cleanup Script
**Directory:** `Ubuntu Kernel Cleanup Script/`

A sophisticated bash script that safely removes old kernel packages from Ubuntu systems while maintaining system stability. Features comprehensive safety checks and interactive confirmation.

**Key Features:**
- **Safety First**: Always preserves currently running kernel and latest installed kernel
- **Flexible Configuration**: Customizable number of additional kernels to keep
- **Dry Run Mode**: Preview changes before execution with detailed package listings
- **Comprehensive Detection**: Handles all kernel package types (images, headers, modules, modules-extra)
- **Interactive Confirmation**: Requires user approval before making changes
- **GRUB Integration**: Automatically updates bootloader configuration
- **Detailed Logging**: Color-coded output with progress reporting

**Requirements:** Ubuntu/Debian system, sudo privileges, Bash 4.0+

### 🎨 Web Icons Generator
**Directory:** `Web Icons Generator/`

A smart bash script that automatically generates all required PWA (Progressive Web App) icons from a single SVG source file. Features cross-platform ImageMagick compatibility and intelligent file management.

**Key Features:**
- **Complete PWA Icon Set**: Generates favicon.ico, apple-touch-icon, and multiple resolution PNG files
- **Maskable Icons Support**: Creates adaptive icons with proper safe zones for Android
- **Smart Detection**: Only generates missing files, preserves existing icons
- **Cross-Platform Compatibility**: Works with both ImageMagick 6.x and 7.x
- **Quality Optimization**: Maintains vector quality from SVG source
- **Progress Reporting**: Color-coded status updates and file information
- **Built-in Validation**: Checks requirements and provides helpful error messages

**Requirements:** ImageMagick (6.x or 7.x), SVG source file named `favicon.svg`

### 💬 Claude Chat Browser
**Directory:** `Claude chat browser/`

A powerful Python-based tool for reading, browsing, and exporting Claude Desktop's JSONL chat files in human-readable formats. Features both interactive and command-line interfaces.

**Key Features:**
- **Interactive Browser**: Menu-driven interface for exploring projects and chats
- **Multiple Output Formats**: Pretty terminal display, Markdown export, raw JSON
- **Advanced Search**: Search project names and chat content across all conversations
- **Smart Navigation**: Paginated viewing with vim-like controls (j/k, space, etc.)
- **Export Capabilities**: Save individual chats or entire projects as Markdown files
- **Content Parsing**: Handles tool usage, attachments, and complex message structures
- **Cross-Platform**: Pure Python implementation with terminal size detection

**Key Scripts:**
- `claude_chat_browser.sh` - Bash wrapper with dependency detection
- `claude_chat_reader.py` - Pure Python implementation

**Requirements:** Python 3.6+, optional: jq for bash script

## Quick Start

### Docker Container Update Checker
```bash
# Install dependencies
pip3 install requests packaging configparser

# Configure Telegram bot and chat ID
sudo mkdir -p /etc/docker-update-checker
# Edit config file with your Telegram credentials

# Run manually
python3 docker_update_checker.py

# Or set up automated checking
sudo crontab -e
# Add: 0 8 * * * /usr/bin/python3 /path/to/docker_update_checker.py
```

### Ubuntu Kernel Cleanup Script
```bash
# Make executable
chmod +x kernel_cleanup.sh

# Preview what would be removed (dry run)
./kernel_cleanup.sh --keep 1 --dry-run

# Actually remove old kernels (with confirmation)
./kernel_cleanup.sh --keep 1
```

### Web Icons Generator
```bash
# Ensure you have favicon.svg in current directory
# Make executable
chmod +x generate_icons.sh

# Generate missing PWA icons
./generate_icons.sh
```

### Claude Chat Browser
```bash
# Interactive browser
./claude_chat_browser.sh

# Quick commands
./claude_chat_browser.sh --list                    # List all projects
./claude_chat_browser.sh "My Project"              # Browse specific project
./claude_chat_browser.sh --content "search term"   # Search chat content
./claude_chat_browser.sh "Project" --format markdown --output export.md
```

## Installation

Each tool can be installed independently. Clone the repository and navigate to the specific tool directory for detailed installation instructions.

```bash
git clone <repository-url>
cd system-management-tools

# Navigate to specific tool directory
cd "Docker Container Update Checker"
# Follow tool-specific README instructions
```

## Project Structure

```
system-management-tools/
├── Docker Container Update Checker/
│   ├── docker-update-checker.py      # Main Python script
│   ├── docker-checker-config.txt     # Sample configuration
│   └── docker-checker-docs.md        # Comprehensive documentation
├── Ubuntu Kernel Cleanup Script/
│   ├── kernel_cleanup_script.sh      # Main bash script
│   └── kernel_cleanup_documentation.md  # Detailed documentation
├── Web Icons Generator/
│   ├── generate_icons.sh             # Main bash script
│   └── README.md                     # Usage guide
├── Claude chat browser/
│   ├── claude_chat_browser.sh        # Bash wrapper script
│   ├── claude_chat_reader.py         # Pure Python implementation
│   └── README.md                     # Setup and usage guide
└── README.md                         # This file
```

## System Requirements

### General
- Unix-like operating system (Linux, macOS, Windows WSL)
- Appropriate system permissions for administration tasks
- Internet connection for update checking and notifications

### Tool-Specific
- **Docker Update Checker**: Python 3.6+, Docker daemon, Telegram Bot
- **Kernel Cleanup**: Ubuntu/Debian system, sudo access
- **Icons Generator**: ImageMagick (any version), SVG source file
- **Chat Browser**: Python 3.6+, Claude Desktop with projects

## Security Considerations

- All scripts include safety checks and require explicit confirmation for destructive operations
- Configuration files should have restricted permissions (600) when containing sensitive data
- Docker Update Checker supports authenticated registries for private repositories
- Kernel Cleanup Script preserves critical kernels and updates bootloader safely

## Contributing

Each tool is self-contained and can be improved independently. When contributing:

1. Test thoroughly with dry-run modes where available
2. Maintain backward compatibility
3. Update documentation for new features
4. Follow existing code style and safety patterns
5. Add appropriate error handling and user feedback

## License

These tools are provided as-is for system administration and productivity purposes. Use at your own discretion in production environments.