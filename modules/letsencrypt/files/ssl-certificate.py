#!/usr/bin/python3 -u

# Generates an SSL certificate (LetsEncrypt) (or a CSR) and private key.
#
# John Lewis
# Paladox

import argparse
import os
import subprocess

class SslCertificate:
    def __init__(self, args):
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
            self.secondary_domain = " -d " +  args['secondary']
        else:
            self.secondary_domain = ""

        self.wildcard = args['wildcard']

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

        self.log("Private key generated at: /root/ssl/{0}.key".format(self.domain))

        # Generate the CSR
        subprocess.call([
            'bash',
            '-c',
            'openssl req -new -sha256 -key /root/ssl/{0}.key -subj \"/C=NL/ST=Netherlands/L=Netherlands/O=Miraheze/CN={0}\" -reqexts SAN -config <(cat /etc/ssl/openssl.cnf <(printf \"[SAN]\nsubjectAltName=DNS:{0}{1}\")) > /root/ssl/{0}.csr'
            .format(self.domain, secondary_domain),
        ])

        self.log("CSR generated at: /root/ssl/{0}.csr".format(self.domain))

        self.log("Not generating an SSL certificate. Use CSR below to send to the requestor")

        os.system("/bin/cat /root/ssl/{0}.csr".format(self.domain))

    def generate_letsencrypt_certificate(self):
        if self.wildcard:
            self.log("Generating Wildcard SSL certificate with LetsEncrypt")

            os.system(
                "/usr/bin/certbot --force-renewal --reuse-key --expand  --no-verify-ssl certonly --manual --preferred-challenges dns-01 {2} -d {0} {1}"
                .format(self.domain, self.secondary_domain, self.overwrite))

            self.log("LetsEncrypt certificate at: /etc/letsencrypt/live/{0}/fullchain.pem".format(self.domain))
        else:
            self.log("Generating SSL certificate with LetsEncrypt")

            os.system(
                "/usr/bin/certbot {1} --noninteractive --force-renewal --reuse-key --expand  --no-verify-ssl certonly -a webroot {3} -d {0} {2}"
                .format(self.domain, self.quiet, self.secondary_domain, self.overwrite))

            self.log("LetsEncrypt certificate at: /etc/letsencrypt/live/{0}/fullchain.pem".format(self.domain))

        os.system("/bin/cat /etc/letsencrypt/live/{0}/fullchain.pem".format(self.domain))

        if self.private:
            os.system("/bin/cat /etc/letsencrypt/live/{0}/privkey.pem".format(self.domain))

    def renew_letsencrypt_certificate(self):
        if self.wildcard:
            self.log("Re-generating a new wildcard SSL cert for {0}".format(self.domain))

            os.system(
                "/usr/bin/certbot --no-verify-ssl --reuse-key --expand  --no-verify-ssl certonly --manual --preferred-challenges dns-01 {2} -d {0} {1}"
                .format(self.domain, self.secondary_domain, self.overwrite))

            self.log("LetsEncrypt certificate at: /etc/letsencrypt/live/{0}/fullchain.pem".format(self.domain))
        else:
            self.log("Re-generating a new SSL cert for {0}".format(self.domain))

            os.system(
                "/usr/bin/certbot --force-renewal --reuse-key --expand  --no-verify-ssl {1} --noninteractive renew --cert-name {0}"
                .format(self.domain, self.quiet))

            self.log("LetsEncrypt certificate at: /etc/letsencrypt/live/{0}/fullchain.pem".format(self.domain))

        os.system("/bin/cat /etc/letsencrypt/live/{0}/fullchain.pem".format(self.domain))

        if self.private:
            os.system("/bin/cat /etc/letsencrypt/live/{0}/privkey.pem".format(self.domain))

    def revoke_letsencrypt_certificate(self):
        self.log("Revoking LetsEncrypt certificate at /etc/letsencrypt/live/{0}".format(self.domain))

        os.system("/usr/bin/certbot revoke --cert-path /etc/letsencrypt/live/{0}/fullchain.pem".format(self.domain))

        self.log("Deleting LetsEncrypt certificate at /etc/letsencrypt/live/{0}".format(self.domain))

        os.system("/usr/bin/certbot delete --cert-name {0}".format(self.domain))

    def log(self, message):
        if not self.quiet:
            print(message)


ap = argparse.ArgumentParser(description="Script to generate LetsEncrypt certificates or to generate a CSR.")

ap.add_argument("-c", "--csr", required=False,
    action="store_true", default=False, help="generates a CSR")

ap.add_argument("-d", "--domain", required=True,
    help="name of the domain")

ap.add_argument("-g", "--generate", required=False,
    action="store_true", default=False, help="generates LetsEncrypt SSL Certificate")

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

ap.add_argument("-v", "--version", action="version", version="%(prog)s 1.1")

ap.add_argument("-w", "--wildcard", required=False,
    action="store_true", default=False, help="auths against DNS supporting wildcards")

args = vars(ap.parse_args())

cert = SslCertificate(args)
cert.on_init()
