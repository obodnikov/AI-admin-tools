#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    cat << 'EOF'
🎨 Web Icons Generator

Usage: generate_icons.sh [INPUT_FILE]

Arguments:
    INPUT_FILE    Path to source image (PNG, SVG, JPG, or other format)
                  Default: favicon.svg (if it exists in current directory)

Examples:
    generate_icons.sh                # Use favicon.svg if it exists
    generate_icons.sh my-icon.png    # Generate from PNG file
    generate_icons.sh /path/to/logo.svg  # Generate from SVG file
    generate_icons.sh favicon.jpg    # Generate from JPG file

Notes:
    - SVG format recommended for best quality at all sizes
    - PNG/JPG will be scaled but quality may degrade at larger sizes
    - Source image should be at least 512x512 pixels for best results

EOF
}

# Function to run ImageMagick commands with the detected version
run_imagemagick() {
    local input="$1"
    local options="$2"
    local output="$3"
    
    if command -v magick &> /dev/null; then
        # ImageMagick 7.x syntax
        magick "$input" $options "$output"
    else
        # ImageMagick 6.x syntax
        convert "$input" $options "$output"
    fi
}

# Function to get image info
get_image_info() {
    local file="$1"
    
    if command -v identify &> /dev/null; then
        identify -format "%wx%h" "$file" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Main function - wrapped to avoid destroying parent shell
main() {
    local exit_code=0
    
    echo -e "${BLUE}🎨 Web Icons Generator${NC}"
    echo "=================================="

    # Parse input argument
    local SOURCE_FILE="${1:-favicon.svg}"

    # Show help if -h or --help is passed
    if [[ "$SOURCE_FILE" == "-h" ]] || [[ "$SOURCE_FILE" == "--help" ]]; then
        usage
        return 0
    fi

    # Detect ImageMagick command (works for both v6 and v7)
    local MAGICK_CMD=""
    local MAGICK_VERSION=""

    if command -v magick &> /dev/null; then
        MAGICK_CMD="magick"
        MAGICK_VERSION="ImageMagick 7.x (magick command)"
    elif command -v convert &> /dev/null; then
        MAGICK_CMD="convert"
        MAGICK_VERSION="ImageMagick 6.x (convert command)"
    else
        echo -e "${RED}❌ ImageMagick is required but not installed.${NC}"
        echo ""
        echo "Install it with:"
        echo -e "  ${YELLOW}Ubuntu/Debian:${NC} sudo apt install imagemagick"
        echo -e "  ${YELLOW}macOS:${NC} brew install imagemagick"
        echo -e "  ${YELLOW}Windows:${NC} Download from https://imagemagick.org/"
        echo ""
        echo "After installation, you should have either 'magick' or 'convert' command available."
        return 1
    fi

    # Check if source file exists
    if [ ! -f "$SOURCE_FILE" ]; then
        echo -e "${RED}❌ Source file not found: $SOURCE_FILE${NC}"
        echo ""
        usage
        return 1
    fi

    # Get file extension and type
    local FILE_EXT="${SOURCE_FILE##*.}"
    local FILE_EXT_LOWER=$(echo "$FILE_EXT" | tr '[:upper:]' '[:lower:]')

    # Warn if using raster format
    if [[ "$FILE_EXT_LOWER" == "png" ]] || [[ "$FILE_EXT_LOWER" == "jpg" ]] || [[ "$FILE_EXT_LOWER" == "jpeg" ]]; then
        echo -e "${YELLOW}⚠️  Warning: Using raster image format ($FILE_EXT_LOWER)${NC}"
        echo -e "${YELLOW}   SVG format recommended for best quality at all sizes${NC}"
        echo ""
    fi

    echo -e "${GREEN}✅ ${MAGICK_VERSION} found${NC}"
    echo -e "${GREEN}✅ Source file found: $SOURCE_FILE ($FILE_EXT_LOWER format)${NC}"
    echo ""

    # Define required icons (Bash 3.2 compatible - no associative arrays)
    # Format: "filename|size|spec" where spec may contain resize options
    local icons=(
        "favicon.ico|32x32"
        "apple-touch-icon.png|180x180"
        "icon-192.png|192x192"
        "icon-512.png|512x512"
        "icon-maskable-192.png|192x192+maskable"
        "icon-maskable-512.png|512x512+maskable"
    )

    # Track what needs to be generated
    local missing_files=()
    local existing_files=()

    # Check which files exist
    echo "📋 Checking existing icon files..."
    for icon_spec in "${icons[@]}"; do
        local filename="${icon_spec%%|*}"
        if [ -f "$filename" ]; then
            existing_files+=("$filename")
            echo -e "   ${GREEN}✅ $filename${NC}"
        else
            missing_files+=("$filename")
            echo -e "   ${RED}❌ $filename${NC}"
        fi
    done

    echo ""

    # If all files exist, ask if user wants to regenerate
    if [ ${#missing_files[@]} -eq 0 ]; then
        echo -e "${GREEN}🎉 All icon files already exist!${NC}"
        echo ""
        read -p "Do you want to regenerate all icons? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}🔄 Regenerating all icons from $SOURCE_FILE...${NC}"
            missing_files=()
            for icon_spec in "${icons[@]}"; do
                local filename="${icon_spec%%|*}"
                missing_files+=("$filename")
            done
        else
            echo -e "${BLUE}👍 No changes needed. Exiting.${NC}"
            return 0
        fi
    else
        echo -e "${YELLOW}🔧 Found ${#missing_files[@]} missing icon file(s).${NC}"
        echo "Missing files: ${missing_files[*]}"
        echo ""
        read -p "Generate missing icons from $SOURCE_FILE? (Y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo -e "${BLUE}👋 Cancelled by user.${NC}"
            return 0
        fi
    fi

    echo ""
    echo -e "${BLUE}🚀 Generating icons from $SOURCE_FILE...${NC}"
    echo ""

    # Generate missing icons
    local generated_count=0
    for missing_file in "${missing_files[@]}"; do
        # Find the spec for this file
        local file_size=""
        local is_maskable=0
        
        for icon_spec in "${icons[@]}"; do
            local filename="${icon_spec%%|*}"
            if [ "$filename" = "$missing_file" ]; then
                local size_part="${icon_spec#*|}"
                file_size="${size_part%%+*}"
                if [[ "$size_part" == *"+maskable"* ]]; then
                    is_maskable=1
                fi
                break
            fi
        done
        
        if [ $is_maskable -eq 1 ]; then
            # Maskable icon with safe zone
            # For 192x192: inner 154x154, For 512x512: inner 410x410
            local size_val="${file_size%x*}"
            local inner_size=0
            if [ "$size_val" = "192" ]; then
                inner_size="154"
            elif [ "$size_val" = "512" ]; then
                inner_size="410"
            else
                # Calculate 80% for other sizes
                inner_size=$((size_val * 80 / 100))
            fi
            
            echo -e "   ${YELLOW}🎭 Generating maskable icon: $missing_file${NC}"
            if run_imagemagick "$SOURCE_FILE" "-resize ${inner_size}x${inner_size} -background transparent -gravity center -extent $file_size" "$missing_file" 2>/dev/null; then
                echo -e "   ${GREEN}✅ Created $missing_file (${file_size} with safe zone)${NC}"
                ((generated_count++))
            else
                echo -e "   ${RED}❌ Failed to create $missing_file${NC}"
                exit_code=1
            fi
        else
            # Standard icon
            echo -e "   ${YELLOW}🖼️ Generating icon: $missing_file${NC}"
            if run_imagemagick "$SOURCE_FILE" "-resize $file_size" "$missing_file" 2>/dev/null; then
                echo -e "   ${GREEN}✅ Created $missing_file (${file_size})${NC}"
                ((generated_count++))
            else
                echo -e "   ${RED}❌ Failed to create $missing_file${NC}"
                exit_code=1
            fi
        fi
    done

    echo ""
    echo "=================================="
    if [ $generated_count -gt 0 ]; then
        echo -e "${GREEN}🎉 Successfully generated $generated_count icon file(s)!${NC}"
        echo ""
        echo -e "${BLUE}📁 Current icon files:${NC}"
        for icon_spec in "${icons[@]}"; do
            local filename="${icon_spec%%|*}"
            if [ -f "$filename" ]; then
                local size=$(get_image_info "$filename")
                echo -e "   ${GREEN}✅ $filename${NC} (${size})"
            fi
        done
        echo ""
        echo -e "${BLUE}💡 Next steps:${NC}"
        echo "   1. Add manifest.json to your project"
        echo "   2. Update index.html with manifest link"
        echo "   3. Test PWA functionality in Chrome DevTools"
    else
        echo -e "${YELLOW}⚠️ No icons were generated.${NC}"
        exit_code=1
    fi

    echo ""
    echo -e "${BLUE}🔗 Useful links:${NC}"
    echo "   • Test PWA: Chrome DevTools → Application → Manifest"
    echo "   • Lighthouse audit: Chrome DevTools → Lighthouse → PWA"
    echo "   • Icon validator: https://realfavicongenerator.net/favicon_checker"
    echo ""
    echo -e "${BLUE}🔧 ImageMagick info:${NC}"
    echo "   • Command used: $MAGICK_CMD"
    echo "   • Version: $MAGICK_VERSION"
    echo "   • Source file: $SOURCE_FILE"
    
    return $exit_code
}

# ============================================================================
# Source detection: Determine if script is being sourced or directly executed
# This prevents parent shell destruction when sourcing
# ============================================================================

_IS_SOURCED=0
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
        _IS_SOURCED=1
    fi
fi

# Execute with appropriate exit handling
if [[ $_IS_SOURCED -eq 1 ]]; then
    main "$@"
else
    main "$@"
    exit $?
fi
