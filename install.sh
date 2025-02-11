#!/bin/bash
set -e

echo "Welcome to the NPM Proxy & Cloudflare DNS Update Service Installer."
echo "Please provide the following configuration values."

# Prompt for configuration values, with defaults where applicable
read -p "Enter NPM API URL (default: http://127.0.0.1): " NPM_API_URL
NPM_API_URL=${NPM_API_URL:-"http://127.0.0.1"}

read -p "Enter NPM API user: " NPM_API_USER
read -p "Enter NPM API password: " NPM_API_PASS

read -p "Enter Cloudflare API token: " CLOUDFLARE_API_TOKEN
read -p "Enter Cloudflare Zone ID: " CLOUDFLARE_ZONE_ID

echo "Saving configuration to config.py..."
cat > config.py <<EOF
# Auto-generated configuration file

NPM_API_URL = "${NPM_API_URL}"
NPM_API_USER = "${NPM_API_USER}"
NPM_API_PASS = "${NPM_API_PASS}"
CLOUDFLARE_API_TOKEN = "${CLOUDFLARE_API_TOKEN}"
CLOUDFLARE_ZONE_ID = "${CLOUDFLARE_ZONE_ID}"
EOF

echo "Configuration saved."

# Create a systemd service file template
SERVICE_FILE="ddns.service"
echo "Creating systemd service file..."

cat > ${SERVICE_FILE} <<EOF
[Unit]
Description=Update NPM Proxy Hosts and Cloudflare DNS A Records
After=network.target

[Service]
Type=oneshot
User=$(whoami)
WorkingDirectory=$(pwd)
ExecStart=/usr/bin/python3 $(pwd)/ddns_update.py

[Install]
WantedBy=multi-user.target
EOF

# Create a systemd timer file to run the service every 5 seconds
TIMER_FILE="ddns.timer"
echo "Creating systemd timer file..."

cat > ${TIMER_FILE} <<EOF
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

echo "Installing systemd service and timer..."
sudo cp ${SERVICE_FILE} /etc/systemd/system/
sudo cp ${TIMER_FILE} /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable ddns.timer
sudo systemctl start ddns.timer

echo "Installation complete. The service is scheduled to run every 5 seconds via systemd timer."
echo "Run command \"systemctl status ddns.service\" to see service status"
echo "Run command \"sudo journalctl -u ddns.service -f\" to see service log"
