#! /usr/bin/python3
# This script fetches domains from Cloudflare for SaaS, and also domains from the WikiDiscover API, and the redirect domains from the repo redirects file.
# It compares the two lists, writes the results to files, and pushes changes to a Git repository.

import requests
import yaml
import os
import subprocess
import argparse

# Variables for output files and proxy settings
CLOUDFLARE_OUTPUT = "cloudflare_domains"
WIKIDISCOVER_OUTPUT = "wikidiscover_output.yaml"
LOG_FILE = "domain_comparisons"
EXEMPT_DOMAINS = ["analytics.wikitide.net", "grafana.wikitide.net", "monitoring.wikitide.net", "orain.org", "phorge-static.wikitide.net",
    "static.wikitide.net", "wikitide.com", "www.orain.org"]
PROXY = "http://bastion.fsslc.wtnet:8080"
proxies = {"http": PROXY, "https": PROXY}

# Cloudflare credentials and headers
CLOUDFLARE_API_TOKEN = "<%= @cloudflare_api_token %>"
CLOUDFLARE_ZONE_ID = "<%= @cloudflare_zone_id %>"
CLOUDFLARE_API_URL = f"https://api.cloudflare.com/client/v4/zones/{CLOUDFLARE_ZONE_ID}/custom_hostnames"

cf_headers = {
    "Authorization": f"Bearer {CLOUDFLARE_API_TOKEN}",
    "X-Auth-Key": f"{CLOUDFLARE_API_TOKEN}",
    "Content-Type": "application/json",
    "User-Agent": "wikitide/listdomains.py (operated by WikiTide Foundation Technology Team - https://wikitide.org)"
}


def get_cloudflare_domains(quiet=False):
    all_domains = []
    page = 1
    # 50 domains per page is the maximum allowed by Cloudflare API
    # We will paginate through all results until we get an empty page
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
        if not quiet:
            print(f"Fetched {len(all_domains)} total domains from Cloudflare (page {page})...")
        page += 1
    return sorted(set(all_domains))


def get_wikidiscover_data():
    url = 'https://meta.miraheze.org/w/api.php'

    # Headers for the WikiDiscover API request
    headers = {
        "User-Agent": "wikitide/listdomains.py (operated by WikiTide Foundation Technology Team - https://wikitide.org)"
    }
    params = {
        'action': 'query',
        'format': 'json',
        'list': 'wikidiscover',
        'wdcustomurl': 'true',
        'wdprop': 'url',
        'wdlimit': '500'
    }

    yaml_output = {}
    domain_list = []
    offset = 0

    while True:
        if offset > 0:
            params['wdoffset'] = str(offset)

        response = requests.get(url, headers=headers, params=params, proxies=proxies)
        response.raise_for_status()

        result = response.json().get('query', {}).get('wikidiscover', {})
        wikis_data = result.get('wikis', {})
        count = result.get('count', 0)

        for dbname, info in wikis_data.items():
            wiki_url = info.get('url')
            if dbname.endswith("wiki") and wiki_url:
                yaml_output[dbname] = wiki_url
                domain = wiki_url.split("//")[1]
                domain_list.append(domain)

        if count == 0 or len(wikis_data) == 0:
            break

        print(f"Fetched {len(yaml_output)} wikis so far (offset: {offset})...")
        offset += len(wikis_data)

    return yaml_output, sorted(set(domain_list))


def get_redirects(workdir):
    os.chdir(workdir)

    with open("redirects.yaml") as redirs:
        redirects = yaml.safe_load(redirs)

    redirect_list = []

    for key in list(redirects):
        redirect_list.append(redirects[key]["url"])

    return sorted(set(redirect_list))


def write_files(workdir, cf_list=None, wd_yaml=None, wd_domains=None, redirect_list=None):
    os.chdir(workdir)

    if cf_list is not None:
        with open(CLOUDFLARE_OUTPUT, "w") as f:
            f.write("\n".join(cf_list))

    if wd_yaml is not None:
        with open(WIKIDISCOVER_OUTPUT, "w") as f:
            yaml.dump(wd_yaml, f, sort_keys=True)

    if cf_list is not None and wd_domains is not None:
        cf_set = set(cf_list)
        wd_set = set(wd_domains)
        exempt_set = set(EXEMPT_DOMAINS)

        only_in_cf = cf_set - wd_set - exempt_set
        if redirect_list is not None:
            redirect_set = set(redirect_list)
            only_in_cf = only_in_cf - redirect_set
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


def git_push(workdir):
    os.chdir(workdir)

    subprocess.run([
        "git", "config", "--global", "core.sshCommand",
        "ssh -i /var/lib/nagios/id_ed25519 -F /dev/null -o ProxyCommand='nc -X connect -x bastion.fsslc.wtnet:8080 %h %p'"
    ], check=True)

    subprocess.run(["git", "-C", workdir, "config", "user.name", "WikiTideBot"], check=True)
    subprocess.run(["git", "-C", workdir, "config", "user.email", "noreply@wikitide.org"], check=True)
    subprocess.run(["git", "add", CLOUDFLARE_OUTPUT, WIKIDISCOVER_OUTPUT, LOG_FILE], check=True)

    result = subprocess.run(["git", "diff", "--cached", "--quiet"])
    if result.returncode == 0:
        print("No changes to commit.")
        return

    subprocess.run(["git", "commit", "-m", "Bot: Auto-update domain lists"], check=True)
    subprocess.run(["git", "push", "origin"], check=True)


def main():
    parser = argparse.ArgumentParser(description="Fetch and compare domains from Cloudflare and WikiDiscover.")
    parser.add_argument("--workdir", type=str, default="/srv/ssl/ssl", help="Working directory containing the Git repo.")
    parser.add_argument("--dry-run", action="store_true", help="Do not push changes to Git.")
    parser.add_argument("--source", choices=["cloudflare", "wikidiscover", "all"], default="all", help="Which data sources to use.")
    parser.add_argument("--quiet", action="store_true", help="Suppress all console output.")

    args = parser.parse_args()

    # Validate working directory
    if not os.path.exists(args.workdir):
        print(f"Error: Working directory '{args.workdir}' does not exist!", file=sys.stderr)
        sys.exit(1)

    if not os.access(args.workdir, os.W_OK):
        print(f"Error: You do not have write permissions for '{args.workdir}'!", file=sys.stderr)
        sys.exit(1)

    subprocess.run(["git", "-C", workdir, "pull"], check=True)

    cf_domains = None
    wd_yaml = None
    wd_domains = None
    redirect_list = None

    if args.source in ("cloudflare", "all"):
        if not args.quiet:
            print("Fetching Cloudflare domains...")
        cf_domains = get_cloudflare_domains(quiet=args.quiet)

    if args.source in ("wikidiscover", "all"):
        if not args.quiet:
            print("Fetching WikiDiscover data...")
        wd_yaml, wd_domains = get_wikidiscover_data()

    if args.source in ("redirects", "all"):
        if not args.quiet:
            print("Fetching redirect domains...")
        redirect_list = get_redirects(args.workdir)

    if not args.quiet:
        print("Writing output files...")
    write_files(args.workdir, cf_domains, wd_yaml, wd_domains, redirect_list)

    if args.dry_run:
        if not args.quiet:
            print("Dry run enabled: skipping git push...")
    else:
        if not args.quiet:
            print("Pushing to GitHub...")
        git_push(args.workdir)

    if not args.quiet:
        print("Done!")

if __name__ == "__main__":
    main()
