#!/bin/bash

# Claude JSONL Chat Reader
# Read and convert Claude project JSONL chat files to readable format

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

CLAUDE_DIR="$HOME/.claude/projects"

# Check if python3 and jq are available
PYTHON_AVAILABLE=false
JQ_AVAILABLE=false

if command -v python3 &> /dev/null; then
    PYTHON_AVAILABLE=true
fi

if command -v jq &> /dev/null; then
    JQ_AVAILABLE=true
fi

show_help() {
    cat << EOF
Claude JSONL Chat Reader

USAGE:
    $0 [OPTIONS] [PROJECT_NAME]

OPTIONS:
    -l, --list          List all available projects
    -s, --search TERM   Search for projects containing TERM
    -r, --recent N      Show N most recently modified projects (default: 10)
    -f, --format TYPE   Output format: pretty, markdown, raw (default: pretty)
    -o, --output FILE   Save output to file instead of displaying
    -c, --content TERM  Search for content within chats
    -h, --help          Show this help

FORMATS:
    pretty     - Colored terminal output (default)
    markdown   - Markdown format for saving
    raw        - Raw JSON output

EXAMPLES:
    $0                           # Interactive project browser
    $0 -l                        # List all projects
    $0 -r 5                      # Show 5 most recent projects
    $0 -s docker                 # Search for projects with 'docker' in name
    $0 my-project                # View specific project chats
    $0 my-project -f markdown    # View as markdown
    $0 my-project -o chat.md     # Save to markdown file
    $0 -c "update checker"       # Search chat content

REQUIREMENTS:
    - python3 (recommended) or jq for JSON parsing
    
INSTALLATION:
    # Ubuntu/Debian
    sudo apt install python3 jq
    
    # macOS
    brew install python3 jq
EOF
}

check_dependencies() {
    if [[ "$PYTHON_AVAILABLE" = false && "$JQ_AVAILABLE" = false ]]; then
        echo -e "${RED}❌ Neither python3 nor jq found!${NC}"
        echo ""
        echo "Please install one of them:"
        echo "  Ubuntu/Debian: sudo apt install python3 jq"
        echo "  macOS: brew install python3 jq"
        echo "  CentOS/RHEL: sudo yum install python3 jq"
        exit 1
    fi
    
    if [[ "$PYTHON_AVAILABLE" = true ]]; then
        PARSER="python"
    else
        PARSER="jq"
        echo -e "${YELLOW}💡 Using jq parser. Install python3 for better formatting.${NC}"
    fi
}

check_claude_dir() {
    if [[ ! -d "$CLAUDE_DIR" ]]; then
        echo -e "${RED}❌ Claude projects directory not found: $CLAUDE_DIR${NC}"
        echo "Make sure you have Claude Desktop installed and have created projects."
        exit 1
    fi
}

get_project_info() {
    local project_dir="$1"
    local project_name=$(basename "$project_dir")
    local jsonl_files=($(find "$project_dir" -name "*.jsonl" -type f 2>/dev/null))
    local file_count=${#jsonl_files[@]}
    local last_modified=""
    local total_messages=0
    
    if [[ $file_count -gt 0 ]]; then
        # Get most recent modification time
        last_modified=$(find "$project_dir" -name "*.jsonl" -type f -exec stat -c %Y {} \; 2>/dev/null | sort -n | tail -1)
        if [[ -n "$last_modified" ]]; then
            last_modified=$(date -d "@$last_modified" "+%Y-%m-%d %H:%M" 2>/dev/null || date -r "$last_modified" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
        fi
        
        # Count total messages across all jsonl files
        for file in "${jsonl_files[@]}"; do
            local count=$(wc -l < "$file" 2>/dev/null || echo 0)
            total_messages=$((total_messages + count))
        done
    fi
    
    echo "$project_name|$file_count|$total_messages|$last_modified|$project_dir"
}

list_projects() {
    echo -e "${BLUE}📁 Available Claude Projects${NC}"
    echo "================================"
    
    if [[ ! -d "$CLAUDE_DIR" || -z "$(ls -A "$CLAUDE_DIR" 2>/dev/null)" ]]; then
        echo -e "${YELLOW}No projects found in $CLAUDE_DIR${NC}"
        return
    fi
    
    echo -e "${CYAN}Project Name                 Chats  Messages   Last Modified        ${NC}"
    echo "------------------------------------------------------------------------"
    
    for project_dir in "$CLAUDE_DIR"/*; do
        if [[ -d "$project_dir" ]]; then
            info=$(get_project_info "$project_dir")
            IFS='|' read -r name files messages modified path <<< "$info"
            printf "%-28s %5s  %8s   %s\n" "$name" "$files" "$messages" "$modified"
        fi
    done
}

search_projects() {
    local search_term="$1"
    echo -e "${BLUE}🔍 Searching for projects containing: '$search_term'${NC}"
    echo "================================================"
    
    found=false
    for project_dir in "$CLAUDE_DIR"/*; do
        if [[ -d "$project_dir" ]]; then
            project_name=$(basename "$project_dir")
            if [[ "$project_name" == *"$search_term"* ]]; then
                info=$(get_project_info "$project_dir")
                IFS='|' read -r name files messages modified path <<< "$info"
                echo -e "${GREEN}✅ $name${NC} ($files chats, $messages messages, modified: $modified)"
                found=true
            fi
        fi
    done
    
    if [[ "$found" = false ]]; then
        echo -e "${YELLOW}No projects found matching '$search_term'${NC}"
    fi
}

search_content() {
    local search_term="$1"
    echo -e "${BLUE}🔍 Searching chat content for: '$search_term'${NC}"
    echo "=============================================="
    
    found=false
    for project_dir in "$CLAUDE_DIR"/*; do
        if [[ -d "$project_dir" ]]; then
            project_name=$(basename "$project_dir")
            
            for jsonl_file in "$project_dir"/*.jsonl; do
                if [[ -f "$jsonl_file" ]]; then
                    chat_name=$(basename "$jsonl_file" .jsonl)
                    
                    # Search in the jsonl file
                    if grep -q -i "$search_term" "$jsonl_file" 2>/dev/null; then
                        echo -e "${GREEN}📝 Found in: $project_name/${chat_name}${NC}"
                        
                        # Show matching lines with context
                        if [[ "$PARSER" = "python" ]]; then
                            python3 -c "
import json
import sys

search_term = '$search_term'.lower()
with open('$jsonl_file', 'r') as f:
    for i, line in enumerate(f, 1):
        try:
            data = json.loads(line)
            content = data.get('content', '')
            if search_term in content.lower():
                role = data.get('role', 'unknown')
                preview = content[:100] + '...' if len(content) > 100 else content
                print(f'   Line {i} ({role}): {preview}')
        except:
            pass
"
                        else
                            # Fallback with jq
                            grep -i -n "$search_term" "$jsonl_file" | head -3 | while read line; do
                                echo "   $line"
                            done
                        fi
                        echo ""
                        found=true
                    fi
                fi
            done
        fi
    done
    
    if [[ "$found" = false ]]; then
        echo -e "${YELLOW}No content found matching '$search_term'${NC}"
    fi
}

show_recent_projects() {
    local count=${1:-10}
    echo -e "${BLUE}⏰ $count Most Recently Modified Projects${NC}"
    echo "========================================"
    
    # Create temporary file with project info
    temp_file=$(mktemp)
    
    for project_dir in "$CLAUDE_DIR"/*; do
        if [[ -d "$project_dir" ]]; then
            info=$(get_project_info "$project_dir")
            IFS='|' read -r name files messages modified path <<< "$info"
            # Get timestamp for sorting
            if [[ -n "$modified" && "$modified" != "unknown" ]]; then
                timestamp=$(find "$project_dir" -name "*.jsonl" -type f -exec stat -c %Y {} \; 2>/dev/null | sort -n | tail -1)
                echo "$timestamp|$name|$files|$messages|$modified" >> "$temp_file"
            fi
        fi
    done
    
    # Sort by timestamp and show top N
    sort -nr "$temp_file" | head -n "$count" | while IFS='|' read -r timestamp name files messages modified; do
        echo -e "${GREEN}📝 $name${NC} ($files chats, $messages messages, $modified)"
    done
    
    rm -f "$temp_file"
}

parse_jsonl_python() {
    local file="$1"
    local format="$2"
    local output_file="$3"
    
    python3 -c "
import json
import sys
from datetime import datetime

def format_timestamp(ts):
    try:
        if isinstance(ts, (int, float)):
            return datetime.fromtimestamp(ts / 1000 if ts > 1000000000000 else ts).strftime('%Y-%m-%d %H:%M:%S')
        return str(ts)
    except:
        return 'Unknown time'

def format_content(content, role):
    if not content:
        return 'No content'
    
    # Handle different content types
    if isinstance(content, list):
        text_parts = []
        for item in content:
            if isinstance(item, dict):
                if item.get('type') == 'text':
                    text_parts.append(item.get('text', ''))
                elif item.get('type') == 'tool_use':
                    text_parts.append(f'[Tool: {item.get(\"name\", \"unknown\")}]')
                elif item.get('type') == 'tool_result':
                    text_parts.append('[Tool Result]')
            else:
                text_parts.append(str(item))
        return ' '.join(text_parts)
    
    return str(content)

format_type = '$format'
output_file = '$output_file'

messages = []
with open('$file', 'r', encoding='utf-8') as f:
    for line_num, line in enumerate(f, 1):
        try:
            data = json.loads(line.strip())
            messages.append(data)
        except json.JSONDecodeError as e:
            print(f'Error parsing line {line_num}: {e}', file=sys.stderr)

if not messages:
    print('No valid messages found')
    sys.exit(1)

output_lines = []

if format_type == 'markdown':
    output_lines.append('# Claude Chat Export\\n')
    output_lines.append(f'Generated: {datetime.now().strftime(\"%Y-%m-%d %H:%M:%S\")}\\n')
    output_lines.append(f'Total messages: {len(messages)}\\n\\n')
    
    for i, msg in enumerate(messages, 1):
        role = msg.get('role', 'unknown').title()
        content = format_content(msg.get('content'), role)
        timestamp = format_timestamp(msg.get('created_at', ''))
        
        output_lines.append(f'## Message {i} - {role}\\n')
        output_lines.append(f'**Time:** {timestamp}\\n\\n')
        output_lines.append(f'{content}\\n\\n')
        output_lines.append('---\\n\\n')

elif format_type == 'raw':
    for msg in messages:
        output_lines.append(json.dumps(msg, indent=2))

else:  # pretty format
    for i, msg in enumerate(messages, 1):
        role = msg.get('role', 'unknown')
        content = format_content(msg.get('content'), role)
        timestamp = format_timestamp(msg.get('created_at', ''))
        
        if role == 'user':
            color = '\033[0;32m'  # Green
        elif role == 'assistant':
            color = '\033[0;34m'  # Blue
        else:
            color = '\033[0;33m'  # Yellow
        
        reset = '\033[0m'
        
        output_lines.append(f'{color}📧 Message {i} - {role.title()}{reset}')
        output_lines.append(f'🕒 {timestamp}')
        output_lines.append(f'💬 {content}')
        output_lines.append('─' * 80)

result = '\\n'.join(output_lines)

if output_file and output_file != '-':
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(result)
    print(f'Chat exported to: {output_file}')
else:
    print(result)
"
}

parse_jsonl_jq() {
    local file="$1"
    local format="$2"
    local output_file="$3"
    
    if [[ "$format" = "raw" ]]; then
        if [[ -n "$output_file" && "$output_file" != "-" ]]; then
            jq '.' "$file" > "$output_file"
            echo "Raw JSON exported to: $output_file"
        else
            jq '.' "$file"
        fi
    else
        # Simple text extraction with jq
        local output=""
        local count=1
        
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                role=$(echo "$line" | jq -r '.role // "unknown"')
                content=$(echo "$line" | jq -r '.content // "No content"')
                timestamp=$(echo "$line" | jq -r '.created_at // "Unknown time"')
                
                if [[ "$format" = "markdown" ]]; then
                    output+="\n## Message $count - ${role^}\n"
                    output+="**Time:** $timestamp\n\n"
                    output+="$content\n\n"
                    output+="---\n\n"
                else
                    output+="\n📧 Message $count - ${role^}\n"
                    output+="🕒 $timestamp\n"
                    output+="💬 $content\n"
                    output+="$(printf '─%.0s' {1..80})\n"
                fi
                ((count++))
            fi
        done < "$file"
        
        if [[ -n "$output_file" && "$output_file" != "-" ]]; then
            echo -e "$output" > "$output_file"
            echo "Chat exported to: $output_file"
        else
            echo -e "$output"
        fi
    fi
}

view_chat() {
    local file="$1"
    local format="${2:-pretty}"
    local output_file="$3"
    local filename=$(basename "$file")
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}❌ File not found: $file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}💬 Viewing: $filename${NC}"
    echo "================================"
    echo ""
    
    if [[ "$PARSER" = "python" ]]; then
        parse_jsonl_python "$file" "$format" "$output_file"
    else
        parse_jsonl_jq "$file" "$format" "$output_file"
    fi
}

browse_project() {
    local project_dir="$1"
    local format="${2:-pretty}"
    local output_file="$3"
    local project_name=$(basename "$project_dir")
    
    # Get all jsonl files in the project
    local chat_files=($(find "$project_dir" -name "*.jsonl" -type f 2>/dev/null | sort))
    
    if [[ ${#chat_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No JSONL chat files found in project: $project_name${NC}"
        return
    fi
    
    echo -e "${BLUE}💬 Project: $project_name${NC}"
    echo "================================"
    echo -e "${CYAN}Found ${#chat_files[@]} chat file(s):${NC}"
    echo ""
    
    # Show files with numbers and message counts
    for i in "${!chat_files[@]}"; do
        local file="${chat_files[$i]}"
        local filename=$(basename "$file" .jsonl)
        local size=$(du -h "$file" 2>/dev/null | cut -f1)
        local modified=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1 || stat -f %Sm -t %Y-%m-%d "$file" 2>/dev/null || echo "unknown")
        local msg_count=$(wc -l < "$file" 2>/dev/null || echo "0")
        printf "%2d) %-30s %8s %10s msgs %s\n" $((i+1)) "$filename" "$size" "$msg_count" "$modified"
    done
    
    echo ""
    echo -e "${YELLOW}Choose an option:${NC}"
    echo "  1-${#chat_files[@]}) View specific chat"
    echo "  a) View all chats"
    echo "  e) Export all to markdown"
    echo "  q) Quit"
    echo ""
    
    while true; do
        read -p "Enter choice: " choice
        
        case "$choice" in
            [1-9]*)
                if [[ "$choice" -ge 1 && "$choice" -le ${#chat_files[@]} ]]; then
                    view_chat "${chat_files[$((choice-1))]}" "$format" "$output_file"
                    echo ""
                    read -p "Press Enter to continue..."
                    break
                else
                    echo -e "${RED}Invalid selection. Please choose 1-${#chat_files[@]}${NC}"
                fi
                ;;
            "a"|"A")
                for file in "${chat_files[@]}"; do
                    echo ""
                    echo -e "${CYAN}" + "="*60 + "${NC}"
                    view_chat "$file" "$format"
                    echo ""
                    read -p "Press Enter for next chat (or 'q' to stop)..." next
                    if [[ "$next" == "q" ]]; then
                        break
                    fi
                done
                break
                ;;
            "e"|"E")
                local export_dir="${project_name}_export_$(date +%Y%m%d_%H%M%S)"
                mkdir -p "$export_dir"
                echo -e "${BLUE}📤 Exporting all chats to markdown in: $export_dir${NC}"
                
                for file in "${chat_files[@]}"; do
                    local chat_name=$(basename "$file" .jsonl)
                    local export_file="$export_dir/${chat_name}.md"
                    view_chat "$file" "markdown" "$export_file" > /dev/null
                done
                
                echo -e "${GREEN}✅ All chats exported to: $export_dir/${NC}"
                ls -la "$export_dir"
                break
                ;;
            "q"|"Q")
                break
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter a number, 'a', 'e', or 'q'${NC}"
                ;;
        esac
    done
}

interactive_browser() {
    echo -e "${BLUE}🤖 Claude JSONL Chat Browser${NC}"
    echo "============================="
    echo ""
    
    # Get projects sorted by modification time
    projects=()
    while IFS= read -r -d '' project_dir; do
        if [[ -d "$project_dir" ]]; then
            projects+=("$project_dir")
        fi
    done < <(find "$CLAUDE_DIR" -maxdepth 1 -type d ! -path "$CLAUDE_DIR" -print0 2>/dev/null | sort -z)
    
    if [[ ${#projects[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No projects found in $CLAUDE_DIR${NC}"
        return
    fi
    
    echo -e "${CYAN}Available projects:${NC}"
    echo ""
    
    for i in "${!projects[@]}"; do
        local project_dir="${projects[$i]}"
        local info=$(get_project_info "$project_dir")
        IFS='|' read -r name files messages modified path <<< "$info"
        printf "%2d) %-25s (%s chats, %s msgs, %s)\n" $((i+1)) "$name" "$files" "$messages" "$modified"
    done
    
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  1-${#projects[@]}) Browse specific project"
    echo "  l) List all projects with details"
    echo "  r) Show recent projects"
    echo "  c) Search chat content"
    echo "  q) Quit"
    echo ""
    
    while true; do
        read -p "Enter choice: " choice
        
        case "$choice" in
            [1-9]*)
                if [[ "$choice" -ge 1 && "$choice" -le ${#projects[@]} ]]; then
                    browse_project "${projects[$((choice-1))]}"
                    break
                else
                    echo -e "${RED}Invalid selection. Please choose 1-${#projects[@]}${NC}"
                fi
                ;;
            "l"|"L")
                list_projects
                echo ""
                read -p "Press Enter to continue..."
                ;;
            "r"|"R")
                show_recent_projects 10
                echo ""
                read -p "Press Enter to continue..."
                ;;
            "c"|"C")
                read -p "Enter search term: " search_term
                if [[ -n "$search_term" ]]; then
                    search_content "$search_term"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            "q"|"Q")
                echo -e "${BLUE}👋 Goodbye!${NC}"
                break
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter a number, 'l', 'r', 'c', or 'q'${NC}"
                ;;
        esac
    done
}

# Main script logic
main() {
    check_dependencies
    check_claude_dir
    
    local format="pretty"
    local output_file=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--list)
                list_projects
                exit 0
                ;;
            -s|--search)
                if [[ -n "$2" ]]; then
                    search_projects "$2"
                    shift 2
                else
                    echo -e "${RED}Error: --search requires a search term${NC}"
                    exit 1
                fi
                exit 0
                ;;
            -c|--content)
                if [[ -n "$2" ]]; then
                    search_content "$2"
                    shift 2
                else
                    echo -e "${RED}Error: --content requires a search term${NC}"
                    exit 1
                fi
                exit 0
                ;;
            -r|--recent)
                count=${2:-10}
                if [[ "$count" =~ ^[0-9]+$ ]]; then
                    show_recent_projects "$count"
                    shift 2
                else
                    show_recent_projects 10
                    shift
                fi
                exit 0
                ;;
            -f|--format)
                if [[ -n "$2" ]]; then
                    format="$2"
                    shift 2
                else
                    echo -e "${RED}Error: --format requires a format type${NC}"
                    exit 1
                fi
                ;;
            -o|--output)
                if [[ -n "$2" ]]; then
                    output_file="$2"
                    shift 2
                else
                    echo -e "${RED}Error: --output requires a filename${NC}"
                    exit 1
                fi
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
            *)
                # Assume it's a project name
                project_path="$CLAUDE_DIR/$1"
                if [[ -d "$project_path" ]]; then
                    browse_project "$project_path" "$format" "$output_file"
                else
                    echo -e "${RED}Project not found: $1${NC}"
                    echo "Available projects:"
                    list_projects
                fi
                exit 0
                ;;
        esac
    done
    
    # If no arguments, start interactive browser
    interactive_browser
}

main "$@"