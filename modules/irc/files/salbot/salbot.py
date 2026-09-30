#!/usr/bin/env python3
# Created by Universal Omega for T14689

import argparse
import asyncio
import base64
import fnmatch
import http.client
import ipaddress
import json
import logging
import os
import re
import socket
import ssl
import sys
import time
import urllib.parse
from collections import deque
from datetime import datetime, timezone

log = logging.getLogger("salbot")

LOG_LINE = re.compile(
    r"^!log\s+(?:\[(?P<actor>[^\]@\s]+)@(?P<host>[^\]\s]+)\]\s+)?(?P<message>.+)$",
    re.IGNORECASE,
)
TASK_SUFFIX = re.compile(r"\s*\((?P<task>T[0-9]+)\)\s*$")
TASK_ANYWHERE = re.compile(r"\b(T[0-9]+)\b")
RELAY_LINE = re.compile(r"<(?P<discord>[ a-z0-9._]*)> (?P<message>.*)")
LOGGED_REPLY = re.compile(r"^Logged the message at (?P<url>https://\S+#sal-[0-9]+(?:-[0-9]+)?)$")
NOTHING_LOGGED = "Message missing. Nothing logged."


class PhorgeError(Exception):
    def __init__(self, message, retry=False):
        super().__init__(message)
        self.retry = retry


class Proxy:
    def __init__(self, url):
        parts = urllib.parse.urlsplit(url)
        scheme = parts.scheme.lower()
        if scheme in ("socks5", "socks5h"):
            self.kind = "socks5"
        elif scheme == "http":
            self.kind = "http"
        else:
            raise ValueError("Unsupported proxy scheme %r, use socks5://, socks5h:// or http://" % parts.scheme)
        if not parts.hostname:
            raise ValueError("Proxy URL has no host")
        self.host = parts.hostname
        self.port = parts.port or (1080 if self.kind == "socks5" else 8080)
        self.username = urllib.parse.unquote(parts.username) if parts.username else None
        self.password = urllib.parse.unquote(parts.password) if parts.password else ""

    def __str__(self):
        return "%s://%s:%d" % (self.kind, self.host, self.port)


def read_exact(sock, count):
    data = b""
    while len(data) < count:
        chunk = sock.recv(count - len(data))
        if not chunk:
            raise ConnectionError("Proxy closed the connection during handshake")
        data += chunk
    return data


def socks5_connect(sock, proxy, host, port):
    if proxy.username is not None:
        sock.sendall(b"\x05\x02\x00\x02")
    else:
        sock.sendall(b"\x05\x01\x00")
    version, method = read_exact(sock, 2)
    if version != 5:
        raise ConnectionError("Proxy did not answer as SOCKS5")
    if method == 2:
        user = proxy.username.encode()
        password = proxy.password.encode()
        if len(user) > 255 or len(password) > 255:
            raise ConnectionError("Proxy credentials too long")
        sock.sendall(b"\x01" + bytes([len(user)]) + user + bytes([len(password)]) + password)
        if read_exact(sock, 2)[1] != 0:
            raise ConnectionError("Proxy rejected the credentials")
    elif method != 0:
        raise ConnectionError("Proxy offered no acceptable auth method")

    try:
        address = ipaddress.ip_address(host)
        target = (b"\x01" if address.version == 4 else b"\x04") + address.packed
    except ValueError:
        name = host.encode("idna")
        target = b"\x03" + bytes([len(name)]) + name
    sock.sendall(b"\x05\x01\x00" + target + port.to_bytes(2, "big"))

    reply = read_exact(sock, 4)
    if reply[1] != 0:
        raise ConnectionError("SOCKS5 connect failed with code %d" % reply[1])
    if reply[3] == 1:
        read_exact(sock, 6)
    elif reply[3] == 4:
        read_exact(sock, 18)
    elif reply[3] == 3:
        read_exact(sock, read_exact(sock, 1)[0] + 2)
    else:
        raise ConnectionError("SOCKS5 reply had an unknown address type")


def http_connect(sock, proxy, host, port):
    target = "[%s]:%d" % (host, port) if ":" in host else "%s:%d" % (host, port)
    lines = ["CONNECT %s HTTP/1.1" % target, "Host: " + target]
    if proxy.username is not None:
        token = base64.b64encode(("%s:%s" % (proxy.username, proxy.password)).encode()).decode()
        lines.append("Proxy-Authorization: Basic " + token)
    sock.sendall(("\r\n".join(lines) + "\r\n\r\n").encode())
    head = b""
    while not head.endswith(b"\r\n\r\n"):
        head += read_exact(sock, 1)
        if len(head) > 8192:
            raise ConnectionError("Proxy response headers too large")
    status = head.split(b"\r\n", 1)[0].decode("latin-1")
    parts = status.split(" ", 2)
    if len(parts) < 2 or parts[1] != "200":
        raise ConnectionError("Proxy refused CONNECT: " + status)


def open_socket(host, port, timeout, proxy=None):
    """Plain TCP connection, or a tunnel through the proxy. The proxy resolves the target name."""
    if proxy is None:
        return socket.create_connection((host, port), timeout)
    sock = socket.create_connection((proxy.host, proxy.port), timeout)
    try:
        if proxy.kind == "socks5":
            socks5_connect(sock, proxy, host, port)
        else:
            http_connect(sock, proxy, host, port)
    except Exception:
        sock.close()
        raise
    return sock


class ProxiedHTTPConnection(http.client.HTTPConnection):
    def __init__(self, *args, proxy=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.proxy = proxy

    def connect(self):
        self.sock = open_socket(self.host, self.port, self.timeout, self.proxy)


class ProxiedHTTPSConnection(http.client.HTTPSConnection):
    def __init__(self, *args, proxy=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.proxy = proxy

    def connect(self):
        sock = open_socket(self.host, self.port, self.timeout, self.proxy)
        self.sock = self._context.wrap_socket(sock, server_hostname=self.host)


def parse_irc(line):
    prefix = None
    if line.startswith(":"):
        prefix, _, line = line[1:].partition(" ")
    if " :" in line:
        head, _, trailing = line.partition(" :")
        params = head.split()
        params.append(trailing)
    else:
        params = line.split()
    if not params:
        return prefix, "", []
    return prefix, params[0].upper(), params[1:]


def extract_entry(text, task_mode="suffix"):
    """Returns (actor, message, [tasks]) or None when the line is not a log entry."""
    match = LOG_LINE.match(text.strip())
    if not match:
        return None
    actor = None
    if match.group("actor"):
        actor = "%s@%s" % (match.group("actor"), match.group("host"))
    message = match.group("message").strip()

    if task_mode == "any":
        tasks = list(dict.fromkeys(TASK_ANYWHERE.findall(message)))
    else:
        suffix = TASK_SUFFIX.search(message)
        if not suffix:
            return None
        tasks = [suffix.group("task")]
        message = message[: suffix.start()].rstrip()
    if not tasks or not message:
        return None
    return actor, message, tasks


class Phorge:
    def __init__(self, cfg):
        self.url = cfg["url"].rstrip("/")
        self.token = os.environ.get("PHORGE_API_TOKEN") or cfg["api_token"]
        self.timeout = cfg.get("timeout", 20)
        self.proxy = Proxy(cfg["proxy"]) if cfg.get("proxy") else None
        parts = urllib.parse.urlsplit(self.url)
        self.https = parts.scheme == "https"
        self.host = parts.hostname
        self.port = parts.port or (443 if self.https else 80)
        self.base_path = parts.path

    def connection(self):
        cls = ProxiedHTTPSConnection if self.https else ProxiedHTTPConnection
        return cls(self.host, self.port, timeout=self.timeout, proxy=self.proxy)

    def comment(self, task, body):
        data = urllib.parse.urlencode(
            {
                "api.token": self.token,
                "objectIdentifier": task,
                "transactions[0][type]": "comment",
                "transactions[0][value]": body,
            }
        )
        headers = {
            "User-Agent": "SALPhorgeBot/1.0",
            "Content-Type": "application/x-www-form-urlencoded",
        }
        conn = self.connection()
        try:
            conn.request("POST", self.base_path + "/api/maniphest.edit", data, headers)
            response = conn.getresponse()
            raw = response.read()
            status = response.status
        except (OSError, http.client.HTTPException) as error:
            raise PhorgeError(str(error), retry=True)
        finally:
            conn.close()
        if status >= 400:
            raise PhorgeError("HTTP %s" % status, retry=status >= 500)
        try:
            payload = json.loads(raw)
        except ValueError as error:
            raise PhorgeError("Bad JSON from Phorge: %s" % error, retry=True)
        if payload.get("error_code"):
            raise PhorgeError(
                "%s: %s" % (payload["error_code"], payload.get("error_info"))
            )


class Pending:
    def __init__(self, channel, entry):
        self.channel = channel
        self.entry = entry
        self.when = datetime.now(timezone.utc)
        self.created = time.monotonic()
        self.timer = None
        self.done = False


class Bot:
    def __init__(self, config):
        self.config = config
        self.irc_cfg = config["irc"]
        self.phorge = Phorge(config["phorge"])
        self.channels = [c.lower() for c in self.irc_cfg["channels"]]
        self.allowed = [m.lower() for m in config.get("allowed_senders", [])]
        self.skip = [re.compile(p) for p in config.get("skip_patterns", [])]
        self.task_mode = config.get("task_mode", "suffix")
        self.dry_run = config.get("dry_run", False)
        self.sal_url = config.get("sal_url", "").rstrip("/")
        self.time_format = config.get("time_format", "%Y-%m-%d %H:%M")
        sal_parts = urllib.parse.urlsplit(self.sal_url)
        self.sal_origin = "%s://%s" % (sal_parts.scheme, sal_parts.netloc) if sal_parts.netloc else ""
        self.logbot_nick = config.get("logbot_nick", "MirahezeLogbot")
        self.logbot_mask = config.get("logbot_mask", "%s!*@*" % self.logbot_nick).lower()
        self.relay_host = config.get("relay_host", "")
        self.link_wait = config.get("link_wait", 60)
        self.stale_seconds = config.get("stale_seconds", 600)
        self.pending = {}
        self.min_interval = config.get("min_post_interval", 1.0)
        self.retries = config.get("retries", 3)
        self.dedupe_window = config.get("dedupe_seconds", 60)
        self.queue = asyncio.Queue(maxsize=config.get("queue_size", 200))
        self.recent = {}
        self.writer = None
        self.nick = self.irc_cfg["nick"]
        self.proxy = Proxy(self.irc_cfg["proxy"]) if self.irc_cfg.get("proxy") else None

    def sender_allowed(self, mask):
        if not self.allowed:
            return True
        mask = mask.lower()
        return any(fnmatch.fnmatchcase(mask, pattern) for pattern in self.allowed)

    def seen_recently(self, key):
        now = time.monotonic()
        for old in [k for k, t in self.recent.items() if now - t > self.dedupe_window]:
            del self.recent[old]
        if key in self.recent:
            return True
        self.recent[key] = now
        return False

    def build_comment(self, channel, actor, message, when, link):
        nav = "{nav icon=file, name=Mentioned in SAL (%s), href=%s}" % (channel, link)
        return "%s [%s] <%s> %s" % (nav, when.strftime(self.time_format), actor, message)

    def unwrap(self, mask, text):
        """Mirrors how the logbot reads relayed Discord lines. Returns (line, discord name)."""
        if self.relay_host and mask.partition("!")[2] == self.relay_host:
            parsed = RELAY_LINE.search(text)
            if not parsed or not parsed.group("discord").split():
                return None, None
            return parsed.group("message"), "@" + parsed.group("discord").split()[0]
        return text, None

    def is_logged(self, line):
        nick = self.logbot_nick
        if line.startswith(nick) or line.startswith("!" + nick) or line.lower() == "!log help":
            return False
        return line.lower().startswith("!log ")

    def prepare(self, mask, line, discord):
        entry = extract_entry(line, self.task_mode)
        if entry is None:
            return None
        if not self.sender_allowed(mask):
            log.info("Ignored entry from %s", mask)
            return None
        actor, message, tasks = entry
        if any(p.search(message) for p in self.skip):
            log.debug("Skipped by pattern: %s", message)
            return None
        actor = actor or discord or mask.split("!", 1)[0]
        tasks = [t for t in tasks if not self.seen_recently((t, actor, message))]
        if not tasks:
            return None
        return {"actor": actor, "message": message, "tasks": tasks}

    def fallback_link(self, pending):
        return "%s#%s" % (self.sal_url, pending.when.strftime("%Y-%m-%d"))

    def trusted_link(self, url):
        return bool(self.sal_origin) and url.startswith(self.sal_origin + "/")

    def enqueue(self, pending, link):
        entry = pending.entry
        body = self.build_comment(
            pending.channel,
            entry["actor"],
            entry["message"],
            pending.when,
            link or self.fallback_link(pending),
        )
        for task in entry["tasks"]:
            try:
                self.queue.put_nowait((task, body))
            except asyncio.QueueFull:
                log.error("Queue full, dropped comment for %s", task)

    def purge(self, key):
        queue = self.pending.get(key)
        now = time.monotonic()
        while queue and now - queue[0].created > self.stale_seconds:
            old = queue.popleft()
            if old.timer:
                old.timer.cancel()

    def expire(self, pending):
        if pending.done:
            return
        pending.done = True
        if pending.entry:
            log.warning("No logbot reply in time, using the date link")
            self.enqueue(pending, None)

    def add_pending(self, key, channel, entry):
        pending = Pending(channel, entry)
        if entry:
            loop = asyncio.get_running_loop()
            pending.timer = loop.call_later(self.link_wait, self.expire, pending)
        self.pending.setdefault(key, deque()).append(pending)

    def handle_reply(self, key, text):
        text = text.strip()
        match = LOGGED_REPLY.match(text)
        if not match and text != NOTHING_LOGGED:
            return
        queue = self.pending.get(key)
        if not queue:
            return
        pending = queue.popleft()
        if pending.timer:
            pending.timer.cancel()
        if pending.done:
            return
        pending.done = True
        if not pending.entry or not match:
            return
        url = match.group("url")
        self.enqueue(pending, url if self.trusted_link(url) else None)

    def handle_message(self, mask, channel, text):
        key = channel.lower()
        if key not in self.channels:
            return
        self.purge(key)
        if fnmatch.fnmatchcase(mask.lower(), self.logbot_mask):
            self.handle_reply(key, text)
            return
        line, discord = self.unwrap(mask, text)
        if line is None or not self.is_logged(line):
            return
        self.add_pending(key, channel, self.prepare(mask, line, discord))

    async def poster(self):
        loop = asyncio.get_running_loop()
        while True:
            task, body = await self.queue.get()
            try:
                await self.post_with_retries(loop, task, body)
            finally:
                self.queue.task_done()
            await asyncio.sleep(self.min_interval)

    async def post_with_retries(self, loop, task, body):
        if self.dry_run:
            log.info("Dry run for %s: %s", task, body)
            return
        for attempt in range(1, self.retries + 1):
            try:
                await loop.run_in_executor(None, self.phorge.comment, task, body)
                log.info("Commented on %s", task)
                return
            except PhorgeError as error:
                if not error.retry or attempt == self.retries:
                    log.error("Could not comment on %s: %s", task, error)
                    return
                log.warning("Retry %d for %s: %s", attempt, task, error)
                await asyncio.sleep(2 ** attempt)

    def send(self, line):
        log.debug(">> %s", line if not line.startswith("AUTHENTICATE ") else "AUTHENTICATE ***")
        self.writer.write((line + "\r\n").encode("utf-8"))

    async def run(self):
        asyncio.create_task(self.poster())
        delay = self.irc_cfg.get("reconnect_min", 5)
        cap = self.irc_cfg.get("reconnect_max", 300)
        while True:
            try:
                if await self.session():
                    delay = self.irc_cfg.get("reconnect_min", 5)
            except (OSError, asyncio.TimeoutError, ConnectionError) as error:
                log.warning("Connection problem: %s", error)
            log.info("Reconnecting in %ds", delay)
            await asyncio.sleep(delay)
            delay = min(delay * 2, cap)

    async def session(self):
        cfg = self.irc_cfg
        context = ssl.create_default_context() if cfg.get("ssl", True) else None
        server, port = cfg["server"], cfg.get("port", 6697)
        if self.proxy:
            log.info("Connecting to %s:%d through %s", server, port, self.proxy)
            loop = asyncio.get_running_loop()
            sock = await asyncio.wait_for(
                loop.run_in_executor(None, open_socket, server, port, 30, self.proxy),
                timeout=45,
            )
            sock.setblocking(False)
            reader, self.writer = await asyncio.wait_for(
                asyncio.open_connection(
                    sock=sock,
                    ssl=context,
                    server_hostname=server if context else None,
                ),
                timeout=30,
            )
        else:
            reader, self.writer = await asyncio.wait_for(
                asyncio.open_connection(server, port, ssl=context),
                timeout=30,
            )
        self.nick = cfg["nick"]
        self.pending.clear()
        password = cfg.get("password", "")
        username = cfg.get("username") or cfg["nick"]
        use_sasl = bool(password) and cfg.get("sasl", True)
        registered = False
        pinged = False

        if use_sasl:
            self.send("CAP REQ :sasl")
        if cfg.get("server_password"):
            self.send("PASS " + cfg["server_password"])
        self.send("NICK " + self.nick)
        self.send("USER %s 0 * :%s" % (username, cfg.get("realname", "SAL Phorge bot")))

        try:
            while True:
                try:
                    raw = await asyncio.wait_for(reader.readline(), timeout=cfg.get("ping_interval", 180))
                except asyncio.TimeoutError:
                    if pinged:
                        raise
                    pinged = True
                    self.send("PING :keepalive")
                    continue
                if not raw:
                    raise ConnectionError("server closed the connection")
                pinged = False
                line = raw.decode("utf-8", errors="replace").rstrip("\r\n")
                log.debug("<< %s", line)
                prefix, command, params = parse_irc(line)

                if command == "PING":
                    self.send("PONG :" + (params[-1] if params else ""))
                elif command == "CAP" and len(params) >= 3:
                    if params[1] == "ACK" and "sasl" in params[2].split():
                        self.send("AUTHENTICATE PLAIN")
                    elif params[1] == "NAK":
                        log.warning("Server refused SASL")
                        self.send("CAP END")
                elif command == "AUTHENTICATE" and params and params[0] == "+":
                    blob = "%s\0%s\0%s" % (username, username, password)
                    self.send("AUTHENTICATE " + base64.b64encode(blob.encode()).decode())
                elif command == "903":
                    self.send("CAP END")
                elif command in ("902", "904", "905", "906"):
                    raise ConnectionError("SASL failed (%s)" % command)
                elif command == "433":
                    self.nick += "_"
                    self.send("NICK " + self.nick)
                elif command == "001":
                    registered = True
                    log.info("Registered as %s", self.nick)
                    if password and not use_sasl:
                        self.send("PRIVMSG NickServ :IDENTIFY %s %s" % (username, password))
                    for channel in cfg["channels"]:
                        self.send("JOIN " + channel)
                elif command == "PRIVMSG" and len(params) >= 2 and prefix:
                    text = params[1]
                    if text.startswith("\x01"):
                        continue
                    self.handle_message(prefix, params[0], text)
                elif command == "ERROR":
                    raise ConnectionError(" ".join(params))
        finally:
            try:
                self.writer.close()
            except Exception:
                pass
        return registered


def load_config(path):
    with open(path, encoding="utf-8") as handle:
        config = json.load(handle)
    for section, keys in (("irc", ("server", "nick", "channels")), ("phorge", ("url",))):
        for key in keys:
            if key not in config.get(section, {}):
                sys.exit("Missing %s.%s in config" % (section, key))
    for section in ("irc", "phorge"):
        url = config[section].get("proxy")
        if url:
            try:
                Proxy(url)
            except ValueError as error:
                sys.exit("Bad %s.proxy: %s" % (section, error))
    if "api_token" not in config["phorge"] and not os.environ.get("PHORGE_API_TOKEN"):
        sys.exit("Missing phorge.api_token in config")
    return config


def main():
    parser = argparse.ArgumentParser(description="SAL to Phorge comment bot")
    parser.add_argument("-c", "--config", default="config.json")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    config = load_config(args.config)
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else getattr(logging, config.get("log_level", "INFO").upper(), logging.INFO),
        format="%(asctime)s %(levelname)s %(message)s",
        filename=config.get("log_file") or None,
    )
    try:
        asyncio.run(Bot(config).run())
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
