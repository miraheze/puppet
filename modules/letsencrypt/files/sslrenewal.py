#!/usr/bin/python3 -u

# Script that renews a ssl certificate and updates miraheze/ssl.git
#
# Miraheze Staff 2019

import argparse
import os
import subprocess

class SslRenewal:
    def __init__(self, args):
        self.domain = args['domain']

        self.state = args['state']

        self.type = args['type']

    def renew_certificate(self):
        if self.state == "WARNING" and self.type == "HARD":
            os.system("cd /mnt/mediawiki-static/private/miraheze/ssl/ && git reset --hard origin/master && git pull")

            if os.path.isfile("/etc/letsencrypt/live/{0}/fullchain.pem".format(self.domain)):
                os.system(
                    "sudo /root/ssl-certificate -d {0} -q -r > /mnt/mediawiki-static/private/miraheze/ssl/certificates/{0}.crt"
                    .format(self.domain))

                os.system(
                    "git -C /mnt/mediawiki-static/private/miraheze/ssl/ add /mnt/mediawiki-static/private/miraheze/ssl/certificates/{0}.crt"
                    .format(self.domain))

                os.system(
                    "git -C /mnt/mediawiki-static/private/miraheze/ssl commit -m \"Bot: Update SSL cert for {0}\""
                    .format(self.domain))

                os.system("git -C /mnt/mediawiki-static/private/miraheze/ssl/ push origin master")


ap = argparse.ArgumentParser(description="Script to renew a ssl certificate and upload it to a git repo")

ap.add_argument("-d", "--domain", required=True,
    help="name of the domain")

ap.add_argument("-s", "--state", required=True,
    help="the service state, E.G WARNING")

ap.add_argument("-t", "--type", required=True,
    help="the service type, E.G SOFT or HARD")

ap.add_argument("-v", "--version", action="version", version="%(prog)s 1.0")

args = vars(ap.parse_args())

cert = SslRenewal(args)
cert.renew_certificate()
