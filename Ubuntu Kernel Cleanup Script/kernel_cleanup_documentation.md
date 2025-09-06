# Ubuntu Kernel Cleanup Script Documentation

## Overview

The Ubuntu Kernel Cleanup Script is a Bash script designed to safely remove old kernel packages while maintaining system stability. It automatically identifies and removes unused kernel packages while ensuring critical kernels are preserved.

## Features

- **Safe by Design**: Always preserves the currently running kernel and latest installed kernel
- **Flexible Configuration**: Customizable number of additional kernels to keep
- **Dry Run Mode**: Preview changes before execution
- **Comprehensive Package Detection**: Handles all kernel package types (images, headers, modules, modules-extra)
- **Debug Mode**: Detailed logging for troubleshooting
- **Automatic GRUB Update**: Updates bootloader configuration after cleanup
- **Confirmation Required**: Interactive confirmation before making changes

## Installation

1. Download or create the script file:
   ```bash
   curl -o kernel_cleanup.sh [script-url]
   # or copy the script content to a file
   ```

2. Make it executable:
   ```bash
   chmod +x kernel_cleanup.sh
   ```

3. Ensure you have `sudo` privileges for package management

## Usage

### Basic Syntax
```bash
./kernel_cleanup.sh [OPTIONS]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--keep N` | Keep N additional kernels beyond current and latest | 1 |
| `--dry-run` | Show what would be removed without actually removing | false |
| `--debug` | Enable detailed debug output | false |
| `--verbose` | Enable verbose output | false |
| `--help` | Show help message and exit | - |

### Examples

#### Basic Usage
```bash
# Keep current, latest, and 1 additional kernel (default)
./kernel_cleanup.sh

# Keep current, latest, and 2 additional kernels
./kernel_cleanup.sh --keep 2

# Keep only current and latest kernels
./kernel_cleanup.sh --keep 0
```

#### Preview Mode
```bash
# Preview what would be removed (keeping only current and latest)
./kernel_cleanup.sh --keep 0 --dry-run

# Preview with verbose output
./kernel_cleanup.sh --keep 1 --dry-run --verbose

# Preview with debug information
./kernel_cleanup.sh --keep 2 --dry-run --debug
```

#### Real Execution
```bash
# Remove old kernels (will ask for confirmation)
./kernel_cleanup.sh --keep 1

# With verbose output during execution
./kernel_cleanup.sh --keep 1 --verbose
```

## How It Works

### Kernel Detection Process

1. **Current Kernel Identification**: Uses `uname -r` to identify the currently running kernel
2. **Package Discovery**: Scans all installed kernel packages using `dpkg --list`
3. **Version Extraction**: Extracts kernel versions from package names using regex pattern `[0-9]+\.[0-9]+\.[0-9]+-[0-9]+`
4. **Package Types Detected**:
   - `linux-image-*`: Kernel images
   - `linux-headers-*`: Kernel headers
   - `linux-modules-*`: Kernel modules
   - `linux-modules-extra-*`: Additional kernel modules

### Keep Logic

The script follows this priority order for keeping kernels:

1. **Currently Running Kernel**: Always preserved (identified via `uname -r`)
2. **Latest Installed Kernel**: Always preserved (highest version number)
3. **Additional Kernels**: Based on `--keep N` parameter, preserves N most recent kernels

### Version Sorting

Kernels are sorted using natural version sorting (`sort -V`) to properly handle version numbers like:
- 6.8.0-40 < 6.8.0-41 < 6.8.0-78 < 6.8.0-79

### Package Removal

For each kernel version marked for removal, the script removes ALL associated packages:
- Kernel image (e.g., `linux-image-6.8.0-40-generic`)
- Kernel headers (e.g., `linux-headers-6.8.0-40`, `linux-headers-6.8.0-40-generic`)
- Kernel modules (e.g., `linux-modules-6.8.0-40-generic`)
- Extra modules (e.g., `linux-modules-extra-6.8.0-40-generic`)

## Safety Features

### Always Preserved
- Currently running kernel (cannot be removed while in use)
- Latest installed kernel (provides fallback option)
- Meta-packages like `linux-image-generic`, `linux-headers-generic`

### Safety Checks
- Refuses to run as root (uses `sudo` when needed)
- Requires interactive confirmation before removal
- Updates GRUB configuration after successful removal
- Validates command-line arguments

### Error Handling
- Comprehensive error checking for all operations
- Graceful handling of missing packages or permissions
- Detailed logging of all operations

## Output Examples

### Dry Run Output
```
[INFO] Ubuntu Kernel Cleanup Script
[INFO] Keep extra kernels: 2
[INFO] Running in DRY RUN mode
[INFO] Currently running kernel: 6.8.0-79-generic (6.8.0-79)
[INFO] Found 23 kernel versions: 6.8.0-40 6.8.0-41 ... 6.8.0-79
[INFO] Latest kernel version: 6.8.0-79

=== CLEANUP SUMMARY ===
[INFO] Kernels to keep (3 total):
  - 6.8.0-79 (5 packages)
  - 6.8.0-78 (3 packages)
  - 6.8.0-71 (5 packages)

[WARNING] Kernels to remove (20 versions):
  - 6.8.0-40 (3 packages)
  - 6.8.0-41 (3 packages)
  ...

[WARNING] Total packages to remove: 60
Packages to remove:
  - linux-image-6.8.0-40-generic
  - linux-modules-6.8.0-40-generic
  - linux-modules-extra-6.8.0-40-generic
  ...

[INFO] DRY RUN: No packages will be removed
```

### Actual Execution Output
```
[INFO] Ubuntu Kernel Cleanup Script
[INFO] Keep extra kernels: 1
[INFO] Currently running kernel: 6.8.0-79-generic (6.8.0-79)
[INFO] Found 23 kernel versions: 6.8.0-40 6.8.0-41 ... 6.8.0-79

=== CLEANUP SUMMARY ===
[INFO] Kernels to keep (2 total):
  - 6.8.0-79 (5 packages)
  - 6.8.0-78 (3 packages)

[WARNING] Total packages to remove: 63

Do you want to proceed with the removal? [y/N]: y
[INFO] Removing 63 old kernel packages...
[SUCCESS] Successfully removed old kernel packages
[INFO] Updating GRUB configuration...
[SUCCESS] GRUB configuration updated
[INFO] Running autoremove to clean up dependencies...
[SUCCESS] Kernel cleanup completed successfully!

[INFO] Remaining kernel versions:
  - 6.8.0-79 (5 packages)
  - 6.8.0-78 (3 packages)
```

## Troubleshooting

### Common Issues

#### Script Stops with "unexpected EOF"
- **Cause**: Syntax error in the script file
- **Solution**: Re-download the script or check for file corruption

#### No kernels detected
- **Cause**: Non-standard kernel package naming or dpkg issues
- **Solution**: Run `dpkg --list | grep linux` manually to check package status

#### Permission denied errors
- **Cause**: Insufficient privileges for package management
- **Solution**: Ensure user has sudo privileges

#### GRUB update fails
- **Cause**: GRUB configuration issues or insufficient disk space
- **Solution**: Check `/boot` partition space and GRUB configuration

### Debug Mode

Use `--debug` flag for detailed troubleshooting:
```bash
./kernel_cleanup.sh --keep 1 --dry-run --debug
```

Debug output includes:
- Raw version detection results
- Keep/remove logic decisions
- Package discovery process
- Step-by-step execution flow

### Manual Verification

Before running the script, you can manually verify kernel packages:
```bash
# List all kernel packages
dpkg --list | egrep -i 'linux-image|linux-headers|linux-modules' | awk '{print $2}'

# Check current kernel
uname -r

# Check available kernels in GRUB
ls /boot/vmlinuz-*
```

## Best Practices

### Before Running
1. **Create a backup** of important data
2. **Check current kernel**: Ensure system is running on a stable kernel
3. **Verify boot options**: Check GRUB menu has multiple kernel options
4. **Use dry-run mode** first to preview changes

### Recommended Keep Values
- **Conservative**: `--keep 2` (keeps 3-4 kernels total)
- **Standard**: `--keep 1` (keeps 2-3 kernels total)
- **Minimal**: `--keep 0` (keeps only current and latest)

### After Running
1. **Reboot and test** system functionality
2. **Verify GRUB menu** shows expected kernel options
3. **Check system logs** for any issues
4. **Test critical applications**

## System Requirements

- **OS**: Ubuntu (tested on Ubuntu 20.04+)
- **Shell**: Bash 4.0+
- **Privileges**: sudo access
- **Dependencies**: dpkg, egrep, awk, grep, sort

## Known Limitations

1. **Ubuntu-specific**: Designed for Ubuntu's kernel package naming scheme
2. **Generic kernels only**: May not handle custom or third-party kernels
3. **No rollback**: Once packages are removed, they must be manually reinstalled
4. **Requires manual GRUB menu update** in some cases

## Security Considerations

- Script requires sudo privileges for package removal
- Never run as root directly (script prevents this)
- Review package list in dry-run mode before execution
- Script only removes kernel packages, not other system packages

## Contributing

When modifying the script:
1. Test thoroughly with `--dry-run` mode
2. Maintain backward compatibility
3. Add appropriate error handling
4. Update documentation for new features
5. Test on multiple Ubuntu versions

## Version History

- **v1.0**: Initial release with basic kernel cleanup functionality
- **v1.1**: Added debug mode and improved error handling
- **v1.2**: Enhanced package detection and dry-run output
- **Current**: Comprehensive logging and safety features