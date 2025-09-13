# PWA Icon Generator Guide

## Overview

This script automatically generates all required PWA (Progressive Web App) icons from a single SVG source file. It supports both ImageMagick 6.x and 7.x, making it compatible with most Linux distributions, macOS, and Windows.

## Required Icon Files for PWA

Based on PWA standards, the script generates these icon files:

### Standard Icons
- **favicon.ico** - 32×32 pixels (browser tab icon)
- **apple-touch-icon.png** - 180×180 pixels (iOS home screen)
- **icon-192.png** - 192×192 pixels (Android home screen)
- **icon-512.png** - 512×512 pixels (Android splash screen)

### Maskable Icons (for adaptive icons on Android)
- **icon-maskable-192.png** - 192×192 pixels with safe zone
- **icon-maskable-512.png** - 512×512 pixels with safe zone

## Prerequisites

### Required Software
- **ImageMagick** (either version 6.x or 7.x)
- **SVG source file** named `favicon.svg`

### Installation Commands

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install imagemagick
```

#### CentOS/RHEL/Fedora
```bash
# CentOS/RHEL
sudo yum install ImageMagick

# Fedora
sudo dnf install ImageMagick
```

#### macOS
```bash
brew install imagemagick
```

#### Windows
Download from [https://imagemagick.org/](https://imagemagick.org/)

## Usage

### Basic Usage
```bash
# Make script executable
chmod +x generate-icons.sh

# Run the script
./generate-icons.sh
```

### Features

🔍 **Smart Detection**
- Automatically detects ImageMagick 6.x (`convert`) or 7.x (`magick`)
- Checks for existing icon files before generating
- Only creates missing icons to save time

🎨 **High Quality Output**
- Generates crisp icons at multiple resolutions
- Creates maskable icons with proper safe zones
- Maintains vector quality from SVG source

📊 **Helpful Reporting**
- Shows which files already exist
- Reports generation progress with colors
- Displays final file sizes and status

⚙️ **Cross-Platform Compatibility**
- Works on Ubuntu, CentOS, macOS, Windows
- Handles different ImageMagick command syntax automatically
- Provides system-specific installation instructions

### Output Example

```
🎨 PWA Icon Generator
==================================
✅ ImageMagick 6.x (convert command) found
✅ favicon.svg found

📋 Checking existing icon files...
   ❌ favicon.ico
   ❌ apple-touch-icon.png
   ✅ icon-192.png
   ❌ icon-512.png
   ❌ icon-maskable-192.png
   ❌ icon-maskable-512.png

🔧 Found 5 missing icon file(s).
Missing files: favicon.ico apple-touch-icon.png icon-512.png icon-maskable-192.png icon-maskable-512.png

Generate missing icons? (Y/n): y

🚀 Generating icons...

   🖼️ Generating icon: favicon.ico
   ✅ Created favicon.ico (32x32)
   🖼️ Generating icon: apple-touch-icon.png
   ✅ Created apple-touch-icon.png (180x180)
   🖼️ Generating icon: icon-512.png
   ✅ Created icon-512.png (512x512)
   🎭 Generating maskable icon: icon-maskable-192.png
   ✅ Created icon-maskable-192.png (192x192 with safe zone)
   🎭 Generating maskable icon: icon-maskable-512.png
   ✅ Created icon-maskable-512.png (512x512 with safe zone)

==================================
🎉 Successfully generated 5 icon file(s)!

📁 Current icon files:
   ✅ favicon.ico (32x32)
   ✅ apple-touch-icon.png (180x180)
   ✅ icon-192.png (192x192)
   ✅ icon-512.png (512x512)
   ✅ icon-maskable-192.png (192x192)
   ✅ icon-maskable-512.png (512x512)

💡 Next steps:
   1. Add manifest.json to your project
   2. Update index.html with manifest link
   3. Test PWA functionality in Chrome DevTools

🔗 Useful links:
   • Test PWA: Chrome DevTools → Application → Manifest
   • Lighthouse audit: Chrome DevTools → Lighthouse → PWA
   • Icon validator: https://realfavicongenerator.net/favicon_checker

🔧 ImageMagick info:
   • Command used: convert
   • Version: ImageMagick 6.x (convert command)
```

## Maskable Icon Design Guidelines

**Safe Zone Requirements:**
- Minimum 20% padding on all sides
- Icon content should fit within center 80% circle
- Background should extend to edges

**Example for 192×192 maskable icon:**
- Total canvas: 192×192 pixels
- Safe zone: 154×154 pixels (center circle)
- Your icon content must fit within the center 154×154 area

## Troubleshooting

### Common Issues

#### "ImageMagick is required but not installed"
**Solution:** Install ImageMagick using the commands above for your system.

#### "favicon.svg not found"
**Solution:** Ensure you have an SVG file named `favicon.svg` in the same directory as the script.

#### Script runs but no icons generated
**Possible causes:**
- SVG file is corrupted or not a valid SVG
- Insufficient disk space
- Permission issues in the directory

**Debug steps:**
```bash
# Test ImageMagick manually
convert favicon.svg -resize 32x32 test.png

# Check file permissions
ls -la favicon.svg

# Check available disk space
df -h .
```

#### "Failed to create [filename]"
**Solution:** 
- Check that the SVG file is valid
- Ensure you have write permissions in the directory
- Try running the conversion manually to see the error

### Manual Testing

Test ImageMagick installation:
```bash
# Check if commands exist
which convert
which magick
which identify

# Test version
convert -version
# or
magick -version

# Test basic conversion
convert favicon.svg -resize 32x32 test-icon.png
rm test-icon.png  # Clean up test file
```

## File Structure After Generation

```
your-project/
├── index.html
├── manifest.json          # Your PWA manifest
├── styles.css
├── script.js
├── favicon.svg            # Source file (required)
├── favicon.ico            # Generated
├── apple-touch-icon.png   # Generated
├── icon-192.png           # Generated
├── icon-512.png           # Generated
├── icon-maskable-192.png  # Generated
└── icon-maskable-512.png  # Generated
```

## Integration with Your PWA

### 1. Create manifest.json
```json
{
  "name": "Your App Name",
  "short_name": "App",
  "description": "Your app description",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#000000",
  "icons": [
    {
      "src": "icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icon-512.png", 
      "sizes": "512x512",
      "type": "image/png"
    },
    {
      "src": "icon-maskable-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "maskable"
    },
    {
      "src": "icon-maskable-512.png",
      "sizes": "512x512", 
      "type": "image/png",
      "purpose": "maskable"
    }
  ]
}
```

### 2. Update index.html
```html
<head>
  <!-- Basic favicon -->
  <link rel="icon" href="favicon.ico" sizes="32x32">
  <link rel="icon" href="favicon.svg" type="image/svg+xml">
  
  <!-- Apple touch icon -->
  <link rel="apple-touch-icon" href="apple-touch-icon.png">
  
  <!-- PWA manifest -->
  <link rel="manifest" href="manifest.json">
</head>
```

### 3. Test Your PWA
- Open Chrome DevTools → Application → Manifest
- Run Lighthouse audit for PWA score
- Test "Add to Home Screen" functionality

## Script Customization

The script can be easily modified to generate different icon sizes by editing the `icons` array:

```bash
# In the script, modify this section:
declare -A icons=(
    ["favicon.ico"]="32x32:favicon.ico"
    ["apple-touch-icon.png"]="180x180:apple-touch-icon.png" 
    ["icon-192.png"]="192x192:icon-192.png"
    ["icon-512.png"]="512x512:icon-512.png"
    ["icon-maskable-192.png"]="154x154+192x192:icon-maskable-192.png"
    ["icon-maskable-512.png"]="410x410+512x512:icon-maskable-512.png"
    # Add custom sizes here:
    # ["custom-icon.png"]="64x64:custom-icon.png"
)
```

## License

This script is provided as-is for generating PWA icons. Feel free to modify and distribute according to your needs.