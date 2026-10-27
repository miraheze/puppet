#!/usr/bin/env python3
"""
safe_service_restart.py

Safely restart systemd services (e.g., php-fpm, nginx) by temporarily depooling
a server from the HAProxy pools on multiple cache hosts, restarting services,
and then repooling it.

The pools on each cache host are controlled via an API protected by TOTP.

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
        self.server = fqdn.split(".")[0]
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

        logger.info("Detected server: %s (FQDN: %s)", self.server, self.fqdn)
        logger.info("Target cache hosts: %s", ", ".join(self.apis))

    def _get_totp_header(self):
        """Return authentication headers with either a provided code or generated TOTP"""
        if self.totp_code:
            code = self.totp_code
        elif self.totp_secret:
            code = pyotp.TOTP(self.totp_secret).now()
        else:
            raise RuntimeError("Must provide --totp-secret or --totp-code")
        return {"X-TOTP": code, "accept": "application/json"}

    def _valid_server_name(self):
        """Ensure server name is valid (letters + digits, e.g. mw151)"""
        return re.fullmatch(r"[a-z]+\d+", self.server)

    def run(self):
        """Safe restart: depool → restart services → repool"""
        if not self._valid_server_name():
            logger.error("Invalid server name: %s", self.server)
            return self.DEFAULT_RC

        if self.force:
            logger.info("Force mode: restarting services without depool/repool")
            return self._restart_services()

        logger.info("Depooling server %s from all cache hosts...", self.server)
        if not self._set_server("maint"):
            return self.DEFAULT_RC

        if self.grace_period > 0:
            logger.info("Waiting %d seconds before restarting...", self.grace_period)
            time.sleep(self.grace_period)

        logger.info("Restarting services: %s", ", ".join(self.services))
        rc = self._restart_services()
        if rc != 0:
            logger.warning("Service restart failed, NOT repooling")
            return rc

        logger.info("Repooling server %s on all cache hosts...", self.server)
        if not self._set_server("ready"):
            return self.DEFAULT_RC

        return rc

    def run_depool(self):
        if not self._valid_server_name():
            logger.error("Invalid server name: %s", self.server)
            return self.DEFAULT_RC
        logger.info("Depooling server %s from all cache hosts...", self.server)
        return 0 if self._set_server("maint") else self.DEFAULT_RC

    def run_pool(self):
        if not self._valid_server_name():
            logger.error("Invalid server name: %s", self.server)
            return self.DEFAULT_RC
        logger.info("Repooling server %s on all cache hosts...", self.server)
        return 0 if self._set_server("ready") else self.DEFAULT_RC

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

    def _set_server(self, state):
        """Call the API of each cache host to change the server state"""
        headers = self._get_totp_header()
        all_ok = True

        for api in self.apis:
            url = f"{api}/server/{self.server}/{state}"
            ok = False

            for attempt in range(1, self.retries + 1):
                try:
                    r = requests.post(url, headers=headers, timeout=self.timeout)
                    data = r.json()
                except Exception as e:
                    logger.warning("[%s] Attempt %d: API error: %s", api, attempt, e)
                    time.sleep(self.wait)
                    continue

                if r.status_code == 404 and data.get("error") == "unknown server":
                    # Not in any pool on this host, nothing to change
                    logger.info("[%s] Server %s is not in a pool, skipping", api, self.server)
                    ok = True
                    break

                if r.ok and data.get("status") == "ok":
                    logger.info("[%s] Server %s set to %s", api, self.server, state)
                    ok = True
                    break

                logger.warning("[%s] Attempt %d: API error: %s", api, attempt, data)
                time.sleep(self.wait)

            if not ok:
                all_ok = False
                logger.error("[%s] Failed to set server %s to %s after %d attempts",
                             api, self.server, state, self.retries)

        return all_ok


def parse_args():
    parser = argparse.ArgumentParser(
        description="Safely restart services by depooling/repooling from the pools on multiple cache hosts."
    )
    parser.add_argument("--api", nargs="+", required=True,
                        help="One or more cache host API base URLs (e.g. http://cp171:5001 http://cp191:5001)")
    parser.add_argument("--retries", default=5, type=int, help="Number of times to retry API")
    parser.add_argument("--wait", default=3, type=int, help="Seconds to wait between retries")
    parser.add_argument("--timeout", default=5, type=int, help="Seconds to wait for API response")
    parser.add_argument("--grace-period", default=3, type=int, help="Seconds to wait after depool before restart")
    parser.add_argument("--force", action="store_true", default=False, help="Restart without depool/repool")
    parser.add_argument("--totp-secret", help="Shared TOTP secret (base32)")
    parser.add_argument("--totp-code", help="Pre-generated TOTP code")

    # Mutually exclusive actions
    actions = parser.add_mutually_exclusive_group(required=True)
    actions.add_argument(
        "--services", nargs="+", metavar="SVC", help="Systemd service to restart"
    )
    actions.add_argument(
        "--pool",
        action="store_true",
        default=False,
        help="Just repool server",
    )
    actions.add_argument(
        "--depool",
        action="store_true",
        default=False,
        help="Just depool server",
    )
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
