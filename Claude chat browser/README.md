Now here's a proper tool that can read Claude's `.jsonl` chat files. Here are the best ways to use it:

## Quick Setup

1. **Save the script**:
```bash
curl -o claude-reader.sh [your-script-url]
# Or copy the script content to claude-reader.sh
chmod +x claude-reader.sh
```

2. **Install dependencies**:
```bash
# Ubuntu/Debian
sudo apt install python3 jq

# macOS  
brew install python3 jq
```

## Usage Examples

### Interactive Browser (Recommended)
```bash
./claude-reader.sh
```
This gives you a menu to:
- Browse all projects
- Select specific chats
- Export to markdown
- Search content

### Quick Commands
```bash
# List all projects
./claude-reader.sh --list

# View specific project
./claude-reader.sh "Docker Container Update Checker"

# Export project to markdown files
./claude-reader.sh "Docker Container Update Checker" --format markdown

# Search for content across all chats
./claude-reader.sh --content "update checker"

# Show recent projects
./claude-reader.sh --recent 5

# Export specific project to markdown file
./claude-reader.sh "Ubuntu Kernel Cleanup Script" --format markdown --output kernel-cleanup-chat.md
```

## What the Script Does

🔍 **Parses JSONL Format**: Converts Claude's JSON Lines chat format into human-readable text

📊 **Multiple Output Formats**:
- **Pretty**: Colored terminal output with emojis
- **Markdown**: Clean markdown for saving/sharing  
- **Raw**: Original JSON for debugging

🔎 **Smart Search**: 
- Search project names
- Search chat content across all files
- Find recent conversations

📤 **Export Options**:
- Export single chats
- Export entire projects
- Save as markdown files

## Sample Output

```
🤖 Claude JSONL Chat Browser
=============================

Available projects:

 1) Docker Container Update Checker   (3 chats, 45 msgs, 2025-09-20)
 2) Ubuntu Kernel Cleanup Script      (2 chats, 32 msgs, 2025-09-19)  
 3) System Management Tools           (1 chats, 18 msgs, 2025-09-18)

Options:
  1-3) Browse specific project
  l) List all projects with details
  r) Show recent projects
  c) Search chat content
  q) Quit

Enter choice: 1

💬 Project: Docker Container Update Checker
================================
Found 3 chat file(s):

 1) main-chat                    2.1KB      15 msgs 2025-09-20
 2) troubleshooting              1.8KB      12 msgs 2025-09-19
 3) feature-requests             3.2KB      18 msgs 2025-09-18

Choose an option:
  1-3) View specific chat
  a) View all chats
  e) Export all to markdown
  q) Quit
```

## Pro Tips

### Add to PATH for easy access:
```bash
# Move to bin directory
sudo mv claude-reader.sh /usr/local/bin/claude-reader
sudo chmod +x /usr/local/bin/claude-reader

# Now use from anywhere:
claude-reader --list
claude-reader "My Project" --format markdown
```

### Create aliases:
```bash
# Add to ~/.bashrc or ~/.zshrc
alias claude='claude-reader.sh'
alias claude-search='claude-reader.sh --content'
alias claude-recent='claude-reader.sh --recent'
```

### Quick export all projects:
```bash
# Export all projects to markdown
for project in ~/.claude/projects/*/; do
    project_name=$(basename "$project")
    ./claude-reader.sh "$project_name" --format markdown --output "${project_name}.md"
done
```

This tool will give you full access to read, search, and export all your Claude project conversations in a much more readable format than the raw JSONL files!