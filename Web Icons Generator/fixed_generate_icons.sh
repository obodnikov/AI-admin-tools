#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🌿 Pollen Tracker Icon Generator${NC}"
echo "=================================="

# Detect ImageMagick command (works for both v6 and v7)
MAGICK_CMD=""
MAGICK_VERSION=""

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
    exit 1
fi

# Check if source favicon.svg exists
if [ ! -f "favicon.svg" ]; then
    echo -e "${RED}❌ favicon.svg not found in current directory.${NC}"
    echo "Please ensure favicon.svg exists before running this script."
    exit 1
fi

echo -e "${GREEN}✅ ${MAGICK_VERSION} found${NC}"
echo -e "${GREEN}✅ favicon.svg found${NC}"
echo ""

# Function to run ImageMagick commands with the detected version
run_imagemagick() {
    local input="$1"
    local options="$2"
    local output="$3"
    
    if [[ "$MAGICK_CMD" == "magick" ]]; then
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
    elif [[ "$MAGICK_CMD" == "magick" ]]; then
        magick identify -format "%wx%h" "$file" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Define required icons with their specifications
declare -A icons=(
    ["favicon.ico"]="32x32:favicon.ico"
    ["apple-touch-icon.png"]="180x180:apple-touch-icon.png"
    ["icon-192.png"]="192x192:icon-192.png"
    ["icon-512.png"]="512x512:icon-512.png"
    ["icon-maskable-192.png"]="154x154+192x192:icon-maskable-192.png"
    ["icon-maskable-512.png"]="410x410+512x512:icon-maskable-512.png"
)

# Track what needs to be generated
missing_files=()
existing_files=()

# Check which files exist
echo "📋 Checking existing icon files..."
for file in "${!icons[@]}"; do
    if [ -f "$file" ]; then
        existing_files+=("$file")
        echo -e "   ${GREEN}✅ $file${NC}"
    else
        missing_files+=("$file")
        echo -e "   ${RED}❌ $file${NC}"
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
        echo -e "${YELLOW}🔄 Regenerating all icons...${NC}"
        missing_files=("${!icons[@]}")
    else
        echo -e "${BLUE}👍 No changes needed. Exiting.${NC}"
        exit 0
    fi
else
    echo -e "${YELLOW}🔧 Found ${#missing_files[@]} missing icon file(s).${NC}"
    echo "Missing files: ${missing_files[*]}"
    echo ""
    read -p "Generate missing icons? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${BLUE}👋 Cancelled by user.${NC}"
        exit 0
    fi
fi

echo ""
echo -e "${BLUE}🚀 Generating icons...${NC}"
echo ""

# Generate missing icons
generated_count=0
for file in "${missing_files[@]}"; do
    spec="${icons[$file]}"
    
    if [[ $spec == *"+"* ]]; then
        # Maskable icon with safe zone
        IFS='+' read -r inner_size outer_size <<< "$spec"
        IFS=':' read -r size_part filename <<< "$outer_size"
        
        echo -e "   ${YELLOW}🎭 Generating maskable icon: $filename${NC}"
        if run_imagemagick "favicon.svg" "-resize $inner_size -background transparent -gravity center -extent $size_part" "$filename" 2>/dev/null; then
            echo -e "   ${GREEN}✅ Created $filename (${size_part} with safe zone)${NC}"
            ((generated_count++))
        else
            echo -e "   ${RED}❌ Failed to create $filename${NC}"
        fi
    else
        # Standard icon
        IFS=':' read -r size filename <<< "$spec"
        
        echo -e "   ${YELLOW}🖼️ Generating icon: $filename${NC}"
        if run_imagemagick "favicon.svg" "-resize $size" "$filename" 2>/dev/null; then
            echo -e "   ${GREEN}✅ Created $filename (${size})${NC}"
            ((generated_count++))
        else
            echo -e "   ${RED}❌ Failed to create $filename${NC}"
        fi
    fi
done

echo ""
echo "=================================="
if [ $generated_count -gt 0 ]; then
    echo -e "${GREEN}🎉 Successfully generated $generated_count icon file(s)!${NC}"
    echo ""
    echo -e "${BLUE}📁 Current icon files:${NC}"
    for file in "${!icons[@]}"; do
        if [ -f "$file" ]; then
            size=$(get_image_info "$file")
            echo -e "   ${GREEN}✅ $file${NC} (${size})"
        fi
    done
    echo ""
    echo -e "${BLUE}💡 Next steps:${NC}"
    echo "   1. Add manifest.json to your project"
    echo "   2. Update index.html with manifest link"
    echo "   3. Test PWA functionality in Chrome DevTools"
else
    echo -e "${YELLOW}⚠️ No icons were generated.${NC}"
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