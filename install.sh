#!/bin/bash
set -e

# Check if whiptail is installed
if ! command -v whiptail >/dev/null; then
    apt-get update && apt-get install -y whiptail
fi

# Colors for regular output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Window dimensions
WINDOW_HEIGHT=20
WINDOW_WIDTH=70

# Welcome screen
whiptail --title "DDNS Automation Setup" --msgbox "\
Welcome to the NPM Proxy & Cloudflare DNS Update Service Installer.

This wizard will guide you through the configuration process.

Please have ready:
• NPM API credentials
• Cloudflare API tokens
• Cloudflare Zone IDs" ${WINDOW_HEIGHT} ${WINDOW_WIDTH}

# NPM Configuration
NPM_API_URL=$(whiptail --title "NPM Configuration" --inputbox "\
Enter NPM API URL:" ${WINDOW_HEIGHT} ${WINDOW_WIDTH} "http://127.0.0.1" 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
    echo "Setup cancelled by user"
    exit 1
fi

NPM_API_USER=$(whiptail --title "NPM Configuration" --inputbox "\
Enter NPM API Username:" ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
    echo "Setup cancelled by user"
    exit 1
fi

NPM_API_PASS=$(whiptail --title "NPM Configuration" --passwordbox "\
Enter NPM API Password:" ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
    echo "Setup cancelled by user"
    exit 1
fi

# Domain count
domain_count=$(whiptail --title "Cloudflare Configuration" --inputbox "\
How many domains do you want to control?" ${WINDOW_HEIGHT} ${WINDOW_WIDTH} "1" 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
    echo "Setup cancelled by user"
    exit 1
fi

# Build the Cloudflare configuration
cf_config_entries=""
{
    for (( i=1; i<=domain_count; i++ ))
    do
        whiptail --title "Domain Configuration #$i" --msgbox "\
Please prepare the following information for domain #$i:
• Root Domain (e.g., example.com)
• Cloudflare API Token
• Cloudflare Zone ID" ${WINDOW_HEIGHT} ${WINDOW_WIDTH}

        # Get domain details
        root_domain=$(whiptail --title "Domain #$i Configuration" --inputbox "\
Enter Root Domain (e.g., example.com):" ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus != 0 ]; then
            echo "Setup cancelled by user"
            exit 1
        fi

        cf_token=$(whiptail --title "Domain #$i Configuration" --passwordbox "\
Enter Cloudflare API Token:" ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus != 0 ]; then
            echo "Setup cancelled by user"
            exit 1
        fi

        zone_id=$(whiptail --title "Domain #$i Configuration" --inputbox "\
Enter Cloudflare Zone ID:" ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus != 0 ]; then
            echo "Setup cancelled by user"
            exit 1
        fi

        if [ $i -eq 1 ]; then
            cf_config_entries="\"$root_domain\": {\"API_TOKEN\": \"$cf_token\", \"ZONE_ID\": \"$zone_id\"}"
        else
            cf_config_entries+=",\n    \"$root_domain\": {\"API_TOKEN\": \"$cf_token\", \"ZONE_ID\": \"$zone_id\"}"
        fi

        # Show progress in a more reliable way
        echo "XXX"
        echo $(( (i * 100) / domain_count ))
        echo "Configuring domain $i of $domain_count: $root_domain"
        echo "XXX"
    done
} 

# After configuration, show summary
whiptail --title "Configuration Summary" --msgbox "\
Configuration completed successfully!

Domains configured: $domain_count
NPM API URL: $NPM_API_URL
NPM Username: $NPM_API_USER

Press OK to continue with service installation." ${WINDOW_HEIGHT} ${WINDOW_WIDTH}
# Save configuration
{
    echo "Creating configuration files..."
    cat > config.json <<EOF
{
  "NPM_API_URL": "${NPM_API_URL}",
  "NPM_API_USER": "${NPM_API_USER}",
  "NPM_API_PASS": "${NPM_API_PASS}",
  "CLOUDFLARE_CONFIG": {
    ${cf_config_entries}
  }
}
EOF

    echo "Creating service files..."
    # Create systemd service file
    cat > ddns.service <<EOF
[Unit]
Description=Update NPM Proxy Hosts and Cloudflare DNS A Records
After=network.target

[Service]
Type=oneshot
User=$(whoami)
WorkingDirectory=$(pwd)
ExecStart=/usr/bin/python3 $(pwd)/autodnsip.py

[Install]
WantedBy=multi-user.target
EOF

    # Create timer file
    cat > ddns.timer <<EOF
[Unit]
Description=Run NPM Proxy Update every 5 seconds

[Timer]
OnBootSec=5sec
OnUnitActiveSec=5sec
AccuracySec=1sec
Unit=ddns.service

[Install]
WantedBy=timers.target
EOF

    # Install service files
    sudo cp ddns.service /etc/systemd/system/
    sudo cp ddns.timer /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable ddns.timer
    sudo systemctl start ddns.timer

} | whiptail --title "Installation Progress" --gauge "Installing service..." ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 0

# Final status display
if systemctl is-active --quiet ddns.timer; then
    whiptail --title "Installation Complete" --msgbox "\
Installation completed successfully!

Service Status: ACTIVE
Timer Status: ACTIVE

Usage Commands:
• View service status: systemctl status ddns.service
• View logs: journalctl -u ddns.service -f

Configuration has been saved to: $(pwd)/config.json" ${WINDOW_HEIGHT} ${WINDOW_WIDTH}
else
    whiptail --title "Installation Warning" --msgbox "\
Installation completed but service is not running.
Please check the logs using: journalctl -u ddns.service" ${WINDOW_HEIGHT} ${WINDOW_WIDTH}
fi

# Clear screen and show final message
clear
echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "${BLUE}Configuration file:${NC} $(pwd)/config.json"
echo -e "${BLUE}Service status:${NC} $(systemctl is-active ddns.service)"
echo -e "${BLUE}Timer status:${NC} $(systemctl is-active ddns.timer)"
