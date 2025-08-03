#! /usr/bin/python3

# This script fetches domains from Cloudflare for SaaS, and also domains from the WikiDiscover API.
# It compares the two lists, writes the results to files, and pushes changes to a Git repository.

import requests
import yaml
import json
import os
import subprocess

# Configuration variables
CLOUDFLARE_API_TOKEN = "<%= @cloudflare_api_token %>"
CLOUDFLARE_ZONE_ID = "<%= @cloudflare_zone_id %>"
CLOUDFLARE_API_URL = f"https://api.cloudflare.com/client/v4/zones/{CLOUDFLARE_ZONE_ID}/custom_hostnames"

WIKIDISCOVER_API_URL = "https://meta.miraheze.org/w/api.php?action=query&list=wikidiscover&formatversion=2&wdcustomurl=true&wdprop=url&wdlimit=1000&format=json"

CLOUDFLARE_OUTPUT = "cloudflare_domains"
WIKIDISCOVER_OUTPUT = "wikidiscover_output.yaml"
LOG_FILE = "domain_comparisons"

# Proxy configuration for requests
PROXY = "http://bastion.fsslc.wtnet:8080"  # Or your actual proxy
proxies = {
    "http": PROXY,
    "https": PROXY
}

# Headers for Cloudflare API requests
cf_headers = {
    "X-Auth-Key": f"{CLOUDFLARE_API_TOKEN}",
    "Content-Type": "application/json"
    "User-Agent": "wikitide/listdomains.py (operated by WikiTide Foundation Technology Team - https://wikitide.org)"
}

# Headers for WikiDiscover API requests
wd_headers = {
    "User-Agent": "wikitide/listdomains.py (operated by WikiTide Foundation Technology Team - https://wikitide.org)"
}

# Step 1: Get Cloudflare domains
def get_cloudflare_domains():
    all_domains = []
    page = 1
    per_page = 50
    while True:
        resp = requests.get(f"{CLOUDFLARE_API_URL}?page={page}&per_page={per_page}", headers=cf_headers, proxies=proxies)
        resp.raise_for_status()
        data = resp.json()
        result = data.get("result", [])
        if not result:
            break
        for entry in result:
            hostname = entry.get("hostname")
            if hostname:
                all_domains.append(hostname)
        page += 1
    return sorted(set(all_domains))

# Step 2: Get WikiDiscover data
def get_wikidiscover_data():
    response = requests.get(WIKIDISCOVER_API_URL, headers=wd_headers)
    response.raise_for_status()
    data = response.json()
    wikis = data.get("query", {}).get("wikidiscover", {}).get("wikis", {})
    yaml_output = {}
    domain_list = []
    for dbname, info in wikis.items():
        url = info.get("url")
        if dbname.endswith("wiki") and url:
            yaml_output[dbname] = url
            domain = url.split("//")[1]
            domain_list.append(domain)
    return yaml_output, sorted(set(domain_list))

# Step 3: Write files and compare domains
def write_files(cloudflare_list, wikidiscover_yaml, wikidiscover_domains):
    # Change to the directory where the git repo is located
    os.chdir("/srv/ssl/ssl")

    # Cloudflare domains
    with open(CLOUDFLARE_OUTPUT, "w") as f:
        f.write("\n".join(cloudflare_list))

    # WikiDiscover YAML
    with open(WIKIDISCOVER_OUTPUT, "w") as f:
        yaml.dump(wikidiscover_yaml, f, sort_keys=True)

    # Compare the two lists
    cf_set = set(cloudflare_list)
    wd_set = set(wikidiscover_domains)

    only_in_cf = cf_set - wd_set
    only_in_wd = wd_set - cf_set

    with open(LOG_FILE, "w") as f:
        if only_in_cf:
            f.write("Domains in Cloudflare but not listed in WikiDiscover:\n")
            f.writelines(f"{domain}\n" for domain in sorted(only_in_cf))
        if only_in_wd:
            f.write("\nDomains listed in WikiDiscover but not in Cloudflare:\n")
            f.writelines(f"{domain}\n" for domain in sorted(only_in_wd))
        if not only_in_cf and not only_in_wd:
            f.write("All domains match between Cloudflare and WikiDiscover.\n")

# Step 4: Push changes to GitHub
import subprocess

def git_push():
    # Ensure the working directory is correct
    os.chdir("/srv/ssl/ssl")

    # Set Git SSH command for proxy and key
    subprocess.run([
        "git", "config", "--global", "core.sshCommand",
        "ssh -i /var/lib/nagios/id_ed25519 -F /dev/null -o ProxyCommand='nc -X connect -x bastion.fsslc.wtnet:8080 %h %p'"
    ], check=True)

    # Configure Git user info in the local repo
    subprocess.run([
        "git", "-C", "/srv/ssl/ssl/", "config", "user.name", "WikiTideBot"
    ], check=True)
    subprocess.run([
        "git", "-C", "/srv/ssl/ssl/", "config", "user.email", "noreply@wikitide.org"
    ], check=True)

    # Reset to the latest state from origin/main
    subprocess.run([
        "git", "-C", "/srv/ssl/ssl/", "reset", "--hard", "origin/main"
    ], check=True)
    subprocess.run([
        "git", "-C", "/srv/ssl/ssl/", "pull"
    ], check=True)

    # Add changed files
    subprocess.run(["git", "add", CLOUDFLARE_OUTPUT, WIKIDISCOVER_OUTPUT, LOG_FILE], check=True)

    # Commit and push
    subprocess.run(["git", "commit", "-m", "Automated domain sync update"], check=True)
    subprocess.run(["git", "push", "origin"], check=True)

def main():
    print("Fetching Cloudflare hostnames...")
    cf_domains = get_cloudflare_domains()

    print("Fetching WikiDiscover data...")
    wd_yaml, wd_domains = get_wikidiscover_data()

    print("Writing files...")
    write_files(cf_domains, wd_yaml, wd_domains)

    print("Pushing to GitHub...")
    git_push()

    print("Done!")

if __name__ == "__main__":
    main()
