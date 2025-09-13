# System Management Tools

This project contains utility applications designed to help with system administration, maintenance tasks, and web development.

## Applications

### Docker Container Update Checker
**Directory:** `Docker Container Update Checker/`

A utility tool that monitors Docker containers and checks for available updates to their base images. This application helps system administrators stay on top of security patches and feature updates by automatically detecting when newer versions of container images are available.

**Key Features:**
- Scans running Docker containers
- Checks for image updates from registries
- Provides update notifications and recommendations
- Helps maintain container security and performance

### Ubuntu Kernel Cleanup Script
**Directory:** `Ubuntu Kernel Cleanup Script/`

An automated cleanup script designed to remove old and unused kernel packages from Ubuntu systems. This tool helps free up disk space by safely removing outdated kernel versions while preserving the current and previous kernel for system stability.

**Key Features:**
- Identifies old kernel packages safely
- Preserves current and backup kernels
- Frees up system disk space
- Maintains system boot reliability

### Web Icons Generator
**Directory:** `Web Icons Generator/`

A smart bash script that automatically generates all required PWA (Progressive Web App) icons from a single SVG source file. Compatible with both ImageMagick 6.x and 7.x, making it work across different operating systems.

**Key Features:**
- Generates complete PWA icon set from SVG
- Smart detection of existing files
- Cross-platform ImageMagick compatibility
- Creates maskable icons with proper safe zones
- Color-coded progress reporting

## Usage

Each application is contained within its respective directory and includes its own documentation and setup instructions. Please refer to the individual directories for specific usage guidelines and requirements.

## Requirements

- Docker (for Docker Container Update Checker)
- Ubuntu/Debian-based system (for Ubuntu Kernel Cleanup Script)
- ImageMagick and SVG source file (for Web Icons Generator)
- Appropriate system permissions for administration tasks