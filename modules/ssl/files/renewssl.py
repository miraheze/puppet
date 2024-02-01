#!/usr/bin/python3 -u

# Automatically renew LetsEncrypt SSL certificates
# expiring within a specified time or manually renew others.
#
# Universal Omega 2024

import os
import re
import argparse
import subprocess
import logging
from filelock import FileLock
from datetime import datetime

if os.path.exists('/var/log/ssl'):
    logging.basicConfig(filename='/var/log/ssl/renewssl.log', format='%(asctime)s - %(message)s', level=logging.INFO, force=True)


def get_ssl_domains(ssl_dir):
    """Returns a list of all SSL domains in the specified directory"""
    ssl_domains = []
    for dirpath, dirnames, filenames in os.walk(ssl_dir):
        if 'cert.pem' in filenames:
            ssl_domains.append(os.path.basename(dirpath))
    return ssl_domains


def get_secondary_domains(ssl_dir, domain):
    """Returns a list of all SSL secondary domains that is also for the same certificate"""
    cert_path = os.path.join(ssl_dir, domain, 'cert.pem')
    output = subprocess.check_output(['openssl', 'x509', '-in', cert_path, '-noout', '-text'])
    output = output.decode('utf-8')
    secondary_domains = re.findall(r'DNS:([^,\n]*)', output)
    if domain in secondary_domains:
        secondary_domains.remove(domain)
    return secondary_domains


def get_cert_expiry_date(domain):
    """Returns the expiry date of the SSL certificate for the specified domain"""
    cert_path = f'/etc/letsencrypt/live/{domain}/cert.pem'
    cert_expiry_date = subprocess.check_output(['openssl', 'x509', '-enddate', '-noout', '-in', cert_path])
    cert_expiry_date = cert_expiry_date.decode('utf-8').strip()[9:]
    return datetime.strptime(cert_expiry_date, '%b %d %H:%M:%S %Y %Z')


def days_until_expiry(expiry_date):
    """Returns the number of days until the specified expiry date"""
    days = (expiry_date - datetime.now()).days
    if expiry_date.time() < datetime.now().time():
        days += 1
    return days


def should_renew(domain, days_left, days_before_expiry, only_days, no_confirm):
    """Returns True if the SSL certificate should be renewed"""
    for cert in [domain] + get_secondary_domains('/etc/letsencrypt/live', domain):
        if '*' in cert:
            print(f'Wildcard certificate found: {cert}. Must be manually renewed within the next {days_left} days.')
            return False
    if days_before_expiry and days_left <= days_before_expiry and no_confirm:
        return True
    if only_days:
        return False
    if no_confirm:
        return True
    answer = input(f'The SSL certificate for {domain} is due to expire in {days_left} days. Do you want to renew it now? (y/n): ')
    return answer.lower() in ('y', 'yes')


class SSLRenewer:
    def __init__(self, ssl_dir, days_before_expiry, only_days, no_confirm):
        self.ssl_dir = ssl_dir
        self.days_before_expiry = days_before_expiry
        self.only_days = only_days
        self.no_confirm = no_confirm

    def run(self):
        """Main function that loops through all SSL domains and renews the certificates if necessary"""
        for domain in get_ssl_domains(self.ssl_dir):
            expiry_date = get_cert_expiry_date(domain)
            days_left = days_until_expiry(expiry_date)
            if should_renew(domain, days_left, self.days_before_expiry, self.only_days, self.no_confirm):
                filename = '/tmp/tmp_file.lock'
                lock = FileLock(filename)
                lock_acquired = False
                while not lock_acquired:
                    with lock:
                        lock.acquire()
                        try:
                            secondary_domains = []
                            if get_secondary_domains(self.ssl_dir, domain):
                                secondary_domains = ['--secondary', ' '.join(get_secondary_domains(self.ssl_dir, domain))]
                            command = ['sudo', '/root/ssl-certificate', '--domain', domain, '--renew', '--private', '--overwrite'] + secondary_domains
                            subprocess.call(command)
                            print(f'Executed renew command: {" ".join(command)}')
                            if os.path.exists('/var/log/ssl'):
                                logging.info(f'Renewed SSL certificate, {domain}, with command: {" ".join(command)}')
                            lock_acquired = True
                        finally:
                            lock.release()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Renews LetsEncrypt SSL certificates')
    parser.add_argument('--no-confirm', action='store_true', help='Renew certificates without asking for confirmation')
    parser.add_argument('--only-days', action='store_true', help='Only renew certificates expiring within days specified by --days-before-expiry')
    parser.add_argument('--days-before-expiry', type=int, help='Number of days before expiry to renew certs without a prompt for')
    args = parser.parse_args()

    ssl_renewer = SSLRenewer('/etc/letsencrypt/live', args.days_before_expiry, args.only_days, args.no_confirm)
    ssl_renewer.run()
