#!/bin/bash
set -e

echo "Uninstalling the NPM Proxy & Cloudflare DNS Update Service..."

# Stop and disable the systemd timer and service
echo "Stopping and disabling the systemd timer..."
sudo systemctl stop ddns.timer
sudo systemctl disable ddns.timer

echo "Stopping and disabling the systemd service..."
sudo systemctl stop ddns.service
sudo systemctl disable ddns.service

# Remove the systemd unit files
echo "Removing systemd unit files..."
sudo rm -f /etc/systemd/system/ddns.timer
sudo rm -f /etc/systemd/system/ddns.service

# Reload systemd to apply changes
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Remove the generated configuration file (if present)
CONFIG_FILE="config.py"
if [ -f "$CONFIG_FILE" ]; then
    echo "Removing configuration file ($CONFIG_FILE)..."
    rm -f "$CONFIG_FILE"
fi

echo "Uninstallation complete."
