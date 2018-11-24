#!/usr/bin/python3 -u

# Generate an SSL certificate (LetsEncrypt) with a CSR and private key.
#
# John Lewis
# Paladox

import argparse
import os
 
# construct the argument parse and parse the arguments
ap = argparse.ArgumentParser(description="Script to generate LetsEncrypt certs or generate a CSR.")
ap.add_argument("-c", "--csr", required=False,
    help="generates a CSR")
ap.add_argument("-d", "--domain", required=True,
    help="name of the domain")
ap.add_argument("-g", "--generate", required=False,
    action="store_true", default=False, help="generates LetsEncrypt SSL Certificate")
ap.add_argument("-r", "--renew", required=False,
    action="store_true", default=False, help="renews LetsEncrypt SSL Certificate")
ap.add_argument("-s", "--secondary", required=False,
    help="allows you to add other domains to the same cert, eg www.<domain>")
ap.add_argument("-w", "--wildcard", required=False,
    action="store_true", default=False, help="auths against DNS supporting wildcards")
args = vars(ap.parse_args())

domain = args['domain']

if args['secondary']:
    secondary_domain = " -d " +  args['secondary']
else:
    secondary_domain = ""

if args["csr"]:
    secondary_domain = secondary_domain.replace(" -d ", "")

    # Generate the private key
    os.system("openssl genrsa 2048 > /root/ssl/{}.key".format(domain))
    print("Private key generated at: /root/ssl/{}.key".format(domain))

    # Generate the CSR
    os.system("openssl req -new -sha256 -key /root/ssl/{0}.key -subj \"/C=NL/ST=Netherlands/L=Netherlands/O=Miraheze/CN={0}\" -reqexts SAN -config <(cat /etc/ssl/openssl.cnf <(printf \"[SAN]\nsubjectAltName=DNS:{0}{1}\")) > /root/ssl/{0}.csr".format(domain, secondary_domain))
    print("CSR generated at: /root/ssl/{0}.csr".format(domain))

    print("Not generating an SSL certificate. Use CSR below to send to the requestor")
    os.system("cat /root/ssl/{0}.csr".format(domain))

if args["generate"] and not args["renew"]:
    if args["wildcard"]:
        print("Generating Wildcard SSL certificate with LetsEncrypt")
        os.system("/usr/bin/certbot certonly --manual --preferred-challenges dns-01 -d {0} {1} --no-verify-ssl".format(domain, secondary_domain))
        print("LetsEncrypt certificate at: /etc/letsencrypt/live/{0}/fullchain.pem".format(domain))
    else:
        print("Generating SSL certificate with LetsEncrypt")
        os.system("/usr/bin/certbot -q --noninteractive certonly -a webroot -d {0} {1} --no-verify-ssl".format(domain, secondary_domain))
        print("LetsEncrypt certificate at: /etc/letsencrypt/live/{0}/fullchain.pem".format(domain))
    os.system("cat /etc/letsencrypt/live/{0}/fullchain.pem".format(domain))
elif not args["generate"] and args["renew"]:
    # note that if you do *.domain.org then the cert name is domain.org
    print("Re-generating a new SSL cert for {0}".format(domain))
    if args["wildcard"]:
        os.system("/usr/bin/certbot renew --cert-name {0} --no-verify-ssl --force-renewal --expand".format(domain))
    else:
        os.system("/usr/bin/certbot -q --noninteractive renew --cert-name {0} --no-verify-ssl --force-renewal --expand".format(domain))
    print("LetsEncrypt certificate at: /etc/letsencrypt/live/{0}/fullchain.pem".format(domain))
    os.system("cat /etc/letsencrypt/live/{0}/fullchain.pem".format(domain))
