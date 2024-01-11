#!/usr/bin/python3 -u

# Generate an SSL certificate with a CSR and private key.
#
# John Lewis
# Paladox

import argparse
import os
import string
import subprocess
import sys
import yaml

# Suppress ssl warnings (no checking ssl here since it won't be valid when generating the cert)
os.environ['PYTHONWARNINGS'] = 'ignore:Unverified HTTPS request'

# construct the argument parse and parse the arguments
ap = argparse.ArgumentParser(description='Script to generate LetsEncrypt certs or generate a CSR.')
ap.add_argument('-c', '--csr', required=False,
                action='store_true', default=False, help='generates a CSR')
ap.add_argument('-d', '--domain', required=True,
                help='name of the domain')
ap.add_argument('-g', '--generate', required=False,
                action='store_true', default=False, help='generates LetsEncrypt SSL Certificate')
ap.add_argument('--no-use-key', required=False,
                action='store_true', default=False, help='Creates a brand new private key along side a certificate.')
ap.add_argument('-o', '--overwrite', required=False,
                action='store_true', default=False, help='overwrites the certname replacing it with a updated version')
ap.add_argument('-p', '--private', required=False,
                action='store_true', default=False, help='automatically adds/updates private key in git')
ap.add_argument('-q', '--quiet', required=False,
                action='store_true', default=False, help='makes script quieter')
ap.add_argument('-r', '--renew', required=False,
                action='store_true', default=False, help='renews LetsEncrypt SSL Certificate')
ap.add_argument('--revoke', required=False,
                action='store_true', default=False, help='allows you to revoke certificates (also deletes them)')
ap.add_argument('-s', '--secondary', required=False,
                help='allows you to add other domains to the same cert, eg www.<domain>')
ap.add_argument('-v', '--version', action='version', version='%(prog)s 1.0')
ap.add_argument('-w', '--wildcard', required=False,
                action='store_true', default=False, help='auths against DNS supporting wildcards')
args = vars(ap.parse_args())


class SslCertificate:
    def __init__(self):
        self.csr = args['csr']
        if args['overwrite']:
            self.overwrite = '--cert-name ' + args['domain']
        else:
            self.overwrite = ''
        self.domain = args['domain']
        self.generate = args['generate']
        self.private = args['private']
        if args['quiet']:
            self.quiet = '-q'
        else:
            self.quiet = ''
        self.renew = args['renew']
        self.revoke = args['revoke']
        if args['secondary']:
            self.secondary_domain = ' -d ' + args['secondary']
        else:
            self.secondary_domain = ''
        self.wildcard = args['wildcard']
        self.no_existing_key = args['no_use_key']

    def on_init(self):
        if self.csr:
            self.generate_csr()
        elif self.generate and not self.renew:
            self.generate_letsencrypt_certificate()
        elif not self.generate and self.renew:
            self.renew_letsencrypt_certificate()
        elif self.revoke:
            self.revoke_letsencrypt_certificate()

    def generate_csr(self):
        if self.secondary_domain:
            secondary_domain = self.secondary_domain.replace(' -d ', ',DNS:')
        else:
            secondary_domain = self.secondary_domain

        # Generate the private key
        os.system(f'openssl genrsa 2048 > /root/ssl/{self.domain}.key')

        if not self.quiet:
            print(f'Private key generated at: /root/ssl/{self.domain}.key')

        # Generate the CSR
        subprocess.call([
            'bash',
            '-c',
            f'openssl req -new -sha256 -key /root/ssl/{self.domain}.key -subj \"/C=NL/ST=Netherlands/L=Netherlands/O=Miraheze/CN={self.domain}\" -reqexts SAN -config <(cat /etc/ssl/openssl.cnf <(printf \"[SAN]\nsubjectAltName=DNS:{self.domain}{secondary_domain}\")) > /root/ssl/{self.domain}.csr',
        ])

        if not self.quiet:
            print(f'CSR generated at: /root/ssl/{self.domain}.csr')

        if not self.quiet:
            print('Not generating an SSL certificate. Use CSR below to send to the requestor')

        os.system(f'/bin/cat /root/ssl/{self.domain}.csr')

    def generate_letsencrypt_certificate(self):
        if self.wildcard:
            if not self.quiet:
                print('Generating Wildcard SSL certificate with LetsEncrypt')

            if self.no_existing_key:
                out = os.system(f'/usr/bin/certbot --force-renewal --expand --no-verify-ssl certonly --manual --preferred-challenges dns-01 {self.overwrite} -d {self.domain} {self.secondary_domain}')
                if out != 0:
                    sys.exit("Error: Certbot failed (either the domain isn't pointed or we are being rate limited)")
            else:
                out = os.system(f'/usr/bin/certbot --force-renewal --reuse-key --expand --no-verify-ssl certonly --manual --preferred-challenges dns-01 {self.overwrite} -d {self.domain} {self.secondary_domain}')
                if out != 0:
                    sys.exit("Error: Certbot failed (either the domain isn't pointed or we are being rate limited)")

            if not self.quiet:
                print(f'LetsEncrypt certificate at: /etc/letsencrypt/live/{self.domain}/fullchain.pem')
        else:
            if not self.quiet:
                print('Generating SSL certificate with LetsEncrypt')

            if self.no_existing_key:
                out = os.system(f'/usr/bin/certbot {self.quiet} --noninteractive --force-renewal --expand --no-verify-ssl certonly -a webroot {self.overwrite} -d {self.domain} {self.secondary_domain}')
                if out != 0:
                    sys.exit("Error: Certbot failed (either the domain isn't pointed or we are being rate limited)")
            else:
                out = os.system(f'/usr/bin/certbot {self.quiet} --noninteractive --force-renewal --reuse-key --expand --no-verify-ssl certonly -a webroot {self.overwrite} -d {self.domain} {self.secondary_domain}')
                if out != 0:
                    sys.exit("Error: Certbot failed (either the domain isn't pointed or we are being rate limited)")

            if not self.quiet:
                print(f'LetsEncrypt certificate at: /etc/letsencrypt/live/{self.domain}/fullchain.pem')

        if not self.wildcard:
            if not self.quiet:
                print('Pushing LetsEncrypt SSL certificate to GitHub')

            os.system('git config --global core.sshCommand "ssh -i /var/lib/nagios/id_ed25519 -F /dev/null -o ProxyCommand=\'nc -6 -X connect -x bast.miraheze.org:8080 %h %p\'"')
            os.system('git -C /srv/ssl/ssl/ config user.name "MirahezeSSLBot"')
            os.system('git -C /srv/ssl/ssl/ config user.email "noreply@miraheze.org"')
            os.system('git -C /srv/ssl/ssl/ reset --hard origin/master')
            os.system('git -C /srv/ssl/ssl/ pull')
            os.system(f'cp /etc/letsencrypt/live/{self.domain}/fullchain.pem /srv/ssl/ssl/certificates/{self.domain}.crt')
            os.system(f'git -C /srv/ssl/ssl/ add /srv/ssl/ssl/certificates/{self.domain}.crt')

        file_path = '/srv/ssl/ssl/certs.yaml'

        with open(file_path, 'r') as certs_file:
            certs_data = yaml.safe_load(certs_file) or {}

        domain_key = self.domain.translate(str.maketrans('', '', string.punctuation))

        if domain_key not in certs_data:
            certs_data[domain_key] = {
                'url': self.domain,
                'ca': 'LetsEncrypt',
                'disable_event': False
            }

            with open(file_path, 'a') as certs_file:
                yaml.dump(certs_data, certs_file, default_flow_style=False)

            os.system('git -C /srv/ssl/ssl/ add /srv/ssl/ssl/certs.yaml')
            os.system(f'git -C /srv/ssl/ssl/ commit -m "Bot: Add SSL cert for {self.domain}" -m "Certificate committed by {os.getlogin()}"')
            os.system('git -C /srv/ssl/ssl/ push origin master')

        if self.private:
            print('Private key is being copied and pushed to /home/ssl-admins/ssl-keys')
            os.system(f'cp /etc/letsencrypt/live/{self.domain}/privkey.pem /home/ssl-admins/ssl-keys/{self.domain}.key')
            os.system(f"cd /home/ssl-admins/ssl-keys/ && git add . && git commit -m 'add {self.domain} key' && git push origin master")

    def renew_letsencrypt_certificate(self):
        self.newprivate = False
        if self.wildcard:
            if not self.quiet:
                print(f'Re-generating a new wildcard SSL cert for {self.domain}')

            if os.path.exists(f'/etc/letsencrypt/renewal/{self.domain}.conf'):
                if self.no_existing_key:
                    self.newprivate = True

                    os.system(f"/usr/bin/sed -i 's/reuse_key = True/reuse_key = False/g' /etc/letsencrypt/renewal/{self.domain}.conf")

                    os.system(f'/usr/bin/certbot --expand --no-verify-ssl certonly --manual --preferred-challenges dns-01 {self.overwrite} -d {self.domain} {self.secondary_domain}')

                    os.system(f"/usr/bin/sed -i 's/reuse_key = False/reuse_key = True/g' /etc/letsencrypt/renewal/{self.domain}.conf")
                else:
                    os.system(f'/usr/bin/certbot --reuse-key --expand --no-verify-ssl certonly --manual --preferred-challenges dns-01 {self.overwrite} -d {self.domain} {self.secondary_domain}')
            else:
                self.newprivate = True
                os.system(f'/usr/bin/certbot --force-renewal --reuse-key --expand --no-verify-ssl certonly --manual --preferred-challenges dns-01 {self.overwrite} -d {self.domain} {self.secondary_domain}')

            if not self.quiet:
                print(f'LetsEncrypt certificate at: /etc/letsencrypt/live/{self.domain}/fullchain.pem')
        else:
            if not self.quiet:
                print(f'Re-generating a new SSL cert for {self.domain}')

            if os.path.exists(f'/etc/letsencrypt/renewal/{self.domain}.conf'):
                if self.no_existing_key:
                    self.newprivate = True

                    os.system(f"/usr/bin/sed -i 's/reuse_key = True/reuse_key = False/g' /etc/letsencrypt/renewal/{self.domain}.conf")

                    os.system(f'/usr/bin/certbot --force-renewal --expand --no-verify-ssl {self.quiet} --noninteractive --no-random-sleep-on-renew renew --cert-name {self.domain}')

                    os.system(f"/usr/bin/sed -i 's/reuse_key = False/reuse_key = True/g' /etc/letsencrypt/renewal/{self.domain}.conf")
                else:
                    os.system(f'/usr/bin/certbot --force-renewal --reuse-key --expand --no-verify-ssl {self.quiet} --noninteractive --no-random-sleep-on-renew renew --cert-name {self.domain}')
            else:
                self.newprivate = True
                os.system(f'/usr/bin/certbot {self.quiet} --noninteractive --force-renewal --reuse-key --expand --no-verify-ssl certonly -a webroot {self.overwrite} -d {self.domain} {self.secondary_domain}')

            if not self.quiet:
                print(f'LetsEncrypt certificate at: /etc/letsencrypt/live/{self.domain}/fullchain.pem')

        if not self.quiet:
            print('Pushing LetsEncrypt SSL certificate to GitHub')

        os.system('git config --global core.sshCommand "ssh -i /var/lib/nagios/id_ed25519 -F /dev/null -o ProxyCommand=\'nc -6 -X connect -x bast.miraheze.org:8080 %h %p\'"')
        os.system('git -C /srv/ssl/ssl/ config user.name "MirahezeSSLBot"')
        os.system('git -C /srv/ssl/ssl/ config user.email "noreply@miraheze.org"')
        os.system('git -C /srv/ssl/ssl/ reset --hard origin/master')
        os.system('git -C /srv/ssl/ssl/ pull')
        os.system(f'cp /etc/letsencrypt/live/{self.domain}/fullchain.pem /srv/ssl/ssl/certificates/{self.domain}.crt')
        os.system(f'git -C /srv/ssl/ssl/ add /srv/ssl/ssl/certificates/{self.domain}.crt')
        os.system(f'git -C /srv/ssl/ssl/ commit -m "Bot: Update SSL cert for {self.domain}"')
        os.system('git -C /srv/ssl/ssl/ push origin master')

        if self.private and self.newprivate is True:
            print('New private key is being copied and pushed to /home/ssl-admins/ssl-keys')
            os.system(f'cp /etc/letsencrypt/live/{self.domain}/privkey.pem /home/ssl-admins/ssl-keys/{self.domain}.key')
            os.system(f"cd /home/ssl-admins/ssl-keys/ && git add . && git commit -m 'add {self.domain} key' && git push origin master")

    def revoke_letsencrypt_certificate(self):
        if not self.quiet:
            print(f'Revoking LetsEncrypt certificate at /etc/letsencrypt/live/{self.domain}')

        os.system(f'/usr/bin/certbot revoke --cert-path /etc/letsencrypt/live/{self.domain}/fullchain.pem')

        if not self.quiet:
            print(f'Deleting LetsEncrypt certificate at /etc/letsencrypt/live/{self.domain}')

        os.system(f'/usr/bin/certbot delete --cert-name {self.domain}')

        if not self.quiet:
            print('Removing key from private git')

        os.system(f'rm -rf /home/ssl-admins/ssl-keys/{self.domain}.key')
        os.system(f"cd /home/ssl-admins/ssl-keys/ && git add . && git commit -m 'remove {self.domain} key' && git push origin master")


cert = SslCertificate()
cert.on_init()
