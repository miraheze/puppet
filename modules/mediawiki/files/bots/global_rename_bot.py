#!/usr/bin/env python3
"""
Miraheze global rename bot. Runs once; use cron for scheduling.

Skips (never declines) requests where:
  - CentralAuth reports the username is too similar to an existing one
  - CentralAuth reports a previous rename within the past year
  - The new username violates the Username Policy
"""

import argparse
import json
import logging
import re
import sys
from pathlib import Path

import requests
from bs4 import BeautifulSoup

from policy_checker import PolicyChecker

BASE_URL = "https://meta.miraheze.org"
API_URL  = f"{BASE_URL}/w/api.php"

HUMAN_REVIEW_PHRASES = (
    "the chosen username is too similar to",
    "previous rename",
)

COOKIE_FRAGMENTS = (
    "cookies help us",
    "by using our services",
    "we use cookies",
)


class RenameBot:
    def __init__(self, config: dict, dry_run: bool = False):
        self.cfg     = config
        self.dry_run = dry_run
        self.policy  = PolicyChecker(extra_blocked=config.get("extra_blocked_terms", []))
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": (
                f"MirahezeRenameBot/2.2 "
                f"(+{config.get('bot_contact', 'https://meta.miraheze.org')}; "
                "bot; python-requests)"
            )
        })

    def login(self):
        log = logging.getLogger("rename_bot")
        log.info("Logging in as %s ...", self.cfg["username"])

        r = self.session.get(API_URL, params={
            "action": "query",
            "meta": "tokens",
            "type": "login",
            "format": "json",
        })
        r.raise_for_status()

        token = r.json()["query"]["tokens"]["logintoken"]

        r = self.session.post(API_URL, data={
            "action": "login",
            "lgname": self.cfg["username"],
            "lgpassword": self.cfg["password"],
            "lgtoken": token,
            "format": "json",
        })
        r.raise_for_status()

        result = r.json().get("login", {})

        if result.get("result") != "Success":
            raise RuntimeError(f"Login failed: {result}")

        log.info("Logged in successfully.")

    def get_pending_renames(self) -> list[dict]:
        log = logging.getLogger("rename_bot")

        r = self.session.get(f"{BASE_URL}/wiki/Special:GlobalRenameQueue/open")
        r.raise_for_status()

        soup  = BeautifulSoup(r.text, "html.parser")
        seen  = set()
        items = []

        for a in soup.find_all("a", href=True):
            m = re.search(r"[Gg]lobalRenameQueue/request/(\d+)", a["href"])

            if m:
                rid = m.group(1)

                if rid not in seen:
                    seen.add(rid)
                    items.append({
                        "id": rid,
                        "old_name": "",
                        "new_name": "",
                    })

        log.info("Found %d pending request(s).", len(items))
        return items

    def fetch_request_details(self, entry: dict) -> dict:
        log = logging.getLogger("rename_bot")

        rid = entry["id"]

        r = self.session.get(
            f"{BASE_URL}/wiki/Special:GlobalRenameQueue/request/{rid}"
        )
        r.raise_for_status()

        soup = BeautifulSoup(r.text, "html.parser")

        old_name  = entry["old_name"]
        new_name  = entry["new_name"]
        page_text = soup.get_text(separator=" ")

        m = re.search(
            r"(\S+)\s+is requesting a rename to\s+(\S+)",
            page_text,
            re.IGNORECASE,
        )

        if m:
            old_name = old_name or m.group(1).strip(" .")
            new_name = new_name or m.group(2).strip(" .")

        for li in soup.find_all("li"):
            txt = li.get_text(separator=" ", strip=True)
            tl  = txt.lower()

            if not old_name and tl.startswith("current username"):
                old_name = txt.split(":", 1)[-1].strip()

            elif not new_name and tl.startswith("new username"):
                new_name = txt.split(":", 1)[-1].strip()

        for dt in soup.find_all(["dt", "th"]):
            label  = dt.get_text(strip=True).lower()
            val_el = dt.find_next_sibling(["dd", "td"])

            if not val_el:
                continue

            val = val_el.get_text(strip=True)

            if not val:
                continue

            if not old_name and any(k in label for k in ("current", "rename from")):
                old_name = val

            elif not new_name and any(k in label for k in ("new", "rename to", "requested")):
                new_name = val

        if not old_name:
            m2 = re.search(r'Rename\s+"([^"]+)"', page_text)

            if m2:
                old_name = m2.group(1)

        entry["old_name"] = old_name
        entry["new_name"] = new_name

        warnings: list[str] = []
        seen_txt: set[str]  = set()

        def add_warning(txt):
            txt = txt.strip()

            if not txt or txt in seen_txt:
                return

            if any(f in txt.lower() for f in COOKIE_FRAGMENTS):
                return

            seen_txt.add(txt)
            warnings.append(txt)

        for fs in soup.find_all("fieldset"):
            legend = fs.find("legend")

            if legend:
                add_warning(legend.get_text(strip=True))

            add_warning(fs.get_text(separator=" ", strip=True))

        for sel in (
            ".mw-message-box-warning",
            ".mw-message-box-error",
            ".mw-message-box",
        ):
            for el in soup.select(sel):
                add_warning(el.get_text(separator=" ", strip=True))

        entry["warnings"] = warnings
        entry["soup"]     = soup

        if warnings:
            log.debug("Warnings on #%s: %s", rid, warnings)

        return entry

    def _should_skip(self, entry: dict) -> tuple[bool, str]:
        for text in entry.get("warnings", []):
            tl = text.lower()

            for phrase in HUMAN_REVIEW_PHRASES:
                if phrase in tl:
                    return True, f"CentralAuth warning: {text[:200]}"

        new_name = entry.get("new_name", "")

        if not new_name:
            return True, "Could not determine the requested new username."

        ok, reason = self.policy.check(new_name)

        if not ok:
            return True, f"Username Policy: {reason}"

        return False, ""

    def _approve(self, entry: dict) -> bool:
        log      = logging.getLogger("rename_bot")
        rid      = entry["id"]
        old_name = entry.get("old_name", "?")
        new_name = entry.get("new_name", "?")
        soup     = entry.get("soup")

        if self.dry_run:
            log.info(
                "[DRY-RUN] Would approve #%s: '%s' -> '%s'",
                rid,
                old_name,
                new_name,
            )
            return True

        ACCEPT_NAMES = {"wpaccept", "wpapprove", "approve"}
        ACCEPT_TEXT  = {"accept rename", "approve", "accept"}

        REJECT_NAMES = {"wpreject", "wpdecline", "reject", "decline"}
        REJECT_TEXT  = {"reject rename", "reject", "decline", "deny"}

        def is_approval_form(f):
            action = (f.get("action") or "").lower()

            if "request" in action or "renamequeue" in action:
                return True

            for el in f.find_all(["input", "button"]):
                n = (el.get("name") or "").lower()
                v = (el.get("value") or el.get_text(strip=True) or "").lower()

                if (
                    n in ACCEPT_NAMES
                    or v in ACCEPT_TEXT
                    or n in REJECT_NAMES
                    or v in REJECT_TEXT
                ):
                    return True

            return False

        form = None

        for candidate in soup.find_all("form"):
            if is_approval_form(candidate):
                form = candidate

        if not form:
            log.error("No approval form found for #%s.", rid)
            return False

        fields: dict[str, str] = {}

        # Existing form inputs
        for inp in form.find_all("input"):
            name  = inp.get("name")
            itype = (inp.get("type") or "text").lower()

            if not name or itype == "submit":
                continue

            if itype in ("radio", "checkbox") and not inp.get("checked"):
                continue

            fields[name] = inp.get("value", "")

        # Existing textarea values
        for ta in form.find_all("textarea"):
            name = ta.get("name")

            if name:
                fields[name] = ta.get_text(strip=True)

        APPROVAL_REASON = (
    f"[[Special:GlobalRenameQueue/request/{rid}|Request]] approved."
)

        APPROVAL_COMMENT = (
            "Automatically approved. Please read [[Changing username]] if you ever "
            "wish to change your username again in the future. "
            "Please note we generally do not accept renames before the "
            "12-24 month mark unless a compelling reason is provided. "
            "Thank you for choosing Miraheze!"
        )

        # Dynamically detect reason/comment fields
        for field_name in list(fields.keys()):
            lower = field_name.lower()

            if "reason" in lower:
                fields[field_name] = APPROVAL_REASON

            elif any(x in lower for x in ("comment", "comments", "note")):
                fields[field_name] = APPROVAL_COMMENT

        # Fallbacks
        fields.setdefault("wpReason", APPROVAL_REASON)
        fields.setdefault("wpComments", APPROVAL_COMMENT)

        approve_btn = None

        for el in form.find_all(["input", "button"]):
            el_type = (el.get("type") or "submit").lower()

            if el_type not in ("submit", "button"):
                continue

            n = (el.get("name") or "").lower()
            v = (el.get("value") or el.get_text(strip=True) or "").lower()

            if n in ACCEPT_NAMES or v in ACCEPT_TEXT:
                approve_btn = el
                break

        if approve_btn:
            bname = approve_btn.get("name", "")
            bval  = (
                approve_btn.get("value")
                or approve_btn.get_text(strip=True)
                or "1"
            )

            if bname:
                fields[bname] = bval

            for el in form.find_all(["input", "button"]):
                elname = (el.get("name") or "").lower()
                elval  = (
                    el.get("value")
                    or el.get_text(strip=True)
                    or ""
                ).lower()

                if elname in REJECT_NAMES or elval in REJECT_TEXT:
                    fields.pop(el.get("name", ""), None)

        else:
            fields["wpAction"]  = "approve"
            fields["wpApprove"] = "1"

        action = form.get("action", "")

        if action and not action.startswith("http"):
            action = BASE_URL + action

        if not action:
            action = (
                f"{BASE_URL}/wiki/"
                f"Special:GlobalRenameQueue/request/{rid}"
            )

        log.debug("Submitting approval fields: %s", fields)

        r = self.session.post(action, data=fields)
        r.raise_for_status()

        page_text = BeautifulSoup(
            r.text,
            "html.parser",
        ).get_text().lower()

        if any(s in page_text for s in (
            "approved",
            "has been approved",
            "rename-queue-status-approved",
        )):
            log.info(
                "✓ Approved #%s: '%s' -> '%s'",
                rid,
                old_name,
                new_name,
            )
            return True

        log.warning(
            "Approval result for #%s unclear. Snippet:\n%s",
            rid,
            page_text[:500],
        )

        return False

    def run(self):
        log = logging.getLogger("rename_bot")

        self.login()

        entries = self.get_pending_renames()

        if not entries:
            log.info("Queue is empty.")
            return

        for entry in entries:
            log.info("Request #%s", entry["id"])

            try:
                entry = self.fetch_request_details(entry)

            except Exception as exc:
                log.error(
                    "Could not fetch #%s: %s",
                    entry["id"],
                    exc,
                )
                continue

            log.info(
                "  '%s' -> '%s'",
                entry.get("old_name") or "?",
                entry.get("new_name") or "?",
            )

            skip, reason = self._should_skip(entry)

            if skip:
                log.warning(
                    "  Skipping (human review needed): %s",
                    reason,
                )
                continue

            if not self._approve(entry):
                log.error(
                    "  Approval failed for #%s.",
                    entry["id"],
                )


def load_config(path: str) -> dict:
    p = Path(path)

    if not p.exists():
        print(f"Config file '{path}' not found.", file=sys.stderr)
        sys.exit(1)

    with p.open(encoding="utf-8") as f:
        config = json.load(f)

    pw_path = Path(config["password_file"])

    if not pw_path.exists():
        print(f"Password file '{pw_path}' not found.", file=sys.stderr)
        sys.exit(1)

    config["password"] = (
        pw_path.read_text(encoding="utf-8").strip()
    )

    return config


def main():
    parser = argparse.ArgumentParser(
        description="Miraheze global rename bot"
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
    )

    parser.add_argument(
        "--config",
        default="config.json",
    )

    parser.add_argument(
        "--debug",
        action="store_true",
    )

    args = parser.parse_args()

    config = load_config(args.config)

    log_file = config.get(
        "log_file",
        "rename_bot.log",
    )

    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.FileHandler(
                log_file,
                encoding="utf-8",
            ),
            logging.StreamHandler(sys.stdout),
        ],
    )

    bot = RenameBot(
        config,
        dry_run=args.dry_run,
    )

    if args.dry_run:
        logging.getLogger("rename_bot").info(
            "Dry-run mode, no approvals will be submitted."
        )

    bot.run()


if __name__ == "__main__":
    main()
