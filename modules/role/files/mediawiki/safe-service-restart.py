#!/usr/bin/env python3
"""
safe_service_restart.py

Safely restart systemd services (e.g., php-fpm, nginx) by temporarily depooling
a backend from multiple Varnish control servers, restarting services, and then
repooling them.

Each cache proxy (Varnish) is controlled via an API with optional TOTP
authentication for security.

Usage examples:
  Safe restart:  ./safe_service_restart.py --api http://cp171.fsslc.wtnet:5001 http://cp191.fsslc.wtnet:5001 \
                                           --services php-fpm --totp-secret ABCDEF123
  Depool only:   ./safe_service_restart.py --api http://cp171.fsslc.wtnet:5001 --depool --totp-code 123456
  Repool only:   ./safe_service_restart.py --api http://cp171.fsslc.wtnet:5001 --pool --totp-secret ABCDEF123
"""

import argparse
import logging
import shlex
import subprocess
import sys
import time
import requests
import pyotp
import re
import socket

logger = logging.getLogger("safe-service-restart")


class SafeServiceRestarter:
    DEFAULT_RC = 127

    def __init__(self, args):
        fqdn = socket.getfqdn()
        self.backend = fqdn.split(".")[0]
        self.fqdn = fqdn

        self.apis = [api.rstrip("/") for api in args.api]
        self.services = args.services or []
        self.retries = args.retries
        self.wait = args.wait
        self.timeout = args.timeout
        self.grace_period = args.grace_period
        self.force = args.force
        self.totp_secret = args.totp_secret
        self.totp_code = args.totp_code

        logger.info("Detected backend: %s (FQDN: %s)", self.backend, self.fqdn)
        logger.info("Target cache servers: %s", ", ".join(self.apis))

    def _get_totp_header(self):
        """Return authentication headers with either a provided code or generated TOTP"""
        if self.totp_code:
            code = self.totp_code
        elif self.totp_secret:
            code = pyotp.TOTP(self.totp_secret).now()
        else:
            raise RuntimeError("Must provide --totp-secret or --totp-code")
        return {"X-TOTP": code, "accept": "application/json"}

    def _valid_backend_name(self):
        """Ensure backend name is valid (mw + digits)"""
        return re.match(r"^mw\d+$", self.backend)

    def run(self):
        """Safe restart: depool → restart services → repool"""
        if not self._valid_backend_name():
            logger.error("Invalid backend name: %s", self.backend)
            return self.DEFAULT_RC

        if self.force:
            logger.info("Force mode: restarting services without depool/repool")
            return self._restart_services()

        logger.info("Depooling backend %s from all cache servers...", self.backend)
        if not self._set_backend("sick"):
            return self.DEFAULT_RC

        if self.grace_period > 0:
            logger.info("Waiting %d seconds before restarting...", self.grace_period)
            time.sleep(self.grace_period)

        logger.info("Restarting services: %s", ", ".join(self.services))
        rc = self._restart_services()
        if rc != 0:
            logger.warning("Service restart failed, NOT repooling")
            return rc

        logger.info("Repooling backend %s on all cache servers...", self.backend)
        if not self._set_backend("healthy"):
            return self.DEFAULT_RC

        return rc

    def run_depool(self):
        if not self._valid_backend_name():
            logger.error("Invalid backend name: %s", self.backend)
            return self.DEFAULT_RC
        logger.info("Depooling backend %s from all cache servers...", self.backend)
        return 0 if self._set_backend("sick") else self.DEFAULT_RC

    def run_pool(self):
        if not self._valid_backend_name():
            logger.error("Invalid backend name: %s", self.backend)
            return self.DEFAULT_RC
        logger.info("Repooling backend %s on all cache servers...", self.backend)
        return 0 if self._set_backend("healthy") else self.DEFAULT_RC

    def _restart_services(self):
        rc = 0
        for svc in self.services:
            cmd = ["systemctl", "restart", f"{svc}.service"]
            cmd_str = " ".join(map(shlex.quote, cmd))
            try:
                subprocess.check_call(cmd)
                logger.info("Service restarted: %s", svc)
                logger.debug("Executed command: %s", cmd_str)
            except subprocess.CalledProcessError as e:
                logger.error("Failed to restart service %s: %s", svc, e)
                rc = e.returncode
        return rc

    def _set_backend(self, state):
        """Call each varnish-control API to change backend state"""
        headers = self._get_totp_header()
        all_ok = True

        for api in self.apis:
            url = f"{api}/backend/{self.backend}/{state}"
            ok = False

            for attempt in range(1, self.retries + 1):
                try:
                    r = requests.post(url, headers=headers, timeout=self.timeout)
                    r.raise_for_status()
                    data = r.json()
                except Exception as e:
                    logger.warning("[%s] Attempt %d: API error: %s", api, attempt, e)
                    time.sleep(self.wait)
                    continue

                if data.get("status") == "ok":
                    logger.info("[%s] Backend %s set to %s", api, self.backend, state)
                    ok = True
                    break
                else:
                    logger.warning("[%s] Attempt %d: API error: %s", api, attempt, data)
                    time.sleep(self.wait)

            if not ok:
                all_ok = False
                logger.error("[%s] Failed to set backend %s to %s after %d attempts",
                             api, self.backend, state, self.retries)

        return all_ok


def parse_args():
    parser = argparse.ArgumentParser(
        description="Safely restart services by depooling/repooling from multiple Varnish cache servers."
    )
    parser.add_argument("--api", nargs="+", required=True,
                        help="One or more Varnish control API base URLs (e.g. http://cp171:5001 http://cp191:5001)")
    parser.add_argument("--services", nargs="+", metavar="SVC",
                        help="Systemd service(s) to restart")
    parser.add_argument("--retries", default=5, type=int, help="Number of times to retry API")
    parser.add_argument("--wait", default=3, type=int, help="Seconds to wait between retries")
    parser.add_argument("--timeout", default=5, type=int, help="Seconds to wait for API response")
    parser.add_argument("--grace-period", default=3, type=int, help="Seconds to wait after depool before restart")
    parser.add_argument("--force", action="store_true", default=False, help="Restart without depool/repool")
    parser.add_argument("--totp-secret", help="Shared TOTP secret (base32)")
    parser.add_argument("--totp-code", help="Pre-generated TOTP code")

    # Mutually exclusive actions (like Wikimedia's version)
    actions = parser.add_mutually_exclusive_group(required=True)
    actions.add_argument("--services", nargs="+", metavar="SVC",
                         help="Systemd service(s) to restart safely")
    actions.add_argument("--depool", action="store_true", help="Just depool backend")
    actions.add_argument("--pool", action="store_true", help="Just repool backend")
    return parser.parse_args()


def main():
    args = parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    sr = SafeServiceRestarter(args)

    if args.depool:
        return sr.run_depool()
    if args.pool:
        return sr.run_pool()
    return sr.run()


if __name__ == "__main__":
    sys.exit(main())
