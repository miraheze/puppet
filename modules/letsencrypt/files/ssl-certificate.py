#!/usr/bin/python3 -u

# Generate an SSL certificate (LetsEncrypt) with a CSR and private key.
#
# John Lewis
# Paladox

import argparse
import os
import subprocess

# construct the argument parse and parse the arguments
ap = argparse.ArgumentParser(description="Script to generate LetsEncrypt certs or generate a CSR.")
ap.add_argument("-c", "--csr", required=False,
               action="store_true", default=False, help="generates a CSR")
ap.add_argument("-d", "--domain", required=True,
               help="name of the domain")
ap.add_argument("-g", "--generate", required=False,
               action="store_true", default=False, help="generates LetsEncrypt SSL Certificate")
ap.add_argument("--no-use-key", required=False,
               action="store_true", default=False, help="Creates a brand new private key along side a certificate.")
ap.add_argument("-o", "--overwrite", required=False,
               action="store_true", default=False, help="overwrites the certname replacing it with a updated version")
ap.add_argument("-p", "--private", required=False,
               action="store_true", default=False, help="outputs private key")
ap.add_argument("-q", "--quiet", required=False,
               action="store_true", default=False, help="makes script quieter")
ap.add_argument("-r", "--renew", required=False,
               action="store_true", default=False, help="renews LetsEncrypt SSL Certificate")
ap.add_argument("--revoke", required=False,
               action="store_true", default=False, help="allows you to revoke certificates (also deletes them)")
ap.add_argument("-s", "--secondary", required=False,
               help="allows you to add other domains to the same cert, eg www.<domain>")
ap.add_argument("-v", "--version", action="version", version="%(prog)s 1.0")
ap.add_argument("-w", "--wildcard", required=False,
               action="store_true", default=False, help="auths against DNS supporting wildcards")
args = vars(ap.parse_args())


class SslCertificate:
    def __init__(self):
        self.csr = args['csr']
        if args['overwrite']:
            self.overwrite = "--cert-name {0}".format(args['domain'])
        else:
            self.overwrite = ""
        self.domain = args['domain']
        self.generate = args['generate']
        self.private = args['private']
        if args['quiet']:
            self.quiet = "-q"
        else:
            self.quiet = ""
        self.renew = args['renew']
        self.revoke = args['revoke']
        if args['secondary']:
            self.secondary_domain = " -d " + args['secondary']
        else:
            self.secondary_domain = ""
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
            secondary_domain = self.secondary_domain.replace(" -d ", ",DNS:")
        else:
            secondary_domain = self.secondary_domain

        # Generate the private key
        os.system("openssl genrsa 2048 > /root/ssl/{0}.key".format(self.domain))

        if not self.quiet:
            print("Private key generated at: /root/ssl/{0}.key".format(self.domain))

        # Generate the CSR
        subprocess.call([
            'bash',
            '-c',
            'openssl req -new -sha256 -key /root/ssl/{0}.key -subj \"/C=NL/ST=Netherlands/L=Netherlands/O=Miraheze/CN={0}\" -reqexts SAN -config <(cat /etc/ssl/openssl.cnf <(printf \"[SAN]\nsubjectAltName=DNS:{0}{1}\")) > /root/ssl/{0}.csr'.format(self.domain, secondary_domain),
        ])

        if not self.quiet:
            print("CSR generated at: /root/ssl/{0}.csr".format(self.domain))

        if not self.quiet:
            print("Not generating an SSL certificate. Use CSR below to send to the requestor")

        os.system("/bin/cat /root/ssl/{0}.csr".format(self.domain))

    def generate_letsencrypt_certificate(self):
        if self.wildcard:
            if not self.quiet:
                print("Generating Wildcard SSL certificate with LetsEncrypt")

            if self.no_existing_key:
                os.system("/usr/bin/certbot --force-renewal --expand  --no-verify-ssl certonly --manual --preferred-challenges dns-01 {2} -d {0} {1}".format(self.domain, self.secondary_domain, self.overwrite))
            else:
                os.system("/usr/bin/certbot --force-renewal --reuse-key --expand  --no-verify-ssl certonly --manual --preferred-challenges dns-01 {2} -d {0} {1}".format(self.domain, self.secondary_domain, self.overwrite))

            if not self.quiet:
                print("LetsEncrypt certificate at: /etc/letsencrypt/live/{0}/fullchain.pem".format(self.domain))
        else:
            if not self.quiet:
                print("Generating SSL certificate with LetsEncrypt")

            if self.no_existing_key:
                os.system("/usr/bin/certbot {1} --noninteractive --force-renewal --expand  --no-verify-ssl certonly -a webroot {3} -d {0} {2}".format(self.domain, self.quiet, self.secondary_domain, self.overwrite))
            else:
                os.system("/usr/bin/certbot {1} --noninteractive --force-renewal --reuse-key --expand  --no-verify-ssl certonly -a webroot {3} -d {0} {2}".format(self.domain, self.quiet, self.secondary_domain, self.overwrite))

            if not self.quiet:
                print("LetsEncrypt certificate at: /etc/letsencrypt/live/{0}/fullchain.pem".format(self.domain))

        os.system("/bin/cat /etc/letsencrypt/live/{0}/fullchain.pem".format(self.domain))

        if self.private:
            os.system("/bin/cat /etc/letsencrypt/live/{0}/privkey.pem".format(self.domain))

    def renew_letsencrypt_certificate(self):
        if self.wildcard:
            if not self.quiet:
                print("Re-generating a new wildcard SSL cert for {0}".format(self.domain))

            if self.no_existing_key:
                os.system("/usr/bin/sed -i 's/reuse_key = True/reuse_key = False/g' /etc/letsencrypt/renewal/{0}.conf".format(self.domain))

                os.system("/usr/bin/certbot --no-verify-ssl --expand  --no-verify-ssl certonly --manual --preferred-challenges dns-01 {2} -d {0} {1}".format(self.domain, self.secondary_domain, self.overwrite))

                os.system("/usr/bin/sed -i 's/reuse_key = False/reuse_key = True/g' /etc/letsencrypt/renewal/{0}.conf".format(self.domain))
            else:
                os.system("/usr/bin/certbot --no-verify-ssl --reuse-key --expand  --no-verify-ssl certonly --manual --preferred-challenges dns-01 {2} -d {0} {1}".format(self.domain, self.secondary_domain, self.overwrite))

            if not self.quiet:
                print("LetsEncrypt certificate at: /etc/letsencrypt/live/{0}/fullchain.pem".format(self.domain))
        else:
            if not self.quiet:
                print("Re-generating a new SSL cert for {0}".format(self.domain))

            if self.no_existing_key:
                os.system("/usr/bin/sed -i 's/reuse_key = True/reuse_key = False/g' /etc/letsencrypt/renewal/{0}.conf".format(self.domain))

                os.system("/usr/bin/certbot --force-renewal --expand  --no-verify-ssl {1} --noninteractive renew --cert-name {0}".format(self.domain, self.quiet))

                os.system("/usr/bin/sed -i 's/reuse_key = False/reuse_key = True/g' /etc/letsencrypt/renewal/{0}.conf".format(self.domain))
            else:
                os.system("/usr/bin/certbot --force-renewal --reuse-key --expand  --no-verify-ssl {1} --noninteractive renew --cert-name {0}".format(self.domain, self.quiet))

            if not self.quiet:
                print("LetsEncrypt certificate at: /etc/letsencrypt/live/{0}/fullchain.pem".format(self.domain))

        os.system("/bin/cat /etc/letsencrypt/live/{0}/fullchain.pem".format(self.domain))

        if self.private:
            os.system("/bin/cat /etc/letsencrypt/live/{0}/privkey.pem".format(self.domain))

    def revoke_letsencrypt_certificate(self):
        if not self.quiet:
            print("Revoking LetsEncrypt certificate at /etc/letsencrypt/live/{0}".format(self.domain))

        os.system("/usr/bin/certbot revoke --cert-path /etc/letsencrypt/live/{0}/fullchain.pem".format(self.domain))

        if not self.quiet:
            print("Deleting LetsEncrypt certificate at /etc/letsencrypt/live/{0}".format(self.domain))

        os.system("/usr/bin/certbot delete --cert-name {0}".format(self.domain))


cert = SslCertificate()
cert.on_init()
