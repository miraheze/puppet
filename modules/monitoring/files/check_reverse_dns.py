#!/usr/bin/env python3
"""
Script to check if reverse DNS entry for hostname matches given regex.

Version: 0.2.0 (2021-07-03)

Copyright (C) 2020 Ferran Tufan

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see <http://www.gnu.org/licenses/>.
"""

import argparse
from dns import reversename, resolver
import re
import sys
import tldextract


def get_args():
    """Return specified arguments.

    :return: parsed arguments from argparse
    """

    parser = argparse.ArgumentParser(
        description="Check reverse DNS entry for hostname"
    )
    parser.add_argument(
        '-H',
        '--hostname',
        required=True,
        help="hostname to check",
        dest="hostname"
    )
    parser.add_argument(
        '-r',
        '--regex',
        required=True,
        help="regex for match",
        dest="regex"
    )

    return parser.parse_args()


def check_records(hostname):
    """Check NS and CNAME records for given hostname."""
    extra_known_tlds = ('for.uz')
    uses_cf_at_root = False

    nameservers = []
    domain_parts = tldextract.extract(hostname)
    root_domain = domain_parts.registered_domain

    if root_domain in extra_known_tlds:
        extracted = tldextract.extract(domain_parts.subdomain + '.' + domain_parts.suffix)
        root_domain = extracted.domain + '.' + root_domain

    dns_resolver = resolver.Resolver(configure=False)
    dns_resolver.nameservers = ['2606:4700:4700::1111']

    try:
        nameserversans = dns_resolver.resolve(root_domain, 'NS')
        for nameserver in nameserversans:
            nameserver = str(nameserver)
            nameservers.append(nameserver)
            if nameserver.endswith('.ns.cloudflare.com.') or nameserver.endswith('.dreamhost.com.'):
                uses_cf_at_root = True

        if sorted(list(nameservers)) == sorted(['ns1.miraheze.org.', 'ns2.miraheze.org.']):
            return 'NS'
    except resolver.NoAnswer:
        nameservers = None

    try:
        cname = str(dns_resolver.resolve(hostname, 'CNAME')[0])
    except resolver.NoAnswer:
        cname = None

    if cname == 'mw-lb.miraheze.org.':
        return 'CNAME'
    elif cname is None and uses_cf_at_root:
        return 'CFCNAME'
    return {'NS': nameservers, 'CNAME': cname}


def get_reverse_dnshostname(hostname):
    """Retrieve reverse DNS entry for given hostname.

    :param hostname: hostname to find reverse DNS entry for
    :return: reverse DNS entry if possible, otherwise returns UNKOWN and exits"
    """

    try:
        dns_resolver = resolver.Resolver(configure=False)
        dns_resolver.nameservers = ['2606:4700:4700::1111']

        resolved_ip_addr = str(dns_resolver.resolve(hostname, 'AAAA')[0])
        ptr_record = reversename.from_address(resolved_ip_addr)
        rev_host = str(dns_resolver.resolve(ptr_record, "PTR")[0]).rstrip('.')

        return rev_host
    except (resolver.NXDOMAIN, resolver.NoAnswer):
        print("rDNS WARNING - reverse DNS entry for {} could not be found".format(hostname))
        sys.exit(1)


def main():
    """Execute functions."""

    args = get_args()
    try:
        rdns_hostname = get_reverse_dnshostname(args.hostname)
    except resolver.NoNameservers:
        print("rDNS CRITICAL - {} All nameservers failed to answer the query.".format(args.hostname))
        sys.exit(2)

    match = re.search(args.regex, rdns_hostname)

    if match:
        text = "SSL OK - {} reverse DNS resolves to {}".format(args.hostname, rdns_hostname)
    else:
        print("rDNS CRITICAL - {} reverse DNS resolves to {}".format(args.hostname, rdns_hostname))
        sys.exit(2)

    records = check_records(args.hostname)
    if records == 'NS':
        text = text + ' - NS  RECORDS OK'
        print(text)
        sys.exit(0)
    elif records == 'CNAME':
        text = text + ' - CNAME OK'
        print(text)
        sys.exit(0)
    elif records == 'CFCNAME':
        text = text + ' - CNAME FLAT'
        print(text)
        sys.exit(0)
    else:
        print(f'SSL WARNING - rDNS OK but records conflict. {str(records)}')
        sys.exit(1)


if __name__ == "__main__":
    main()
