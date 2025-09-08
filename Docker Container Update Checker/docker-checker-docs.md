# Docker Container Update Checker

A Python script that automatically checks running Docker containers for available image updates and sends notifications via Telegram.

## Features

- 🔍 **Automatic Update Detection**: Checks all running Docker containers for newer image versions
- 📦 **Multi-Registry Support**: 
  - Docker Hub (docker.io) - Full semantic version comparison
  - LinuxServer.io (lscr.io) - Digest-based update detection
  - GitHub Container Registry (ghcr.io) - Digest-based update detection
  - Red Hat Quay (quay.io) - Digest-based update detection
- 📱 **Telegram Notifications**: Sends formatted notifications when updates are available
- 🎯 **Smart Filtering**: 
  - Skip containers with `latest`, `rc`, `beta`, `alpha`, etc. tags
  - Ignore specific containers by name
  - Focus on stable releases only
- ⏰ **Cron Compatible**: Designed to run automatically via crontab
- 📝 **Comprehensive Logging**: Detailed logs for troubleshooting
- 🔧 **Configurable**: Flexible configuration via INI file

## Requirements

- Ubuntu/Debian Linux (or similar)
- Docker installed and running
- Python 3.6+
- Python packages: `requests`, `packaging`, `configparser`
- Telegram Bot Token and Chat ID

## Installation

### 1. Install Python Dependencies

```bash
pip3 install requests packaging configparser
```

Or using a virtual environment (recommended):
```bash
python3 -m venv .venv
source .venv/bin/activate  # On Linux/Mac
pip install requests packaging configparser
```

### 2. Download and Install the Script

```bash
# Create directory for the script
sudo mkdir -p /opt/docker-update-checker

# Download the script (or copy your file)
sudo cp docker_update_checker.py /opt/docker-update-checker/
sudo chmod +x /opt/docker-update-checker/docker_update_checker.py
```

### 3. Create Configuration Directory

```bash
sudo mkdir -p /etc/docker-update-checker
```

## Configuration

### Setting up Telegram Bot

1. **Create a Telegram Bot**:
   - Open Telegram and search for `@BotFather`
   - Send `/newbot` command
   - Choose a name for your bot
   - Choose a username for your bot (must end with 'bot')
   - Save the token provided by BotFather

2. **Get Your Chat ID**:
   - Send a message to your new bot
   - Open your browser and go to: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
   - Look for `"chat":{"id":` in the response
   - Save this chat ID

### Configuration File

Create the configuration file at `/etc/docker-update-checker/config.ini`:

```ini
[telegram]
# Your bot token from @BotFather
token = YOUR_TELEGRAM_BOT_TOKEN
# Your chat ID from the getUpdates API
chat_id = YOUR_CHAT_ID

[docker]
# Comma-separated list of container names to ignore
ignore_containers = 
# Tags to skip checking (pre-release versions)
skip_tags = latest,rc,beta,alpha,dev,nightly,snapshot,preview
# Send notifications about unsupported registries
notify_unsupported_registries = false

[registry]
# Docker Hub settings
check_private_repos = false
docker_hub_username = 
docker_hub_password = 
```

#### Configuration Options Explained

| Section | Option | Description | Default |
|---------|--------|-------------|---------|
| **telegram** | token | Your Telegram bot token | Required |
| telegram | chat_id | Telegram chat/channel ID for notifications | Required |
| **docker** | ignore_containers | Container names to skip (comma-separated) | Empty |
| docker | skip_tags | Tags to ignore during checks | latest,rc,beta,alpha,dev,nightly,snapshot,preview |
| docker | notify_unsupported_registries | Notify about containers from unsupported registries | false |
| **registry** | check_private_repos | Enable checking private repositories | false |
| registry | docker_hub_username | Docker Hub username for private repos | Empty |
| registry | docker_hub_password | Docker Hub password for private repos | Empty |

## Usage

### Manual Execution

```bash
# Basic usage with default config
python3 /opt/docker-update-checker/docker_update_checker.py

# Specify custom config file
python3 /opt/docker-update-checker/docker_update_checker.py -c /path/to/config.ini

# Enable verbose logging
python3 /opt/docker-update-checker/docker_update_checker.py -v
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-c, --config` | Path to configuration file (default: `/etc/docker-update-checker/config.ini`) |
| `-v, --verbose` | Enable debug logging for troubleshooting |

### Automated Execution with Cron

Add to crontab for automatic checking:

```bash
# Edit crontab
sudo crontab -e

# Add one of these schedules:

# Check every 6 hours
0 */6 * * * /usr/bin/python3 /opt/docker-update-checker/docker_update_checker.py >> /var/log/docker-update-checker.log 2>&1

# Check daily at 8 AM
0 8 * * * /usr/bin/python3 /opt/docker-update-checker/docker_update_checker.py >> /var/log/docker-update-checker.log 2>&1

# Check weekly on Mondays at 9 AM
0 9 * * 1 /usr/bin/python3 /opt/docker-update-checker/docker_update_checker.py >> /var/log/docker-update-checker.log 2>&1

# Check twice daily (8 AM and 8 PM)
0 8,20 * * * /usr/bin/python3 /opt/docker-update-checker/docker_update_checker.py >> /var/log/docker-update-checker.log 2>&1
```

### Log Rotation

Create `/etc/logrotate.d/docker-update-checker`:

```
/var/log/docker-update-checker.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 0644 root root
}
```

## How It Works

### Update Detection Process

1. **Container Discovery**: Lists all running Docker containers using `docker ps`
2. **Image Parsing**: Extracts registry, image name, and tag from each container
3. **Registry-Specific Checks**:
   - **Docker Hub**: Uses API to fetch available tags and compares semantic versions
   - **LinuxServer.io/GitHub/Quay.io**: Uses `docker manifest inspect` to compare digests
4. **Filtering**: Skips containers with pre-release tags or those in ignore list
5. **Notification**: Sends consolidated update report to Telegram

### Registry Support Details

#### Docker Hub (docker.io)
- Full semantic version comparison
- Checks for newer stable versions
- Filters out pre-release tags
- Example: `nginx:1.24.0` → checks if `1.25.0` exists

#### LinuxServer.io (lscr.io)
- Digest-based comparison
- Detects when image has been rebuilt/updated
- Works with versioned tags
- Example: `lscr.io/linuxserver/bookstack:version-1.2.3`

#### GitHub Container Registry (ghcr.io)
- Similar to LinuxServer.io
- Digest comparison for update detection
- Supports public images (private requires authentication)
- Example: `ghcr.io/username/image:v2.0.0`

#### Red Hat Quay (quay.io)
- Digest-based comparison
- Supports OCI and Docker manifest formats
- Works with public and private repositories (with auth)
- Example: `quay.io/jupyter/tensorflow-notebook:latest`

## Telegram Notifications

### Success Notification Format

```
🐳 Docker Container Updates Available

📦 Container: nginx-proxy
   Current: nginx:1.24.0
   Status: New version available: 1.25.0

📦 Container: postgres-db
   Current: postgres:15.3
   Status: New version available: 15.4

📦 Container: unifi
   Current: lscr.io/linuxserver/unifi-network-application:7.5.187
   Status: New version available (digest changed)

_Checked at 2025-09-08 14:30:00_
```

### Error Notification Format

```
❌ Docker Update Checker Error

`Error message details here`
```

## Troubleshooting

### Common Issues and Solutions

#### 1. "Configuration file not found"
- **Solution**: The script will create a sample config file. Edit it with your Telegram credentials.

#### 2. "Docker command failed"
- **Cause**: Docker daemon not running or permission issues
- **Solution**: 
  ```bash
  # Check Docker status
  sudo systemctl status docker
  
  # Add user to docker group (optional)
  sudo usermod -aG docker $USER
  ```

#### 3. "Failed to send Telegram notification"
- **Cause**: Invalid bot token or chat ID
- **Solution**: Verify your token and chat ID are correct

#### 4. "Container uses unsupported registry"
- **Cause**: Image from registry not yet supported
- **Solution**: Enable `notify_unsupported_registries` to track these

#### 5. No updates detected for containers using `latest` tag
- **Cause**: `latest` tag is in the skip list by default
- **Solution**: This is intentional - `latest` always pulls the newest version

#### 6. "'list' object has no attribute 'get'" error
- **Cause**: Outdated version of the script with old manifest parsing logic
- **Solution**: Update to the latest version that properly handles OCI manifest format

### Debug Mode

Run with verbose logging to troubleshoot:

```bash
python3 /opt/docker-update-checker/docker_update_checker.py -v
```

This will show:
- Docker commands being executed
- Manifest parsing details
- Registry detection logic
- Digest comparisons
- Skipped containers and reasons

## Advanced Configuration

### Checking Private Repositories

For private Docker Hub repositories:

```ini
[registry]
check_private_repos = true
docker_hub_username = your_username
docker_hub_password = your_password_or_token
```

For private ghcr.io, lscr.io, or quay.io images, ensure Docker is authenticated:

```bash
# GitHub Container Registry
docker login ghcr.io

# LinuxServer.io
docker login lscr.io

# Red Hat Quay
docker login quay.io
```

### Custom Skip Tags

Modify the tags to skip in your config:

```ini
[docker]
# Only skip latest and release candidates
skip_tags = latest,rc

# Or skip all pre-release versions
skip_tags = latest,rc,beta,alpha,dev,nightly,snapshot,preview,testing,unstable,edge
```

### Ignoring Specific Containers

```ini
[docker]
# Ignore containers by name
ignore_containers = test-container,development-db,temp-nginx
```

## Security Considerations

1. **Configuration File Permissions**:
   ```bash
   sudo chmod 600 /etc/docker-update-checker/config.ini
   sudo chown root:root /etc/docker-update-checker/config.ini
   ```

2. **Telegram Token Security**:
   - Never commit config files to version control
   - Use environment variables for sensitive data in production
   - Rotate tokens periodically

3. **Docker Permissions**:
   - Script requires Docker socket access
   - Run as a user with Docker permissions
   - Avoid running as root if possible

## Version History

- **v2.1.0** - Added Quay.io support
- **v2.0.1** - Fixed lscr.io manifest handling for OCI format
- **v2.0.0** - Added support for multiple registries
- **v1.0.0** - Initial release with Docker Hub support

## Limitations

1. **Version Comparison**: Only works with semantic versioning (e.g., 1.2.3, v2.0.0) for Docker Hub
2. **Registry Support**: Currently supports Docker Hub, lscr.io, ghcr.io, and quay.io
3. **Tag Detection**: Cannot detect updates for custom tags without version numbers
4. **Rate Limits**: Docker Hub API has rate limits (100 requests per 6 hours for anonymous users)
5. **Digest Comparison**: For non-Docker Hub registries, only detects if image was rebuilt, not version changes

## Contributing

To add support for additional registries:

1. Add a new check method (e.g., `check_newregistry_update`)
2. Update the `check_container_updates` method to handle the new registry
3. Update the `parse_image_tag` method if needed for registry detection
4. Add registry-specific logic for version/digest comparison

## Example Configurations

### Minimal Configuration

```ini
[telegram]
token = 123456789:ABCdefGHIjklMNOpqrsTUVwxyz
chat_id = -1001234567890

[docker]
[registry]
```

### Production Configuration

```ini
[telegram]
token = 123456789:ABCdefGHIjklMNOpqrsTUVwxyz
chat_id = -1001234567890

[docker]
ignore_containers = monitoring-prometheus,monitoring-grafana
skip_tags = latest,rc,beta,alpha,dev,nightly
notify_unsupported_registries = true

[registry]
check_private_repos = false
```

### Development Environment

```ini
[telegram]
token = 123456789:ABCdefGHIjklMNOpqrsTUVwxyz
chat_id = 987654321

[docker]
ignore_containers = 
skip_tags = latest
notify_unsupported_registries = true

[registry]
check_private_repos = true
docker_hub_username = dev_user
docker_hub_password = dev_token
```

## Support

For issues or questions:
1. Check the logs: `/var/log/docker-update-checker.log`
2. Run with verbose mode: `-v` flag
3. Verify Docker and network connectivity
4. Ensure Telegram bot is properly configured
5. Check that Docker manifest inspect works: `docker manifest inspect <image>`

## License

This script is provided as-is for monitoring Docker container updates. Use at your own discretion in production environments.