# DDNS with Nginx Proxy Manager & Cloudflare

A simple solution for automatically updating DNS A records on [Cloudflare](https://cloudflare.com) based on your server’s public IP, using [Nginx Proxy Manager (NPM)](https://nginxproxymanager.com/) as the source of domain configurations. This setup relies on `systemd` timers to periodically check your public IP, add new domains, and remove deleted ones.

## One-Command Installation

If you trust this repository and want a quick setup, run this single command:

    curl -fsSL https://raw.githubusercontent.com/<yourusername>/<yourrepo>/main/install.sh | bash

> **Note**: Replace `<yourusername>` and `<yourrepo>` with your actual GitHub username and repository name.

---

## Overview

1. **Bash Installer** (`install.sh`):  
   Prompts you for NPM & Cloudflare credentials, generates a `config.py`, and sets up a `systemd` service & timer.  
2. **Python Script** (`autodnsip.py`):  
   Periodically syncs NPM’s domains with Cloudflare DNS records.  
3. **Bash Uninstaller** (`uninstall.sh`):  
   Removes the timer/service and cleans up configuration files.

---

## Files

- **install.sh**  
  Bash script that prompts for credentials, creates `config.py`, and sets up `ddns.service` + `ddns.timer`.

- **autodnsip.py**  
  Python script that handles the logic to sync Cloudflare DNS with the public IP and NPM domains.

- **uninstall.sh**  
  Bash script that fully removes the `ddns.service` and `ddns.timer`, plus configuration cleanup.

---

## Requirements

1. **Linux** with `systemd` (Ubuntu, Debian, CentOS, Fedora, etc.).  
2. **Python 3** (to run `autodnsip.py`).  
3. **`requests`** Python library (install via `pip install requests`).  
4. **NPM Credentials**: Valid NPM (Nginx Proxy Manager) API URL, username, and password.  
5. **Cloudflare Credentials**: For each domain, an API token with DNS edit permissions and the corresponding Zone ID.

---

## Manual Installation (Alternative to One-Command)

1. **Clone or Download** this repository:

        git clone https://github.com/<yourusername>/<yourrepo>.git
        cd <yourrepo>

2. **Make the installer script executable** (if needed):

        chmod +x install.sh

3. **Run the installer**:

        ./install.sh

   - The script will ask for NPM and Cloudflare details, then create/update files and set up the systemd timer.

4. **Check the service status**:

        systemctl status ddns.timer
        # or
        sudo journalctl -u ddns.service -f

---

## How It Works

1. **NPM Auth Token**:  
   `autodnsip.py` first obtains an auth token from NPM using your credentials.
2. **Domains from NPM**:  
   It fetches the list of domains from NPM’s `/api/nginx/proxy-hosts`.
3. **Public IP**:  
   Queries `https://api.ipify.org?format=json` to get your server’s current public IP.
4. **Cloudflare Sync**:
   - **Adds** an A record for any new domains.
   - **Updates** existing A records if the IP changes.
   - **Deletes** old A records for domains that no longer exist in NPM.
5. **State Tracking**:
   - `proxy_hosts.txt` tracks domain names from the last run.
   - `domain_ips.json` stores each domain’s last known IP.

---

## Customization

- **Adjust Timer Interval**:  
  By default, the timer runs every 5 seconds (edit `ddns.timer` to change):
  
        [Timer]
        OnBootSec=5sec
        OnUnitActiveSec=5sec

  For example, change `OnUnitActiveSec=5min` to run every 5 minutes.

- **Proxied vs. Unproxied**:  
  In `autodnsip.py`, `"proxied": True` can be set to `False` if you want DNS-only (no Cloudflare proxy).

---

## Uninstallation

1. **If you cloned the repo**, navigate into it:

        cd <yourrepo>

2. **Make uninstaller executable**:

        chmod +x uninstall.sh

3. **Run uninstaller**:

        ./uninstall.sh

   - Stops and disables both `ddns.timer` and `ddns.service`.
   - Removes them from `/etc/systemd/system/`.
   - Deletes `config.py` and the working directory if created by the installer.

---

## Troubleshooting

- **Permission Errors**:  
  If you get permission issues, use `sudo` or ensure your user can manage `systemd`.
- **Missing Dependencies**:  
  Install `requests` with `pip3 install requests`.
- **NPM Access**:  
  Make sure your NPM instance is reachable at the provided URL. Confirm credentials are correct.
- **Cloudflare API Errors**:
  - Verify the Zone ID and API token (with DNS edit permissions) are correct.
  - Check Cloudflare dashboard for your zone under Settings → API Tokens.

---

## License

*(Optional: Insert your chosen license text here, e.g., MIT, Apache-2.0, etc.)*

---

**Enjoy automated DNS management with Cloudflare & NPM!**  
For questions or issues, please open an [issue](../../issues) or submit a pull request.
