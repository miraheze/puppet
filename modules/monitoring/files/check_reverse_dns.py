#! /usr/bin/python3

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

sys.excepthook = lambda type, value, traceback: print(f'{type.__name__}: {value}')


def get_args():
    """Return specified arguments.

    :return: parsed arguments from argparse
    """

    parser = argparse.ArgumentParser(
        description='Check reverse DNS entry for hostname'
    )
    parser.add_argument(
        '-H',
        '--hostname',
        required=True,
        help='hostname to check',
        dest='hostname'
    )
    parser.add_argument(
        '-r',
        '--regex',
        required=True,
        help='regex for match',
        dest='regex'
    )

    return parser.parse_args()


def check_records(hostname):
    """Check NS and CNAME records for given hostname."""
    domains_as_tlds = ('eu.org','for.uz')
    cname_check_impossible = False

    nameservers = []
    domain_parts = tldextract.extract(hostname)
    root_domain = domain_parts.registered_domain

    if root_domain in domains_as_tlds:
        extracted = tldextract.extract(domain_parts.subdomain + '.' + domain_parts.suffix)
        root_domain = extracted.domain + '.' + root_domain

    dns_resolver = resolver.Resolver(configure=False)
    dns_resolver.nameservers = ['2606:4700:4700::1111']

    try:
        nameserversans = dns_resolver.resolve(root_domain, 'NS')
        for nameserver in nameserversans:
            nameserver = str(nameserver)
            nameservers.append(nameserver)
            flatten_manadatory_providers = (
                '.ns.cloudflare.com.',
                '.dreamhost.com.',
                '.ns.porkbun.com.',
                '.registrar-servers.com.',
            )
            cname_check_impossible = nameserver.endswith(flatten_manadatory_providers)

        if sorted(list(nameservers)) == sorted(['ns1.miraheze.org.', 'ns2.miraheze.org.']):
            return 'NS'
    except resolver.NoAnswer:
        nameservers = None

    try:
        cname = str(dns_resolver.resolve(hostname, 'CNAME')[0])
    except resolver.NoAnswer:
        cname = None

    if re.match("[A-Za-z]+.miraheze.org", cname):
        return 'CNAME'
    elif cname is None and cname_check_impossible:
        return 'CNAMEFLAT'
    return {'NS': nameservers, 'CNAME': cname}


def get_reverse_dnshostname(hostname):
    """Retrieve reverse DNS entry for given hostname.

    :param hostname: hostname to find reverse DNS entry for
    :return: reverse DNS entry if possible, otherwise returns UNKOWN and exits
    """

    try:
        dns_resolver = resolver.Resolver(configure=False)
        dns_resolver.nameservers = ['2606:4700:4700::1111']

        resolved_ip_addr = str(dns_resolver.resolve(hostname, 'AAAA')[0])
        ptr_record = reversename.from_address(resolved_ip_addr)
        rev_host = str(dns_resolver.resolve(ptr_record, 'PTR')[0]).rstrip('.')

        return rev_host
    except (resolver.NXDOMAIN, resolver.NoAnswer):
        print(f'rDNS WARNING - reverse DNS entry for {hostname} could not be found')
        sys.exit(1)


def main():
    """Execute functions."""

    args = get_args()
    try:
        rdns_hostname = get_reverse_dnshostname(args.hostname)
    except resolver.NoNameservers:
        print(f'rDNS CRITICAL - {args.hostname} All nameservers failed to answer the query.')
        sys.exit(2)

    match = re.search(args.regex, rdns_hostname)

    if match:
        text = f'SSL OK - {args.hostname} reverse DNS resolves to {rdns_hostname}'
    else:
        print(f'rDNS CRITICAL - {args.hostname} reverse DNS resolves to {rdns_hostname}')
        sys.exit(2)

    records = check_records(args.hostname)
    if records == 'NS':
        text += ' - NS  RECORDS OK'
        print(text)
        sys.exit(0)
    elif records == 'CNAME':
        text += ' - CNAME OK'
        print(text)
        sys.exit(0)
    elif records == 'CNAMEFLAT':
        text += ' - CNAME FLAT'
        print(text)
        sys.exit(0)
    else:
        print(f'SSL WARNING - rDNS OK but records conflict. {str(records)}')
        sys.exit(1)


if __name__ == '__main__':
    main()
