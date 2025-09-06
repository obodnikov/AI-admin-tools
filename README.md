# System Management Tools

This project contains two utility applications designed to help with system administration and maintenance tasks.

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

## Usage

Each application is contained within its respective directory and includes its own documentation and setup instructions. Please refer to the individual directories for specific usage guidelines and requirements.

## Requirements

- Docker (for Docker Container Update Checker)
- Ubuntu/Debian-based system (for Ubuntu Kernel Cleanup Script)
- Appropriate system permissions for administration tasks