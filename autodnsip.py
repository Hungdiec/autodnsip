#!/bin/bash
set -e

echo "Welcome to the NPM Proxy & Cloudflare DNS Update Service Installer."
echo "Please provide the following configuration values."

# Prompt for NPM API configuration
read -p "Enter NPM API URL (default: http://127.0.0.1): " NPM_API_URL
NPM_API_URL=${NPM_API_URL:-"http://127.0.0.1"}

read -p "Enter NPM API user: " NPM_API_USER
read -p "Enter NPM API password: " NPM_API_PASS

# Prompt for how many domains to control
read -p "How many domains do you want to control? " domain_count

cf_config_entries=""
for (( i=1; i<=domain_count; i++ ))
do
    echo "Enter Cloudflare credentials for domain #$i:"
    read -p "  Root Domain (e.g., example.com): " root_domain
    read -p "  API Token: " cf_token
    read -p "  Zone ID: " zone_id

    if [ $i -eq 1 ]; then
        cf_config_entries="\"$root_domain\": {\"API_TOKEN\": \"$cf_token\", \"ZONE_ID\": \"$zone_id\"}"
    else
        cf_config_entries+=",\n    \"$root_domain\": {\"API_TOKEN\": \"$cf_token\", \"ZONE_ID\": \"$zone_id\"}"
    fi
done

echo "Saving configuration to config.py..."
cat > config.py <<EOF
# Auto-generated configuration file

NPM_API_URL = "${NPM_API_URL}"
NPM_API_USER = "${NPM_API_USER}"
NPM_API_PASS = "${NPM_API_PASS}"
CLOUDFLARE_CONFIG = {
    ${cf_config_entries}
}
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
ExecStart=/usr/bin/python3 $(pwd)/autodnsip.py

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
echo "Run command \"systemctl status ddns.service\" to see service status."
echo "Run command \"sudo journalctl -u ddns.service -f\" to see service log."
