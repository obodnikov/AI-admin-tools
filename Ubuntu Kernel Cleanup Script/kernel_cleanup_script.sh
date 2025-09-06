#!/bin/bash

# Ubuntu Kernel Cleanup Script
# Automatically removes old kernel packages while keeping current and latest kernels
# Usage: ./kernel_cleanup.sh [--keep N] [--dry-run] [--help]

set -uo pipefail

# Default values
KEEP_EXTRA=1
DRY_RUN=false
VERBOSE=false
DEBUG=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print usage information
usage() {
    cat << EOF
Ubuntu Kernel Cleanup Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --keep N        Keep N additional kernels beyond current and latest (default: 1)
    --dry-run       Show what would be removed without actually removing
    --debug         Enable debug output showing detailed logic
    --verbose       Enable verbose output
    --help          Show this help message

DESCRIPTION:
    This script removes old kernel packages while always keeping:
    - The currently running kernel
    - The latest installed kernel
    - N additional kernels (specified by --keep)

EXAMPLES:
    $0                    # Keep current, latest, and 1 additional kernel
    $0 --keep 2          # Keep current, latest, and 2 additional kernels
    $0 --keep 0 --dry-run # Show what would be removed, keeping only current and latest

SAFETY:
    - Always keeps the currently running kernel
    - Always keeps the latest installed kernel
    - Requires confirmation before removal (unless --dry-run)
    - Updates GRUB after successful removal
EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${NC}[VERBOSE] $1"
    fi
}

log_debug() {
    if [[ "$DEBUG" == true ]]; then
        echo -e "${NC}[DEBUG] $1"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. It will use sudo when needed."
        exit 1
    fi
}

# Check if sudo is available
check_sudo() {
    if ! command -v sudo &> /dev/null; then
        log_error "sudo is required but not found"
        exit 1
    fi
}

# Get current kernel version
get_current_kernel() {
    uname -r
}

# Get all installed kernel versions (unique)
get_installed_kernel_versions() {
    dpkg --list | egrep -i 'linux-image|linux-headers|linux-modules' | \
    awk '{print $2}' | \
    grep -v -E '^(linux-image-generic|linux-headers-generic|linux-modules-generic)$' | \
    grep -oE '[0-9]+\.[0-9]+\.[0-9]+-[0-9]+' | \
    sort -u -V
}

# Get all packages for a specific kernel version
get_packages_for_version() {
    local version="$1"
    dpkg --list | egrep -i 'linux-image|linux-headers|linux-modules' | \
    awk '{print $2}' | \
    grep "$version" | \
    grep -v -E '^(linux-image-generic|linux-headers-generic|linux-modules-generic)$' | \
    sort
}

# Sort versions (latest first)
sort_versions_desc() {
    printf '%s\n' "$@" | sort -V -r
}

# Extract version from kernel string (handles both uname -r format and package format)
normalize_kernel_version() {
    local kernel="$1"
    echo "$kernel" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+-[0-9]+'
}

# Main cleanup function
cleanup_kernels() {
    log_info "Starting kernel cleanup process..."
    
    # Get current kernel and normalize it
    local current_kernel_raw=$(get_current_kernel)
    local current_kernel=$(normalize_kernel_version "$current_kernel_raw")
    log_info "Currently running kernel: $current_kernel_raw ($current_kernel)"
    
    # Get all installed kernel versions
    local all_versions=($(get_installed_kernel_versions))
    if [[ ${#all_versions[@]} -eq 0 ]]; then
        log_warning "No kernel versions found"
        return 0
    fi
    
    log_debug "Raw versions found: ${all_versions[*]}"
    log_info "Found ${#all_versions[@]} kernel versions: ${all_versions[*]}"
    
    # Sort versions (latest first)
    local sorted_versions=($(sort_versions_desc "${all_versions[@]}"))
    local latest_version="${sorted_versions[0]}"
    
    log_info "Latest kernel version: $latest_version"
    
    # Determine which versions to keep
    local keep_versions=()
    
    # Always keep current kernel
    if [[ -n "$current_kernel" ]]; then
        keep_versions+=("$current_kernel")
        log_debug "Added current kernel to keep list: $current_kernel"
        log_verbose "Will keep current kernel: $current_kernel"
    fi
    
    # Always keep latest kernel if different from current
    if [[ "$latest_version" != "$current_kernel" ]]; then
        keep_versions+=("$latest_version")
        log_debug "Added latest kernel to keep list: $latest_version"
        log_verbose "Will keep latest kernel: $latest_version"
    else
        log_debug "Latest kernel is same as current, not adding separately"
    fi
    
    # Keep additional kernels as requested
    local added_extra=0
    log_debug "Looking for $KEEP_EXTRA additional kernels to keep"
    for version in "${sorted_versions[@]}"; do
        if [[ $added_extra -ge $KEEP_EXTRA ]]; then
            log_debug "Reached limit of additional kernels to keep ($KEEP_EXTRA)"
            break
        fi
        
        # Check if this version is already in keep_versions
        local already_keeping=false
        for keep_version in "${keep_versions[@]}"; do
            if [[ "$version" == "$keep_version" ]]; then
                already_keeping=true
                break
            fi
        done
        
        if [[ "$already_keeping" == false ]]; then
            keep_versions+=("$version")
            log_debug "Added additional kernel to keep list: $version"
            log_verbose "Will keep additional kernel: $version"
            ((added_extra++))
        else
            log_debug "Version $version already in keep list, skipping"
        fi
    done
    log_debug "Final keep list: ${keep_versions[*]}"
    
    # Determine which versions to remove
    local remove_versions=()
    log_debug "Checking which versions to remove from: ${all_versions[*]}"
    for version in "${all_versions[@]}"; do
        local should_keep=false
        for keep_version in "${keep_versions[@]}"; do
            if [[ "$version" == "$keep_version" ]]; then
                should_keep=true
                break
            fi
        done
        
        if [[ "$should_keep" == false ]]; then
            remove_versions+=("$version")
            log_debug "Version $version will be removed"
        else
            log_debug "Version $version will be kept"
        fi
    done
    
    log_debug "Final remove list: ${remove_versions[*]}"
    
    if [[ ${#remove_versions[@]} -eq 0 ]]; then
        log_success "No kernels need to be removed"
        log_debug "Remove versions array is empty. Keep versions: ${keep_versions[*]}"
        return 0
    fi
    
    # Get packages to remove
    local packages_to_remove=()
    for version in "${remove_versions[@]}"; do
        log_verbose "Getting packages for version: $version"
        mapfile -t version_packages < <(get_packages_for_version "$version")
        packages_to_remove+=("${version_packages[@]}")
    done
    
    # Display summary
    echo
    log_info "=== CLEANUP SUMMARY ==="
    log_info "Kernels to keep (${#keep_versions[@]} total):"
    for version in "${keep_versions[@]}"; do
        local package_count=$(get_packages_for_version "$version" | wc -l)
        echo "  - $version ($package_count packages)"
        if [[ "$VERBOSE" == true ]]; then
            get_packages_for_version "$version" | sed 's/^/    /'
        fi
    done
    
    if [[ ${#remove_versions[@]} -gt 0 ]]; then
        echo
        log_warning "Kernels to remove (${#remove_versions[@]} versions):"
        for version in "${remove_versions[@]}"; do
            local package_count=$(get_packages_for_version "$version" | wc -l)
            echo "  - $version ($package_count packages)"
            if [[ "$VERBOSE" == true ]]; then
                get_packages_for_version "$version" | sed 's/^/    /'
            fi
        done
        
        echo
        log_warning "Total packages to remove: ${#packages_to_remove[@]}"
        if [[ "$VERBOSE" == true ]] || [[ "$DRY_RUN" == true ]]; then
            echo "Packages to remove:"
            for package in "${packages_to_remove[@]}"; do
                echo "  - $package"
            done
        fi
    fi
    echo
    
    # Dry run check
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: No packages will be removed"
        return 0
    fi
    
    # Confirmation
    echo -n "Do you want to proceed with the removal? [y/N]: "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled"
        return 0
    fi
    
    # Remove packages
    log_info "Removing ${#packages_to_remove[@]} old kernel packages..."
    if [[ ${#packages_to_remove[@]} -gt 0 ]] && sudo apt purge -y "${packages_to_remove[@]}"; then
        log_success "Successfully removed old kernel packages"
        
        # Update GRUB
        log_info "Updating GRUB configuration..."
        if sudo update-grub; then
            log_success "GRUB configuration updated"
        else
            log_warning "Failed to update GRUB configuration"
        fi
        
        # Clean up
        log_info "Running autoremove to clean up dependencies..."
        sudo apt autoremove -y
        
        log_success "Kernel cleanup completed successfully!"
        
        # Show remaining kernels
        echo
        log_info "Remaining kernel versions:"
        get_installed_kernel_versions | while read -r version; do
            local package_count=$(get_packages_for_version "$version" | wc -l)
            echo "  - $version ($package_count packages)"
        done
    else
        log_error "Failed to remove packages or no packages to remove"
        return 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --keep)
            if [[ -z "${2:-}" ]] || [[ ! "$2" =~ ^[0-9]+$ ]]; then
                log_error "Invalid value for --keep. Must be a non-negative integer."
                exit 1
            fi
            KEEP_EXTRA="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log_info "Ubuntu Kernel Cleanup Script"
    log_info "Keep extra kernels: $KEEP_EXTRA"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Running in DRY RUN mode"
    fi
    
    check_root
    check_sudo
    cleanup_kernels
}

# Run main function
main "$@"