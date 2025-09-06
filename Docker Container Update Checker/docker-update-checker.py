#!/usr/bin/env python3
"""
Docker Container Update Checker
Checks running containers for available image updates and sends Telegram notifications
"""

import json
import logging
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import subprocess
import requests
from datetime import datetime
import configparser
import re
from packaging import version

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DockerUpdateChecker:
    def __init__(self, config_path: str = "/etc/docker-update-checker/config.ini"):
        """Initialize the update checker with configuration."""
        self.config = self.load_config(config_path)
        self.telegram_token = self.config.get('telegram', 'token')
        self.telegram_chat_id = self.config.get('telegram', 'chat_id')
        self.ignore_list = self.config.get('docker', 'ignore_containers', fallback='').split(',')
        self.ignore_list = [c.strip() for c in self.ignore_list if c.strip()]
        
        # Load skip tags from config, default includes latest and rc
        default_skip_tags = 'latest,rc,beta,alpha,dev,nightly,snapshot,preview'
        self.skip_tags = self.config.get('docker', 'skip_tags', fallback=default_skip_tags).split(',')
        self.skip_tags = [t.strip().lower() for t in self.skip_tags if t.strip()]
        
    def load_config(self, config_path: str) -> configparser.ConfigParser:
        """Load configuration from file."""
        config = configparser.ConfigParser()
        config_file = Path(config_path)
        
        if not config_file.exists():
            logger.error(f"Configuration file not found: {config_path}")
            self.create_sample_config(config_path)
            sys.exit(1)
            
        config.read(config_path)
        return config
    
    def create_sample_config(self, config_path: str):
        """Create a sample configuration file."""
        sample_config = """[telegram]
# Get your bot token from @BotFather on Telegram
token = YOUR_TELEGRAM_BOT_TOKEN
# Get chat ID by sending a message to your bot and visiting:
# https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
chat_id = YOUR_CHAT_ID

[docker]
# Comma-separated list of container names to ignore
ignore_containers = 
# Skip checking containers with these tags (default: latest and rc tags are always skipped)
skip_tags = latest,rc,beta,alpha,dev,nightly,snapshot,preview
# Notify about containers from unsupported registries (true/false)
notify_unsupported_registries = false

[registry]
# Supported registries: docker.io (Docker Hub), lscr.io (LinuxServer), ghcr.io (GitHub)
# Docker Hub API settings
check_private_repos = false
# Add Docker Hub credentials if checking private repositories
docker_hub_username = 
docker_hub_password = 
# Note: For lscr.io and ghcr.io, the script uses docker manifest inspect
# which requires docker to be authenticated if the images are private
"""
        config_dir = Path(config_path).parent
        config_dir.mkdir(parents=True, exist_ok=True)
        
        with open(config_path, 'w') as f:
            f.write(sample_config)
        logger.info(f"Sample configuration created at: {config_path}")
        logger.info("Please edit the configuration file and run again.")
    
    def run_docker_command(self, cmd: List[str]) -> Optional[str]:
        """Run a docker command and return output."""
        try:
            result = subprocess.run(
                ['docker'] + cmd,
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            logger.error(f"Docker command failed: {e}")
            return None
    
    def get_running_containers(self) -> List[Dict]:
        """Get list of running containers."""
        output = self.run_docker_command(['ps', '--format', 'json'])
        if not output:
            return []
        
        containers = []
        for line in output.split('\n'):
            if line.strip():
                container = json.loads(line)
                # Skip ignored containers
                if container.get('Names') not in self.ignore_list:
                    containers.append(container)
        
        return containers
    
    def parse_image_tag(self, image: str) -> Tuple[str, str, str]:
        """Parse image string into registry, name, and tag."""
        # Handle different image formats
        tag = 'latest'
        registry = 'docker.io'
        
        if ':' in image and '/' in image.split(':')[-1]:
            # Port in registry, not a tag
            parts = image.rsplit(':', 1)
            name = parts[0]
        else:
            parts = image.rsplit(':', 1)
            if len(parts) == 2:
                name, tag = parts
            else:
                name = parts[0]
        
        # Check for registry
        if '/' in name:
            parts = name.split('/', 1)
            if '.' in parts[0] or ':' in parts[0] or parts[0] == 'localhost':
                registry = parts[0]
                name = parts[1]
            else:
                # It's a Docker Hub image with namespace
                name = '/'.join(parts)
        
        # Add library namespace for official images
        if '/' not in name and registry == 'docker.io':
            name = f'library/{name}'
            
        return registry, name, tag
    
    def get_image_digest(self, container_id: str) -> Optional[str]:
        """Get the digest of the image used by a container."""
        output = self.run_docker_command(['inspect', container_id, '--format', '{{.Image}}'])
        if output:
            # Get the image digest
            image_output = self.run_docker_command(['inspect', output, '--format', '{{.RepoDigests}}'])
            if image_output and image_output != '[]':
                # Extract digest from format like [registry/name@sha256:...]
                digests = image_output.strip('[]').split()
                if digests:
                    return digests[0].split('@')[-1] if '@' in digests[0] else None
        return None
    
    def check_dockerhub_update(self, image_name: str, current_tag: str) -> Optional[str]:
        """Check if there's a newer version on Docker Hub."""
        # Skip checking if current tag is in skip list
        if any(skip in current_tag.lower() for skip in self.skip_tags):
            logger.debug(f"Skipping update check for {image_name}:{current_tag} (tag in skip list)")
            return None
        
        # Remove library/ prefix for API calls
        api_name = image_name.replace('library/', '')
        
        # Get token for authentication (even for public repos)
        token_url = f"https://auth.docker.io/token?service=registry.docker.io&scope=repository:{image_name}:pull"
        
        try:
            token_response = requests.get(token_url, timeout=10)
            token_response.raise_for_status()
            token = token_response.json().get('token')
            
            if not token:
                logger.warning(f"Could not get auth token for {image_name}")
                return None
            
            # Get manifest for the current tag
            manifest_url = f"https://registry-1.docker.io/v2/{image_name}/manifests/{current_tag}"
            headers = {
                'Authorization': f'Bearer {token}',
                'Accept': 'application/vnd.docker.distribution.manifest.v2+json'
            }
            
            manifest_response = requests.get(manifest_url, headers=headers, timeout=10)
            manifest_response.raise_for_status()
            
            # Get the current digest
            current_digest = manifest_response.headers.get('Docker-Content-Digest')
            
            # Get all available tags to find newer versions
            tags_url = f"https://registry-1.docker.io/v2/{image_name}/tags/list"
            tags_response = requests.get(tags_url, headers={'Authorization': f'Bearer {token}'}, timeout=10)
            
            if tags_response.status_code == 200:
                tags_data = tags_response.json()
                available_tags = tags_data.get('tags', [])
                
                # Filter and sort tags to find potential newer versions
                newer_version = self.find_newer_version(current_tag, available_tags, image_name, headers)
                if newer_version:
                    return f"New version available: {newer_version}"
            
            return None
            
        except requests.RequestException as e:
            logger.warning(f"Failed to check Docker Hub for {image_name}:{current_tag}: {e}")
            return None
    
    def find_newer_version(self, current_tag: str, available_tags: List[str], 
                          image_name: str, headers: Dict) -> Optional[str]:
        """Find if there's a newer stable version available."""
        from packaging import version
        
        # Filter out unwanted tags
        filtered_tags = []
        for tag in available_tags:
            # Skip tags in the skip list
            if any(skip in tag.lower() for skip in self.skip_tags):
                continue
            # Only consider tags that look like versions
            if re.match(r'^v?\d+(\.\d+)*(-\w+)?$', tag):
                filtered_tags.append(tag)
        
        if not filtered_tags:
            return None
        
        # Try to parse current version
        try:
            current_v = version.parse(current_tag.lstrip('v'))
        except:
            logger.debug(f"Could not parse version from tag: {current_tag}")
            return None
        
        # Find the highest stable version
        newest_tag = None
        newest_version = current_v
        
        for tag in filtered_tags:
            try:
                tag_v = version.parse(tag.lstrip('v'))
                if tag_v > newest_version:
                    newest_version = tag_v
                    newest_tag = tag
            except:
                continue
        
        return newest_tag
    
    def check_lscr_update(self, image_name: str, current_tag: str, container_id: str) -> Optional[str]:
        """Check if there's a newer version on LinuxServer.io registry."""
        # Skip checking if current tag is in skip list
        if any(skip in current_tag.lower() for skip in self.skip_tags):
            logger.debug(f"Skipping update check for lscr.io/{image_name}:{current_tag} (tag in skip list)")
            return None
        
        try:
            # Get current image digest
            current_digest = self.get_image_digest(container_id)
            if not current_digest:
                logger.debug(f"Could not get current digest for lscr.io/{image_name}:{current_tag}")
                return None
            
            # Pull the latest manifest to compare
            # Note: This requires docker pull to get the latest digest without actually downloading
            logger.debug(f"Checking latest digest for lscr.io/{image_name}:{current_tag}")
            
            # Use docker manifest inspect to get remote digest without pulling
            manifest_output = self.run_docker_command([
                'manifest', 'inspect', 
                f'lscr.io/{image_name}:{current_tag}',
                '--verbose'
            ])
            
            if manifest_output:
                # Parse the manifest to get digest
                import json
                try:
                    manifest_data = json.loads(manifest_output)
                    remote_digest = manifest_data.get('Descriptor', {}).get('digest', '')
                    if remote_digest and remote_digest != current_digest:
                        return f"New version available (digest changed)"
                except json.JSONDecodeError:
                    logger.debug("Could not parse manifest data")
            
            return None
            
        except Exception as e:
            logger.warning(f"Failed to check lscr.io for {image_name}:{current_tag}: {e}")
            return None
    
    def check_ghcr_update(self, image_name: str, current_tag: str, container_id: str) -> Optional[str]:
        """Check if there's a newer version on GitHub Container Registry."""
        # Skip checking if current tag is in skip list
        if any(skip in current_tag.lower() for skip in self.skip_tags):
            logger.debug(f"Skipping update check for ghcr.io/{image_name}:{current_tag} (tag in skip list)")
            return None
        
        try:
            # Get current image digest
            current_digest = self.get_image_digest(container_id)
            if not current_digest:
                logger.debug(f"Could not get current digest for ghcr.io/{image_name}:{current_tag}")
                return None
            
            # For GHCR, we can use the same approach as lscr.io
            logger.debug(f"Checking latest digest for ghcr.io/{image_name}:{current_tag}")
            
            # Use docker manifest inspect to get remote digest
            manifest_output = self.run_docker_command([
                'manifest', 'inspect', 
                f'ghcr.io/{image_name}:{current_tag}',
                '--verbose'
            ])
            
            if manifest_output:
                # Parse the manifest to get digest
                import json
                try:
                    manifest_data = json.loads(manifest_output)
                    remote_digest = manifest_data.get('Descriptor', {}).get('digest', '')
                    if remote_digest and remote_digest != current_digest:
                        return f"New version available (digest changed)"
                except json.JSONDecodeError:
                    logger.debug("Could not parse manifest data")
            
            return None
            
        except Exception as e:
            logger.warning(f"Failed to check ghcr.io for {image_name}:{current_tag}: {e}")
            return None
    
    def check_container_updates(self):
        """Check all running containers for updates."""
        containers = self.get_running_containers()
        updates = []
        skipped_registries = {}
        
        for container in containers:
            image = container.get('Image', '')
            container_name = container.get('Names', 'unknown')
            container_id = container.get('ID', '')
            
            logger.info(f"Checking container: {container_name} ({image})")
            
            registry, image_name, tag = self.parse_image_tag(image)
            
            # Check different registries
            if registry == 'docker.io':
                update_info = self.check_dockerhub_update(image_name, tag)
                if update_info:
                    updates.append({
                        'container': container_name,
                        'current_image': image,
                        'update_info': update_info
                    })
                    logger.info(f"Update available for {container_name}")
            elif registry == 'lscr.io':
                update_info = self.check_lscr_update(image_name, tag, container_id)
                if update_info:
                    updates.append({
                        'container': container_name,
                        'current_image': image,
                        'update_info': update_info
                    })
                    logger.info(f"Update available for {container_name}")
            elif registry == 'ghcr.io':
                update_info = self.check_ghcr_update(image_name, tag, container_id)
                if update_info:
                    updates.append({
                        'container': container_name,
                        'current_image': image,
                        'update_info': update_info
                    })
                    logger.info(f"Update available for {container_name}")
            elif registry in ['quay.io']:
                # These registries could be supported in the future
                logger.info(f"Container {container_name} uses {registry} registry (not yet supported)")
                if registry not in skipped_registries:
                    skipped_registries[registry] = []
                skipped_registries[registry].append(container_name)
            else:
                logger.debug(f"Container {container_name} uses unsupported registry: {registry}")
                if registry not in skipped_registries:
                    skipped_registries[registry] = []
                skipped_registries[registry].append(container_name)
        
        # Log summary of skipped registries
        if skipped_registries:
            logger.info("Skipped containers from unsupported registries:")
            for reg, containers in skipped_registries.items():
                logger.info(f"  {reg}: {', '.join(containers)}")
        
        return updates, skipped_registries
    
    def send_telegram_notification(self, updates, skipped_registries=None):
        """Send update notifications to Telegram."""
        if skipped_registries is None:
            skipped_registries = {}
            
        if not updates and not skipped_registries:
            logger.info("No updates found and no containers from unsupported registries")
            return
        
        message = ""
        
        if updates:
            message = "🐳 *Docker Container Updates Available*\n\n"
            for update in updates:
                message += f"📦 *Container:* `{update['container']}`\n"
                message += f"   *Current:* `{update['current_image']}`\n"
                message += f"   *Status:* {update['update_info']}\n\n"
        
        # Optionally include info about skipped registries
        if skipped_registries and self.config.getboolean('docker', 'notify_unsupported_registries', fallback=False):
            if not message:
                message = "🐳 *Docker Container Check*\n\n"
            message += "\n⚠️ *Containers from unsupported registries:*\n"
            for registry, containers in skipped_registries.items():
                message += f"   • {registry}: {', '.join(containers)}\n"
        
        if message:
            message += f"\n_Checked at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}_"
            
            url = f"https://api.telegram.org/bot{self.telegram_token}/sendMessage"
            data = {
                'chat_id': self.telegram_chat_id,
                'text': message,
                'parse_mode': 'Markdown'
            }
            
            try:
                response = requests.post(url, json=data, timeout=10)
                response.raise_for_status()
                logger.info("Telegram notification sent successfully")
            except requests.RequestException as e:
                logger.error(f"Failed to send Telegram notification: {e}")
    
    def send_error_notification(self, error_message: str):
        """Send error notification to Telegram."""
        message = f"❌ *Docker Update Checker Error*\n\n`{error_message}`"
        
        url = f"https://api.telegram.org/bot{self.telegram_token}/sendMessage"
        data = {
            'chat_id': self.telegram_chat_id,
            'text': message,
            'parse_mode': 'Markdown'
        }
        
        try:
            requests.post(url, json=data, timeout=10)
        except:
            pass  # Silently fail if we can't send the error notification
    
    def run(self):
        """Main execution method."""
        logger.info("Starting Docker update check...")
        
        try:
            updates, skipped_registries = self.check_container_updates()
            
            if updates:
                logger.info(f"Found {len(updates)} container(s) with available updates")
                self.send_telegram_notification(updates, skipped_registries)
            elif skipped_registries and self.config.getboolean('docker', 'notify_unsupported_registries', fallback=False):
                logger.info("No updates available, but found containers from unsupported registries")
                self.send_telegram_notification([], skipped_registries)
            else:
                logger.info("No updates available for running containers")
                
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            import traceback
            logger.error(traceback.format_exc())
            # Send error notification to Telegram
            self.send_error_notification(str(e))
            sys.exit(1)


def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Check Docker containers for updates')
    parser.add_argument(
        '-c', '--config',
        default='/etc/docker-update-checker/config.ini',
        help='Path to configuration file'
    )
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Enable verbose logging'
    )
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    checker = DockerUpdateChecker(config_path=args.config)
    checker.run()


if __name__ == '__main__':
    main()