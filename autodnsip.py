#!/usr/bin/env python3
import requests
import json
import os

# Import configuration values from config.py
import config

NPM_API_URL = config.NPM_API_URL
NPM_API_USER = config.NPM_API_USER
NPM_API_PASS = config.NPM_API_PASS
CLOUDFLARE_API_TOKEN = config.CLOUDFLARE_API_TOKEN
CLOUDFLARE_ZONE_ID = config.CLOUDFLARE_ZONE_ID

def get_npm_token():
    """Gets an API token from NPM."""
    url = f"{NPM_API_URL}/api/tokens"
    data = {"identity": NPM_API_USER, "secret": NPM_API_PASS}
    response = requests.post(url, json=data)
    response.raise_for_status()
    return response.json()['token']

def get_proxy_hosts(token):
    """Gets the list of proxy hosts from NPM."""
    url = f"{NPM_API_URL}/api/nginx/proxy-hosts"
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    return response.json()

def update_host_file(current_hosts, filename):
    """Writes the current hosts into the file."""
    with open(filename, "w") as f:
        for host in current_hosts:
            f.write(host + "\n")

def get_public_ip():
    """Fetches the public IP of this server."""
    try:
        response = requests.get("https://api.ipify.org?format=json")
        response.raise_for_status()
        return response.json()["ip"]
    except Exception as e:
        print("Error retrieving public IP:", e)
        return None

def check_cloudflare_record_exists(domain):
    """Checks if an A record already exists for the given domain in Cloudflare."""
    url = f"https://api.cloudflare.com/client/v4/zones/{CLOUDFLARE_ZONE_ID}/dns_records"
    params = {"type": "A", "name": domain}
    headers = {"Authorization": f"Bearer {CLOUDFLARE_API_TOKEN}"}
    response = requests.get(url, headers=headers, params=params)
    response.raise_for_status()
    results = response.json().get('result', [])
    return len(results) > 0

def create_cloudflare_a_record(domain, ip):
    """Creates an A record in Cloudflare for the given domain with the provided IP."""
    if check_cloudflare_record_exists(domain):
        print(f"A record already exists for {domain}, checking for update.")
        update_cloudflare_a_record(domain, ip)
        return

    url = f"https://api.cloudflare.com/client/v4/zones/{CLOUDFLARE_ZONE_ID}/dns_records"
    headers = {
        "Authorization": f"Bearer {CLOUDFLARE_API_TOKEN}",
        "Content-Type": "application/json"
    }
    data = {
        "type": "A",
        "name": domain,
        "content": ip,
        "ttl": 3600,
        "proxied": True
    }
    response = requests.post(url, headers=headers, json=data)
    try:
        response.raise_for_status()
        print(f"A record created for {domain} with IP {ip}")
    except requests.exceptions.HTTPError:
        error_detail = response.json()
        print(f"Error creating Cloudflare A record for {domain}: {response.status_code} {response.reason}")
        print("Details:", error_detail)

def update_cloudflare_a_record(domain, new_ip):
    """Updates the A record in Cloudflare for the given domain with the new IP if it differs."""
    url = f"https://api.cloudflare.com/client/v4/zones/{CLOUDFLARE_ZONE_ID}/dns_records"
    params = {"type": "A", "name": domain}
    headers = {"Authorization": f"Bearer {CLOUDFLARE_API_TOKEN}", "Content-Type": "application/json"}
    response = requests.get(url, headers=headers, params=params)
    response.raise_for_status()
    results = response.json().get('result', [])
    if not results:
        print(f"No A record found for {domain} to update, creating one.")
        create_cloudflare_a_record(domain, new_ip)
        return
    for record in results:
        if record.get('content') != new_ip:
            record_id = record.get('id')
            update_url = f"https://api.cloudflare.com/client/v4/zones/{CLOUDFLARE_ZONE_ID}/dns_records/{record_id}"
            data = {
                "type": "A",
                "name": domain,
                "content": new_ip,
                "ttl": 3600,
                "proxied": True
            }
            update_response = requests.put(update_url, headers=headers, json=data)
            try:
                update_response.raise_for_status()
                print(f"A record updated for {domain} to IP {new_ip}")
            except requests.exceptions.HTTPError:
                error_detail = update_response.json()
                print(f"Error updating Cloudflare A record for {domain}: {update_response.status_code} {update_response.reason}")
                print("Details:", error_detail)
        else:
            print(f"A record for {domain} already has the correct IP {new_ip}")

def delete_cloudflare_a_record(domain):
    """Deletes an A record in Cloudflare for the given domain."""
    url = f"https://api.cloudflare.com/client/v4/zones/{CLOUDFLARE_ZONE_ID}/dns_records"
    params = {"type": "A", "name": domain}
    headers = {"Authorization": f"Bearer {CLOUDFLARE_API_TOKEN}"}
    response = requests.get(url, headers=headers, params=params)
    response.raise_for_status()
    results = response.json().get('result', [])
    if not results:
        print(f"No A record found for {domain}")
        return
    for record in results:
        record_id = record.get('id')
        del_url = f"https://api.cloudflare.com/client/v4/zones/{CLOUDFLARE_ZONE_ID}/dns_records/{record_id}"
        del_response = requests.delete(del_url, headers=headers)
        try:
            del_response.raise_for_status()
            print(f"A record deleted for {domain}")
        except requests.exceptions.HTTPError:
            error_detail = del_response.json()
            print(f"Error deleting Cloudflare A record for {domain}: {del_response.status_code} {del_response.reason}")
            print("Details:", error_detail)

if __name__ == "__main__":
    token = get_npm_token()
    proxy_hosts = get_proxy_hosts(token)
    current_domains = {domain for host in proxy_hosts for domain in host['domain_names']}

    # Read the previous domains from file
    filename = "proxy_hosts.txt"
    if os.path.exists(filename):
        with open(filename, "r") as f:
            previous_domains = {line.strip() for line in f if line.strip()}
    else:
        previous_domains = set()

    created_domains = current_domains - previous_domains
    deleted_domains = previous_domains - current_domains

    # Retrieve current public IP and monitor for changes
    current_public_ip = get_public_ip()
    if not current_public_ip:
        print("Could not retrieve public IP, aborting update.")
        exit(1)
    ip_filename = "public_ip.txt"
    if os.path.exists(ip_filename):
        with open(ip_filename, "r") as f:
            old_ip = f.read().strip()
    else:
        old_ip = None

    if old_ip != current_public_ip:
        print(f"Public IP changed: {old_ip} -> {current_public_ip}")
        with open(ip_filename, "w") as f:
            f.write(current_public_ip)
        # Update all existing records with the new public IP
        for domain in current_domains:
            try:
                update_cloudflare_a_record(domain, current_public_ip)
            except Exception as e:
                print(f"Error updating Cloudflare A record for {domain}: {e}")
    else:
        print("Public IP unchanged.")

    if created_domains:
        print("Created proxy hosts:")
        for domain in created_domains:
            print(f"  - {domain}")
    if deleted_domains:
        print("Deleted proxy hosts:")
        for domain in deleted_domains:
            print(f"  - {domain}")
    if not created_domains and not deleted_domains:
        print("No changes in proxy hosts.")

    for domain in created_domains:
        try:
            create_cloudflare_a_record(domain, current_public_ip)
        except Exception as e:
            print(f"Error processing Cloudflare creation for {domain}: {e}")

    for domain in deleted_domains:
        try:
            delete_cloudflare_a_record(domain)
        except Exception as e:
            print(f"Error processing Cloudflare deletion for {domain}: {e}")

    update_host_file(current_domains, filename)
