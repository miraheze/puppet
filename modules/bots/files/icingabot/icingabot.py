#!/usr/bin/env python3
# Created by Universal Omega for T8845

import argparse
import base64
import contextlib
import http.server
import ipaddress
import json
import logging
import os
import re
import socket
import socketserver
import ssl
import sys
import threading
import time
import urllib.parse
import urllib.request
from collections import deque

log = logging.getLogger('icingabot')

STATES = {0: 'OK', 1: 'WARNING', 2: 'CRITICAL', 3: 'UNKNOWN'}

PRIORITIES = {'unbreak': 100, 'triage': 90, 'high': 75, 'medium': 50, 'low': 25, 'lowest': 10}

ATTRS = [
    'name',
    'display_name',
    'host_name',
    'vars',
    'state',
    'state_type',
    'downtime_depth',
    'notes_url',
    'last_check_result',
    'last_state_ok',
    'last_state_change',
    'flapping',
]

JOINS = ['host.state', 'host.downtime_depth']

KEY = re.compile(r'^Icinga service: `(.+)`$', re.MULTILINE)
STORM = re.compile(r'^Icinga alert storm summary$', re.MULTILINE)
TITLE_STATE = re.compile(r' is (WARNING|CRITICAL|UNKNOWN)$')
STORM_TITLE = 'Many Icinga services are alerting'

POLL_SECONDS = 0.5
REGISTER_TIMEOUT = 120
RESTART_MIN = 5
RESTART_MAX = 300
IRC_LIMIT = 400
CONTROL = re.compile(r'[\x00-\x1f\x7f]')
NICK = re.compile(r'[A-Za-z0-9\[\]\\`_^{|}-]+')
CHANNEL = re.compile(r'[#&][^\s,\x00-\x1f\x7f]+')
JOIN_FAILED = {'403', '405', '471', '473', '474', '475', '476', '477', '520'}
SASL_FAILED = {'902', '904', '905', '906'}

REQUIRED = {
    'icinga': [
        'url', 'username', 'password', 'ca_file', 'queue', 'timeout', 'stream_timeout',
    ],
    'phorge': ['url', 'api_token', 'timeout', 'retries', 'proxy'],
    'irc': [
        'server', 'port', 'ssl', 'nick', 'username', 'password', 'sasl', 'realname', 'channels',
        'ping_interval', 'reconnect_min', 'reconnect_max', 'proxy', 'queue', 'queue_size',
        'message_interval', 'notify_users', 'heartbeat_file', 'heartbeat_interval',
    ],
    'grafana': ['host', 'port', 'max_lines', 'max_body'],
    'priorities': ['WARNING', 'CRITICAL', 'UNKNOWN'],
    'icingaweb_url': None,
    'skip_in_downtime': None,
    'close_after_recovery_seconds': None,
    'close_after_recovery_commented_seconds': None,
    'close_status': None,
    'grace_minutes': None,
    'change_grace_minutes': None,
    'storm_limit': None,
    'storm_window_minutes': None,
    'reopen_hours': None,
    'reconcile_interval': None,
    'reconnect_min': None,
    'reconnect_max': None,
    'state_file': None,
    'heartbeat_file': None,
    'dry_run': None,
    'log_level': None,
}


class PhorgeError(Exception):
    pass


class PhorgeUncertain(PhorgeError):
    pass


def missing_keys(config):
    missing = []
    for key, inner in REQUIRED.items():
        if key not in config:
            missing.append(key)
        elif inner:
            section = config[key]
            if not isinstance(section, dict):
                missing.append(key)
                continue
            missing.extend(f'{key}.{name}' for name in inner if name not in section)
    return missing


def is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def is_whole(value, low, high=None):
    return isinstance(value, int) and not isinstance(value, bool) and value >= low and (high is None or value <= high)


def is_plain(value):
    return isinstance(value, str) and not CONTROL.search(value)


def irc_problems(irc):
    problems = []
    for key in ('server', 'queue', 'heartbeat_file'):
        if not isinstance(irc[key], str) or not irc[key]:
            problems.append(f'irc.{key} must be a non-empty string')
    for key in ('nick', 'username'):
        if not isinstance(irc[key], str) or not NICK.fullmatch(irc[key]):
            problems.append(f'irc.{key} must be a valid IRC name')
    for key in ('realname', 'password'):
        if not is_plain(irc[key]):
            problems.append(f'irc.{key} must be a string without line breaks')
    if not is_whole(irc['port'], 1, 65535):
        problems.append('irc.port must be a whole number from 1 to 65535')
    for key in ('ssl', 'sasl'):
        if not isinstance(irc[key], bool):
            problems.append(f'irc.{key} must be true or false')
    channels = irc['channels']
    if not isinstance(channels, list) or not channels or not all(
        isinstance(name, str) and CHANNEL.fullmatch(name) for name in channels
    ):
        problems.append('irc.channels must be a list of channel names')
    users = irc['notify_users']
    if not isinstance(users, list) or not all(isinstance(name, str) for name in users):
        problems.append('irc.notify_users must be a list of Icinga user names')
    for key in ('ping_interval', 'reconnect_min', 'heartbeat_interval'):
        if not is_number(irc[key]) or irc[key] <= 0:
            problems.append(f'irc.{key} must be a number above 0')
    if is_number(irc['reconnect_min']) and is_number(irc['reconnect_max']):
        if irc['reconnect_max'] < irc['reconnect_min']:
            problems.append('irc.reconnect_max must not be lower than irc.reconnect_min')
    else:
        problems.append('irc.reconnect_max must be a number above 0')
    if not is_number(irc['message_interval']) or irc['message_interval'] < 0:
        problems.append('irc.message_interval must be a number of 0 or more')
    if not is_whole(irc['queue_size'], 1):
        problems.append('irc.queue_size must be a whole number of 1 or more')
    if irc['proxy']:
        try:
            Proxy(irc['proxy'])
        except (ValueError, AttributeError, TypeError) as error:
            problems.append(f'irc.proxy is not usable: {error}')
    return problems


def grafana_problems(grafana):
    problems = []
    if not isinstance(grafana['host'], str) or not grafana['host']:
        problems.append('grafana.host must be a non-empty string')
    if not is_whole(grafana['port'], 1, 65535):
        problems.append('grafana.port must be a whole number from 1 to 65535')
    for key in ('max_lines', 'max_body'):
        if not is_whole(grafana[key], 1):
            problems.append(f'grafana.{key} must be a whole number of 1 or more')
    return problems


def invalid_values(config):
    problems = []
    for key in ('grace_minutes', 'change_grace_minutes', 'storm_window_minutes', 'reopen_hours'):
        value = config[key]
        if not is_number(value) or value < 0:
            problems.append(f'{key} must be a number of 0 or more')
    for key in ('close_after_recovery_seconds', 'close_after_recovery_commented_seconds'):
        delay = config[key]
        if delay is not None and (not is_number(delay) or delay < 0):
            problems.append(f'{key} must be null or a number of 0 or more')
    limit = config['storm_limit']
    if isinstance(limit, bool) or not isinstance(limit, int) or limit < 1:
        problems.append('storm_limit must be a whole number of 1 or more')
    problems.extend(
        f"priorities.{state} must be one of {', '.join(PRIORITIES)}"
        for state, keyword in config['priorities'].items()
        if keyword not in PRIORITIES
    )
    problems.extend(irc_problems(config['irc']))
    problems.extend(grafana_problems(config['grafana']))
    return problems


def load_config(path):
    try:
        with open(path) as handle:
            config = json.load(handle)
    except (OSError, ValueError) as error:
        sys.exit(f'Cannot load {path}: {error}')
    if not isinstance(config, dict):
        sys.exit(f'{path} must contain a JSON object')
    missing = missing_keys(config)
    if missing:
        sys.exit(f"Missing in config: {', '.join(missing)}")
    problems = invalid_values(config)
    if problems:
        sys.exit(f"Invalid config: {'; '.join(problems)}")
    return config


def flatten(value, prefix=''):
    items = []
    if isinstance(value, dict):
        for key, inner in value.items():
            items.extend(flatten(inner, f'{prefix}[{key}]' if prefix else str(key)))
    elif isinstance(value, (list, tuple)):
        for index, inner in enumerate(value):
            items.extend(flatten(inner, f'{prefix}[{index}]'))
    else:
        items.append((prefix, str(value)))
    return items


def build_opener(proxy=None, context=None):
    handlers = [urllib.request.ProxyHandler({'http': proxy, 'https': proxy} if proxy else {})]
    if context is not None:
        handlers.append(urllib.request.HTTPSHandler(context=context))
    return urllib.request.build_opener(*handlers)


def task_text(task):
    return ((task.get('fields') or {}).get('description') or {}).get('raw') or ''


def task_key(task):
    match = KEY.search(task_text(task))
    return match.group(1) if match else None


def is_storm_task(task):
    return bool(STORM.search(task_text(task)))


def title_state(task):
    match = TITLE_STATE.search((task.get('fields') or {}).get('name') or '')
    return match.group(1) if match else 'UNKNOWN'


def describe_seconds(seconds):
    for size, unit in ((3600, 'hour'), (60, 'minute')):
        if seconds >= size and seconds % size == 0:
            count = int(seconds // size)
            return f"{count} {unit}{'' if count == 1 else 's'}"
    count = int(seconds) if float(seconds).is_integer() else seconds
    return f"{count} second{'' if count == 1 else 's'}"


def failing_since(attrs):
    ok = attrs.get('last_state_ok') or 0
    return ok if ok > 0 else attrs.get('last_state_change') or 0


class Proxy:
    def __init__(self, url):
        parts = urllib.parse.urlsplit(url)
        scheme = parts.scheme.lower()
        if scheme in ('socks5', 'socks5h'):
            self.kind = 'socks5'
        elif scheme == 'http':
            self.kind = 'http'
        else:
            raise ValueError(f'Unsupported proxy scheme {parts.scheme!r}, use socks5://, socks5h:// or http://')
        if not parts.hostname:
            raise ValueError('Proxy URL has no host')
        self.host = parts.hostname
        self.port = parts.port or (1080 if self.kind == 'socks5' else 8080)
        self.username = urllib.parse.unquote(parts.username) if parts.username else None
        self.password = urllib.parse.unquote(parts.password) if parts.password else ''

    def __str__(self):
        return f'{self.kind}://{self.host}:{self.port}'


def read_exact(sock, count):
    data = b''
    while len(data) < count:
        chunk = sock.recv(count - len(data))
        if not chunk:
            raise ConnectionError('Proxy closed the connection during handshake')
        data += chunk
    return data


def socks5_connect(sock, proxy, host, port):
    if proxy.username is not None:
        sock.sendall(b'\x05\x02\x00\x02')
    else:
        sock.sendall(b'\x05\x01\x00')
    version, method = read_exact(sock, 2)
    if version != 5:
        raise ConnectionError('Proxy did not answer as SOCKS5')
    if method == 2:
        user = proxy.username.encode()
        password = proxy.password.encode()
        if len(user) > 255 or len(password) > 255:
            raise ConnectionError('Proxy credentials too long')
        sock.sendall(b'\x01' + bytes([len(user)]) + user + bytes([len(password)]) + password)
        if read_exact(sock, 2)[1] != 0:
            raise ConnectionError('Proxy rejected the credentials')
    elif method != 0:
        raise ConnectionError('Proxy offered no acceptable auth method')

    try:
        address = ipaddress.ip_address(host)
        target = (b'\x01' if address.version == 4 else b'\x04') + address.packed
    except ValueError:
        name = host.encode('idna')
        target = b'\x03' + bytes([len(name)]) + name
    sock.sendall(b'\x05\x01\x00' + target + port.to_bytes(2, 'big'))

    reply = read_exact(sock, 4)
    if reply[1] != 0:
        raise ConnectionError(f'SOCKS5 connect failed with code {reply[1]}')
    if reply[3] == 1:
        read_exact(sock, 6)
    elif reply[3] == 4:
        read_exact(sock, 18)
    elif reply[3] == 3:
        read_exact(sock, read_exact(sock, 1)[0] + 2)
    else:
        raise ConnectionError('SOCKS5 reply had an unknown address type')


def http_connect(sock, proxy, host, port):
    target = f'[{host}]:{port}' if ':' in host else f'{host}:{port}'
    lines = [f'CONNECT {target} HTTP/1.1', f'Host: {target}']
    if proxy.username is not None:
        token = base64.b64encode(f'{proxy.username}:{proxy.password}'.encode()).decode()
        lines.append(f'Proxy-Authorization: Basic {token}')
    sock.sendall(('\r\n'.join(lines) + '\r\n\r\n').encode())
    head = b''
    while not head.endswith(b'\r\n\r\n'):
        head += read_exact(sock, 1)
        if len(head) > 8192:
            raise ConnectionError('Proxy response headers too large')
    status = head.split(b'\r\n', 1)[0].decode('latin-1')
    parts = status.split(' ', 2)
    if len(parts) < 2 or parts[1] != '200':
        raise ConnectionError(f'Proxy refused CONNECT: {status}')


def open_socket(host, port, timeout, proxy=None):
    """Plain TCP connection, or a tunnel through the proxy. The proxy resolves the target name."""
    if proxy is None:
        return socket.create_connection((host, port), timeout)
    sock = socket.create_connection((proxy.host, proxy.port), timeout)
    try:
        if proxy.kind == 'socks5':
            socks5_connect(sock, proxy, host, port)
        else:
            http_connect(sock, proxy, host, port)
    except Exception:
        sock.close()
        raise
    return sock


class Phorge:
    def __init__(self, config, dry_run=False):
        self.url = config['url'].rstrip('/')
        self.token = config['api_token']
        self.timeout = config['timeout']
        self.retries = max(1, config['retries'])
        self.phids = {}
        self.user_phid = None
        self.dry_run = dry_run
        self.opener = build_opener(config['proxy'])

    def call(self, method, params=None, attempts=None):
        attempts = attempts or self.retries
        fields = [('api.token', self.token), *flatten(params or {})]
        request = urllib.request.Request(
            f'{self.url}/api/{method}',
            data=urllib.parse.urlencode(fields).encode(),
        )
        failure = None
        for attempt in range(1, attempts + 1):
            log.debug(f'Calling {method}, attempt {attempt} of {attempts}')
            try:
                with self.opener.open(request, timeout=self.timeout) as response:
                    body = json.load(response)
            except (OSError, ValueError) as error:
                failure = PhorgeUncertain(f'{method} request failed: {error}')
                log.debug(str(failure))
                if attempt < attempts:
                    time.sleep(min(2 ** attempt, 30))
                continue
            if body.get('error_code'):
                raise PhorgeError(f"{method} returned {body['error_code']}: {body.get('error_info')}")
            return body['result']
        raise failure

    def resolve(self, slugs):
        phids = []
        for slug in slugs:
            if slug not in self.phids:
                result = self.call('project.search', {'constraints': {'slugs': [slug]}})
                if not result['data']:
                    log.warning(f'Project {slug} was not found in Phorge')
                    continue
                self.phids[slug] = result['data'][0]['phid']
                log.debug(f'Project {slug} is {self.phids[slug]}')
            phids.append(self.phids[slug])
        return phids

    def edit(self, transactions, task=None, attempts=None):
        params = {'transactions': transactions}
        if task is not None:
            params['objectIdentifier'] = task
        if self.dry_run:
            log.info(f'Dry run, would send {json.dumps(params)}')
            return {'object': {'id': task or 0}}
        return self.call('maniphest.edit', params, attempts)

    def create(self, title, description, priority, slugs, matches):
        transactions = [
            {'type': 'title', 'value': title},
            {'type': 'description', 'value': description},
        ]
        if priority:
            transactions.append({'type': 'priority', 'value': priority})
        phids = self.resolve(slugs)
        if phids:
            transactions.append({'type': 'projects.add', 'value': phids})
        for attempt in range(1, self.retries + 1):
            try:
                return self.edit(transactions, attempts=1)['object']['id']
            except PhorgeUncertain as error:
                log.debug(f'Not sure whether the task was created, looking for it: {error}')
                existing = self.find(matches)
                if existing:
                    return existing['id']
                if attempt == self.retries:
                    raise
                time.sleep(min(2 ** attempt, 30))
        raise PhorgeError('Could not create the task')

    def whoami(self):
        if self.user_phid is None:
            self.user_phid = self.call('user.whoami')['phid']
        return self.user_phid

    def open_tasks(self):
        params = {
            'queryKey': 'open',
            'constraints': {'authorPHIDs': [self.whoami()]},
            'order': 'oldest',
            'limit': 100,
        }
        while True:
            result = self.call('maniphest.search', params)
            yield from result['data']
            after = (result.get('cursor') or {}).get('after')
            if not after:
                return
            params = {**params, 'after': after}

    def find(self, matches):
        return next((task for task in self.open_tasks() if matches(task)), None)

    def is_open(self, task):
        result = self.call('maniphest.search', {
            'queryKey': 'open',
            'constraints': {'ids': [task]},
        })
        return bool(result['data'])

    def comment_authors(self, task):
        bot = self.whoami()
        params = {'objectIdentifier': f'T{task}', 'limit': 100}
        found = []
        while True:
            result = self.call('transaction.search', params)
            for transaction in result['data']:
                comments = transaction.get('comments') or []
                if any(not comment.get('removed') for comment in comments):
                    found.append((transaction.get('id') or 0, transaction.get('authorPHID') == bot))
            after = (result.get('cursor') or {}).get('after')
            if not after:
                return found
            params = {**params, 'after': after}

    def has_human_comment(self, task):
        return any(not by_bot for _, by_bot in self.comment_authors(task))

    def has_human_comment_after_bot(self, task):
        found = self.comment_authors(task)
        last = max((number for number, by_bot in found if by_bot), default=0)
        return any(number > last for number, by_bot in found if not by_bot)

    def details(self, task):
        result = self.call('maniphest.search', {
            'queryKey': 'all',
            'constraints': {'ids': [task]},
        })
        if not result['data']:
            return None
        fields = result['data'][0]['fields']
        return {
            'title': fields['name'],
            'status': fields['status']['value'],
            'priority': fields['priority']['value'],
        }


class Icinga:
    def __init__(self, config, queue=None):
        self.url = config['url'].rstrip('/')
        self.queue = queue or config['queue']
        self.timeout = config['timeout']
        self.stream_timeout = config['stream_timeout']
        self.warned = False
        login = f"{config['username']}:{config['password']}".encode()
        self.headers = {
            'Authorization': f'Basic {base64.b64encode(login).decode()}',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
        }
        context = None
        if self.url.startswith('https'):
            context = ssl.create_default_context(cafile=config['ca_file'] or None)
            context.verify_flags &= ~ssl.VERIFY_X509_STRICT
        self.opener = build_opener(None, context)

    def request(self, path, body, timeout, override=None):
        headers = dict(self.headers)
        if override:
            headers['X-HTTP-Method-Override'] = override
        request = urllib.request.Request(
            f'{self.url}{path}',
            data=json.dumps(body).encode(),
            headers=headers,
            method='POST',
        )
        return self.opener.open(request, timeout=timeout)

    def query(self, body):
        body = {**body, 'attrs': ATTRS, 'joins': JOINS}
        with self.request('/v1/objects/services', body, self.timeout, 'GET') as response:
            results = json.load(response)['results']
        if results and not self.warned and not any(result.get('joins') for result in results):
            self.warned = True
            log.warning('Icinga returned no host details, the API user needs objects/query/Host')
        services = []
        for result in results:
            attrs = dict(result['attrs'])
            attrs['host'] = (result.get('joins') or {}).get('host') or {}
            services.append(attrs)
        return services

    def problems(self):
        return self.query({'filter': 'service.state != 0 && service.state_type == 1'})

    def service(self, host, name):
        services = self.query({
            'filter': 'service.host_name == wanted_host && service.name == wanted_service',
            'filter_vars': {'wanted_host': host, 'wanted_service': name},
        })
        return services[0] if services else None

    def events(self, types=('StateChange',)):
        body = {'queue': self.queue, 'types': list(types)}
        with self.request('/v1/events', body, self.stream_timeout) as response:
            log.debug('Connected to the Icinga event stream')
            with contextlib.suppress(TimeoutError):
                for line in response:
                    line = line.strip()
                    if line:
                        yield json.loads(line)


class State:
    def __init__(self, path, persist=True):
        self.path = path
        self.persist = persist
        self.services = {}
        self.created = []
        self.storm = None
        self.storm_recovered = None
        self.storm_close_after = None
        try:
            with open(path) as handle:
                data = json.load(handle)
        except FileNotFoundError:
            return
        except (OSError, ValueError) as error:
            log.warning(f'Ignoring unreadable state file {path}: {error}')
            return
        if not isinstance(data, dict):
            log.warning(f'Ignoring state file {path}, it does not hold an object')
            return
        if 'services' in data:
            self.services = data['services']
            self.created = data.get('created') or []
            self.storm = data.get('storm')
            self.storm_recovered = data.get('storm_recovered')
            self.storm_close_after = data.get('storm_close_after')
        else:
            self.services = data

    def save(self):
        if not self.persist:
            return
        temp = f'{self.path}.tmp'
        with open(temp, 'w') as handle:
            json.dump(
                {
                    'services': self.services,
                    'created': self.created,
                    'storm': self.storm,
                    'storm_recovered': self.storm_recovered,
                    'storm_close_after': self.storm_close_after,
                },
                handle,
                indent=2,
                sort_keys=True,
            )
        os.replace(temp, self.path)

    def get(self, key):
        return self.services.get(key)

    def put(self, key, entry):
        self.services[key] = entry
        self.save()

    def record_created(self, now, window):
        self.created = [stamp for stamp in self.created if now - stamp < window]
        self.created.append(now)
        self.save()

    def recent(self, now, window):
        return sum(1 for stamp in self.created if now - stamp < window)

    def set_storm(self, task):
        self.storm = task
        self.storm_recovered = None
        self.storm_close_after = None
        self.save()

    def set_storm_recovered(self, when, delay):
        self.storm_recovered = when
        self.storm_close_after = delay
        self.save()


def write_heartbeat(path):
    try:
        with open(path, 'w') as handle:
            handle.write(f'{int(time.time())}\n')
    except OSError as error:
        log.error(f'Could not write the heartbeat file: {error}')


def check_output(attrs):
    result = attrs.get('last_check_result') or {}
    text = (result.get('output') or '').strip().replace('```', "'''")
    return text[:1500] or 'No output.'


class Bot:
    def __init__(self, config):
        self.config = config
        self.icinga = Icinga(config['icinga'])
        self.phorge = Phorge(config['phorge'], config['dry_run'])
        self.state = State(config['state_file'], not config['dry_run'])
        self.last_reconcile = 0.0
        self.failures = 0
        self.adopted = False

    def title(self, attrs, state):
        return f"{attrs.get('display_name') or attrs['name']} on {attrs['host_name']} is {state}"

    def description(self, attrs, state):
        host = attrs['host_name']
        name = attrs['name']
        lines = [
            f"Icinga reported **{state}** for **{attrs.get('display_name') or name}** on **{host}**.",
            '',
            '```',
            check_output(attrs),
            '```',
        ]
        if attrs.get('notes_url'):
            lines.extend(['', f"Documentation: {attrs['notes_url']}"])
        base = self.config['icingaweb_url'].rstrip('/')
        if base:
            query = urllib.parse.urlencode({'name': name, 'host.name': host}, quote_via=urllib.parse.quote)
            lines.extend(['', f'Icinga Web: {base}/icingadb/service?{query}'])
        lines.extend(['', f'Icinga service: `{host}!{name}`'])
        lines.extend(['', time.strftime('Reported at %Y-%m-%d %H:%M UTC', time.gmtime())])
        return '\n'.join(lines)

    def storm_description(self):
        limit = self.config['storm_limit']
        window = self.config['storm_window_minutes']
        return '\n'.join([
            f'More than {limit} services started alerting within {window} minutes, '
            'so they are reported here instead of in separate tasks.',
            '',
            'Each service is added as a comment and marked when it recovers.',
            '',
            'Icinga alert storm summary',
        ])

    def blocked(self, attrs):
        host = attrs.get('host') or {}
        if self.config['skip_in_downtime']:
            if attrs.get('downtime_depth', 0) > 0:
                return 'in downtime'
            if host.get('downtime_depth', 0) > 0:
                return 'its host is in downtime'
        if host.get('state', 0) != 0:
            return 'its host is down'
        return None

    def too_soon(self, key, attrs, state, initial):
        if initial:
            minutes = self.config['grace_minutes']
            since = failing_since(attrs)
            what = 'failing'
        else:
            minutes = self.config['change_grace_minutes']
            since = attrs.get('last_state_change') or 0
            what = state
        age = time.time() - since
        if age >= minutes * 60:
            return False
        log.debug(f'{key} is {state} but it has only been {what} for {int(age // 60)} minutes, skipping')
        return True

    def refresh(self, task, attrs, previous, state):
        info = self.phorge.details(task)
        if not info:
            return []
        transactions = []
        if previous and previous != state and info['title'] == self.title(attrs, previous):
            transactions.append({'type': 'title', 'value': self.title(attrs, state)})
        priorities = self.config['priorities']
        wanted = priorities[state]
        current = info['priority']
        target = PRIORITIES[wanted]
        ours = PRIORITIES[priorities[previous]] if previous in priorities else None
        worse = ours is None or target > ours
        if target != current and (current == ours or (worse and target > current)):
            transactions.append({'type': 'priority', 'value': wanted})
        return transactions

    def remember(self, key, task):
        state = title_state(task)
        log.info(f"Adopted T{task['id']} for {key} ({state})")
        entry = {'task': task['id'], 'active': True, 'state': state, 'alert': state}
        self.state.put(key, entry)
        return entry

    def update(self, key, entry, attrs, state):
        if entry.get('active') and entry.get('state') == state:
            return
        task = entry['task']
        lead = 'Now' if entry.get('active') else 'Alerting again,'
        text = f"{lead} **{state}**.\n\n```\n{check_output(attrs)}\n```"
        transactions = [{'type': 'comment', 'value': text}]
        transactions.extend(self.refresh(task, attrs, entry.get('alert'), state))
        self.phorge.edit(transactions, task)
        log.info(f'Updated T{task} for {key} ({state})')
        self.state.put(key, {'task': task, 'active': True, 'state': state, 'alert': state})

    def reopen(self, key, entry, attrs, state):
        closed = entry.get('closed')
        if not closed or time.time() - closed > self.config['reopen_hours'] * 3600:
            return False
        task = entry['task']
        info = self.phorge.details(task)
        if not info or info['status'] != self.config['close_status']:
            return False
        text = f"Alerting again, **{state}**.\n\n```\n{check_output(attrs)}\n```"
        transactions = [{'type': 'status', 'value': 'open'}, {'type': 'comment', 'value': text}]
        transactions.extend(self.refresh(task, attrs, entry.get('alert'), state))
        self.phorge.edit(transactions, task)
        log.info(f'Reopened T{task} for {key} ({state})')
        self.state.put(key, {'task': task, 'active': True, 'state': state, 'alert': state})
        return True

    def storming(self):
        window = self.config['storm_window_minutes'] * 60
        return self.state.recent(time.time(), window) >= self.config['storm_limit']

    def storm_task(self):
        task = self.state.storm
        if task is not None and self.phorge.is_open(task):
            return task
        found = self.phorge.find(is_storm_task)
        if found:
            task = found['id']
        else:
            task = self.phorge.create(
                STORM_TITLE,
                self.storm_description(),
                self.config['priorities']['CRITICAL'],
                [],
                is_storm_task,
            )
            log.info(f'Created alert storm task T{task}')
        self.state.set_storm(task)
        return task

    def storm_open(self, key, attrs, state):
        summary = self.storm_task()
        text = f"`{key}` is **{state}**.\n\n```\n{check_output(attrs)}\n```"
        self.phorge.edit([{'type': 'comment', 'value': text}], summary)
        log.info(f'Added {key} ({state}) to alert storm task T{summary}')
        self.state.put(key, {'task': summary, 'active': True, 'state': state, 'alert': state, 'storm': True})

    def storm_note(self, key, state, entry):
        self.phorge.edit([{'type': 'comment', 'value': f'`{key}` is now **{state}**.'}], entry['task'])
        self.state.put(key, {**entry, 'state': state, 'alert': state})

    def storm_members(self, task, skip=None):
        return [
            other for key, other in self.state.services.items()
            if other.get('storm') and other.get('active') and other['task'] == task and key != skip
        ]

    def recovery_plan(self, task):
        plain = self.config['close_after_recovery_seconds']
        commented = self.config['close_after_recovery_commented_seconds']
        if plain is None and commented is None:
            return None, False
        spoken = self.phorge.has_human_comment(task)
        return (commented if spoken else plain), spoken

    @staticmethod
    def closing_notice(delay, spoken):
        if not delay:
            return ''
        when = describe_seconds(delay)
        if spoken:
            return (
                f' Someone has already commented on this task, so it will be closed automatically in {when}'
                ' unless someone comments again after this message.'
            )
        return f' This task will be closed automatically in {when} unless someone comments on it.'

    def storm_clear(self, key, state, entry):
        task = entry['task']
        last = not self.storm_members(task, skip=key)
        if state == 'OK':
            text = f'`{key}` recovered.'
        elif state == 'GONE':
            text = f'`{key}` no longer exists in Icinga.'
        else:
            text = f'`{key}` is now **{state}**, which is not an alert state.'
        delay, spoken = self.recovery_plan(task) if last else (None, False)
        text += self.closing_notice(delay, spoken)
        transactions = [{'type': 'comment', 'value': text}]
        closing = last and delay == 0
        if closing:
            transactions.append({'type': 'status', 'value': self.config['close_status']})
        self.phorge.edit(transactions, task)
        self.state.put(key, {**entry, 'active': False, 'state': state})
        if closing:
            log.info(f'Closed alert storm task T{task}')
            self.state.set_storm(None)
        elif last and delay:
            self.state.set_storm_recovered(time.time(), delay)

    def create_task(self, key, attrs, state):
        if self.storming():
            self.storm_open(key, attrs, state)
            return
        slugs = attrs['vars'].get('phorge_projects') or []
        task = self.phorge.create(
            self.title(attrs, state),
            self.description(attrs, state),
            self.config['priorities'][state],
            slugs,
            lambda other: task_key(other) == key,
        )
        log.info(f'Created T{task} for {key} ({state})')
        self.state.record_created(time.time(), self.config['storm_window_minutes'] * 60)
        self.state.put(key, {'task': task, 'active': True, 'state': state, 'alert': state})

    def problem(self, key, attrs, state):
        entry = self.state.get(key)
        if entry and entry.get('active') and entry.get('state') == state:
            return
        if entry and entry.get('storm'):
            if entry.get('active'):
                if not self.too_soon(key, attrs, state, False):
                    self.storm_note(key, state, entry)
                return
            entry = None
        if entry and self.phorge.is_open(entry['task']):
            if not self.too_soon(key, attrs, state, False):
                self.update(key, entry, attrs, state)
            return
        if self.too_soon(key, attrs, state, True):
            return
        if entry and self.reopen(key, entry, attrs, state):
            return
        found = self.phorge.find(lambda other: task_key(other) == key)
        if found:
            self.update(key, self.remember(key, found), attrs, state)
            return
        self.create_task(key, attrs, state)

    @staticmethod
    def tracking(entry):
        if not entry:
            return False
        if entry.get('active'):
            return True
        return not entry.get('storm') and entry.get('state') not in ('OK', 'GONE')

    def clear(self, key, state, attrs=None):
        entry = self.state.get(key)
        if not self.tracking(entry):
            return
        if entry.get('storm'):
            self.storm_clear(key, state, entry)
            return
        if state not in ('OK', 'GONE') and entry.get('state') == state:
            return
        recovering = state in ('OK', 'GONE')
        delay, spoken = self.recovery_plan(entry['task']) if recovering else (None, False)
        if state == 'OK':
            text = 'Recovered, the service is back to **OK**.'
        elif state == 'GONE':
            text = 'This service no longer exists in Icinga, so no further alerts are expected.'
        else:
            text = f'Now **{state}**, which is not an alert state for this service.'
        text += self.closing_notice(delay, spoken)
        closing = recovering and delay == 0
        transactions = [{'type': 'comment', 'value': text}]
        if not recovering and attrs is not None:
            transactions.extend(self.refresh(entry['task'], attrs, entry.get('alert'), state))
        if closing:
            transactions.append({'type': 'status', 'value': self.config['close_status']})
        self.phorge.edit(transactions, entry['task'])
        log.info(f"Updated T{entry['task']} for {key} ({state})")
        updated = {
            'task': entry['task'],
            'active': False,
            'state': state,
            'alert': (entry.get('alert') or entry.get('state')) if recovering else state,
        }
        if closing:
            updated['closed'] = time.time()
        elif recovering and delay:
            updated['recovered'] = time.time()
            updated['close_after'] = delay
        self.state.put(key, updated)

    def close_unless_handled(self, task, delay):
        if not self.phorge.is_open(task):
            return False
        if self.phorge.has_human_comment_after_bot(task):
            note = 'Someone commented after the last update, so this task stays open for a person to decide.'
            self.phorge.edit([{'type': 'comment', 'value': note}], task)
            log.info(f'Left T{task} open because someone commented on it')
            return False
        note = f'Closing automatically, {describe_seconds(delay)} after the last update with no comments from anyone since.'
        self.phorge.edit([
            {'type': 'comment', 'value': note},
            {'type': 'status', 'value': self.config['close_status']},
        ], task)
        log.info(f'Closed T{task} after it recovered')
        return True

    def close_recovered(self, key, entry, delay):
        settled = {name: value for name, value in entry.items() if name not in ('recovered', 'close_after')}
        if self.close_unless_handled(entry['task'], delay):
            settled['closed'] = time.time()
        self.state.put(key, settled)

    def close_storm(self, task, delay):
        self.close_unless_handled(task, delay)
        self.state.set_storm(None)

    def close_due(self):
        now = time.time()
        fallback = self.config['close_after_recovery_seconds']
        for key, entry in list(self.state.services.items()):
            recovered = entry.get('recovered')
            delay = entry.get('close_after', fallback)
            if entry.get('active') or recovered is None or delay is None or now - recovered < delay:
                continue
            self.safe(self.close_recovered, key, entry, delay)
        task = self.state.storm
        recovered = self.state.storm_recovered
        delay = fallback if self.state.storm_close_after is None else self.state.storm_close_after
        if task is None or recovered is None or delay is None or now - recovered < delay:
            return
        if not self.storm_members(task):
            self.safe(self.close_storm, task, delay)

    def process(self, attrs):
        key = f"{attrs['host_name']}!{attrs['name']}"
        triggers = (attrs.get('vars') or {}).get('phorge_triggers')
        if not isinstance(triggers, list) or not triggers:
            log.debug(f'{key} does not set phorge_triggers, skipping')
            return
        if int(attrs.get('state_type', 1)) != 1:
            log.debug(f'{key} is in a soft state, skipping')
            return
        if attrs.get('flapping'):
            log.debug(f'{key} is flapping, skipping')
            return
        state = STATES.get(int(attrs['state']), 'UNKNOWN')
        if state not in triggers:
            if state != 'OK' and self.tracking(self.state.get(key)) and self.too_soon(key, attrs, state, False):
                return
            self.clear(key, state, attrs)
            return
        reason = self.blocked(attrs)
        if reason:
            log.debug(f'{key} is {state} but {reason}, skipping')
            return
        self.problem(key, attrs, state)

    def safe(self, func, *args):
        try:
            func(*args)
        except Exception:
            self.failures += 1
            log.exception(f'Failed handling {func.__name__}')

    def on_event(self, event):
        if event.get('type') != 'StateChange' or not event.get('service'):
            return
        log.debug(f"Event for {event['host']}!{event['service']}")
        attrs = self.icinga.service(event['host'], event['service'])
        if attrs:
            self.process(attrs)

    def adopt(self):
        for task in self.phorge.open_tasks():
            if is_storm_task(task):
                if self.state.storm is None:
                    log.info(f"Adopted alert storm task T{task['id']}")
                    self.state.set_storm(task['id'])
                continue
            key = task_key(task)
            if key and not self.state.get(key):
                self.remember(key, task)

    def prepare(self):
        if not self.adopted:
            self.adopt()
            self.adopted = True

    def beat(self):
        if self.failures:
            log.warning(f'{self.failures} problems during the sync, not marking it healthy')
            return
        write_heartbeat(self.config['heartbeat_file'])

    def reconcile(self):
        log.debug('Syncing with current Icinga state')
        self.failures = 0
        seen = set()
        for attrs in self.icinga.problems():
            seen.add(f"{attrs['host_name']}!{attrs['name']}")
            self.safe(self.process, attrs)
        for key, entry in list(self.state.services.items()):
            if not self.tracking(entry) or key in seen:
                continue
            host, _, name = key.partition('!')
            attrs = self.icinga.service(host, name)
            if attrs:
                self.safe(self.process, attrs)
            else:
                log.warning(f'{key} no longer exists in Icinga')
                self.safe(self.clear, key, 'GONE')
        self.close_due()
        self.last_reconcile = time.monotonic()
        self.beat()

    def run(self):
        delay = self.config['reconnect_min']
        while True:
            try:
                self.prepare()
                self.reconcile()
                for event in self.icinga.events():
                    delay = self.config['reconnect_min']
                    self.safe(self.on_event, event)
                    if time.monotonic() - self.last_reconcile > self.config['reconcile_interval']:
                        self.reconcile()
            except (OSError, ValueError, PhorgeError) as error:
                source = 'Phorge' if isinstance(error, PhorgeError) else 'Icinga'
                log.error(f'{source} connection problem: {error}')
                time.sleep(delay)
                delay = min(delay * 2, self.config['reconnect_max'])
                continue
            log.debug('Event stream ended, reconnecting')
            delay = self.config['reconnect_min']
            time.sleep(delay)


def clean_text(text):
    return ' '.join(CONTROL.sub(' ', str(text)).split())


def truncate(text, limit=IRC_LIMIT):
    data = text.encode('utf-8')
    if len(data) <= limit:
        return text
    return data[:limit - 3].decode('utf-8', 'ignore').rstrip() + '...'


def format_notification(event):
    host = clean_text(event.get('host') or '')
    if not host:
        return None
    result = event.get('check_result') or {}
    kind = clean_text(event.get('notification_type') or 'NOTIFICATION').upper()
    try:
        code = int(result.get('state'))
    except (TypeError, ValueError):
        code = None
    output = clean_text(result.get('output') or '')
    service = clean_text(event.get('service') or '')
    if service:
        line = f"{kind} - {service} on {host} is {STATES.get(code, 'UNKNOWN')}: {output}"
    else:
        state = 'UNKNOWN' if code is None else 'UP' if code == 0 else 'DOWN'
        line = f'{kind} - Host {host} is {state}: {output}'
    extra = clean_text(f"{event.get('author') or ''} {event.get('text') or ''}")
    if extra:
        line = f'{line} {extra}'
    return truncate(line.strip())


def parse_irc(line):
    prefix = None
    if line.startswith(':'):
        prefix, _, line = line[1:].partition(' ')
    if ' :' in line:
        head, _, trailing = line.partition(' :')
        params = head.split()
        params.append(trailing)
    else:
        params = line.split()
    if not params:
        return prefix, '', []
    return prefix, params[0].upper(), params[1:]


class IrcRelay:
    def __init__(self, config):
        self.cfg = config['irc']
        self.icinga = Icinga(config['icinga'], self.cfg['queue'])
        self.stream_timeout = config['icinga']['stream_timeout']
        self.proxy = Proxy(self.cfg['proxy']) if self.cfg['proxy'] else None
        self.users = set(self.cfg['notify_users'])
        self.outbox = deque(maxlen=self.cfg['queue_size'])
        self.stream_seen = time.monotonic()

    def wanted(self, event):
        if event.get('type') != 'Notification':
            return False
        if not self.users:
            return True
        users = event.get('users')
        return isinstance(users, list) and any(name in self.users for name in users)

    def handle(self, event):
        if not self.wanted(event):
            log.debug(f"Ignored a notification for {event.get('users')}")
            return
        text = format_notification(event)
        if text:
            self.push(text)

    def push(self, text):
        if len(self.outbox) == self.outbox.maxlen:
            log.warning('The IRC outbox is full, dropping the oldest message')
        self.outbox.append(text)

    def healthy(self):
        return time.monotonic() - self.stream_seen < 3 * self.stream_timeout

    def pump(self):
        delay = self.cfg['reconnect_min']
        while True:
            try:
                for event in self.icinga.events(['Notification']):
                    self.stream_seen = time.monotonic()
                    delay = self.cfg['reconnect_min']
                    try:
                        self.handle(event)
                    except Exception:
                        log.exception('Could not handle a notification')
            except (OSError, ValueError) as error:
                log.error(f'Icinga notification stream problem: {error}')
                time.sleep(delay)
                delay = min(delay * 2, self.cfg['reconnect_max'])
                continue
            self.stream_seen = time.monotonic()
            delay = self.cfg['reconnect_min']
            time.sleep(1)

    def run(self):
        delay = self.cfg['reconnect_min']
        while True:
            link = IrcLink(self)
            try:
                link.run()
            except OSError as error:
                log.warning(f'IRC connection problem: {error}')
            if link.joined:
                delay = self.cfg['reconnect_min']
            log.info(f'Reconnecting to IRC in {delay}s')
            time.sleep(delay)
            delay = min(delay * 2, self.cfg['reconnect_max'])


class IrcLink:
    def __init__(self, relay):
        self.relay = relay
        self.cfg = relay.cfg
        self.nick = self.cfg['nick']
        self.username = self.cfg['username']
        self.password = self.cfg['password']
        self.use_sasl = bool(self.password) and self.cfg['sasl']
        self.waiting = {name.lower() for name in self.cfg['channels']}
        self.joined = False
        self.buffer = b''
        self.sock = None
        self.last_read = time.monotonic()
        self.pinged = None

    def run(self):
        cfg = self.cfg
        server, port = cfg['server'], cfg['port']
        if self.relay.proxy:
            log.info(f'Connecting to {server}:{port} through {self.relay.proxy}')
        else:
            log.info(f'Connecting to {server}:{port}')
        raw = open_socket(server, port, 30, self.relay.proxy)
        try:
            sock = ssl.create_default_context().wrap_socket(raw, server_hostname=server) if cfg['ssl'] else raw
        except Exception:
            raw.close()
            raise
        try:
            sock.settimeout(POLL_SECONDS)
            self.sock = sock
            self.talk()
        finally:
            with contextlib.suppress(OSError):
                sock.close()

    def send(self, line):
        shown = 'AUTHENTICATE ***' if line.startswith('AUTHENTICATE ') else line
        log.debug(f'>> {shown}')
        self.sock.sendall(f'{line}\r\n'.encode('utf-8'))

    def talk(self):
        cfg = self.cfg
        started = time.monotonic()
        last_beat = next_post = 0.0
        if self.use_sasl:
            self.send('CAP REQ :sasl')
        self.send(f'NICK {self.nick}')
        self.send(f"USER {self.username} 0 * :{cfg['realname']}")
        while True:
            self.fill()
            now = time.monotonic()
            if not self.joined:
                if now - started > REGISTER_TIMEOUT:
                    raise ConnectionError('registration timed out')
            else:
                if self.relay.outbox and now >= next_post:
                    self.post()
                    next_post = now + cfg['message_interval']
                if now - last_beat >= cfg['heartbeat_interval'] and self.relay.healthy():
                    write_heartbeat(cfg['heartbeat_file'])
                    last_beat = now
            self.keepalive(now)

    def fill(self):
        try:
            chunk = self.sock.recv(4096)
        except TimeoutError:
            return
        if not chunk:
            raise ConnectionError('server closed the connection')
        self.last_read = time.monotonic()
        self.pinged = None
        self.buffer += chunk
        while True:
            line, found, rest = self.buffer.partition(b'\n')
            if not found:
                break
            self.buffer = rest
            self.handle(line.decode('utf-8', 'replace').rstrip('\r'))
        if len(self.buffer) > 8192:
            raise ConnectionError('server sent a line that is too long')

    def keepalive(self, now):
        if self.pinged is not None:
            if now - self.pinged > self.cfg['ping_interval']:
                raise ConnectionError('ping timeout')
        elif now - self.last_read > self.cfg['ping_interval']:
            self.send('PING :keepalive')
            self.pinged = now

    def post(self):
        text = self.relay.outbox.popleft()
        try:
            for channel in self.cfg['channels']:
                self.send(f'PRIVMSG {channel} :{text}')
        except OSError:
            self.relay.outbox.appendleft(text)
            raise
        log.debug(f'Relayed {text}')

    def check_failure(self, command, params):
        if command in SASL_FAILED:
            raise ConnectionError(f'SASL failed ({command})')
        if command == '433':
            raise ConnectionError(f'the nickname {self.nick} is already in use')
        if command in JOIN_FAILED and len(params) >= 2:
            raise ConnectionError(f'cannot join {params[1]} ({command})')
        if command == 'KICK' and len(params) >= 2 and params[1].lower() == self.nick.lower():
            raise ConnectionError(f'kicked from {params[0]}')
        if command == 'ERROR':
            raise ConnectionError(' '.join(params))

    def handle(self, line):
        log.debug(f'<< {line}')
        _, command, params = parse_irc(line)
        self.check_failure(command, params)
        if command == 'PING':
            self.send(f"PONG :{params[-1] if params else ''}")
        elif command == 'CAP' and len(params) >= 3:
            if params[1] == 'ACK' and 'sasl' in params[2].split():
                self.send('AUTHENTICATE PLAIN')
            elif params[1] == 'NAK':
                log.warning('The server refused SASL')
                self.send('CAP END')
        elif command == 'AUTHENTICATE' and params and params[0] == '+':
            blob = f'{self.username}\0{self.username}\0{self.password}'
            self.send(f'AUTHENTICATE {base64.b64encode(blob.encode()).decode()}')
        elif command == '903':
            self.send('CAP END')
        elif command == '001':
            log.info(f'Registered as {self.nick}')
            if self.password and not self.use_sasl:
                self.send(f'PRIVMSG NickServ :IDENTIFY {self.username} {self.password}')
            for channel in self.cfg['channels']:
                self.send(f'JOIN {channel}')
        elif command == '366' and len(params) >= 2:
            self.waiting.discard(params[1].lower())
            if not self.waiting and not self.joined:
                self.joined = True
                log.info(f"Joined {', '.join(self.cfg['channels'])}")


def grafana_messages(content, limit):
    message = content['message']
    if not isinstance(message, str):
        raise TypeError('message is not a string')
    lines = [truncate(clean_text(line)) for line in message.splitlines()]
    lines = [line for line in lines if line]
    if len(lines) <= limit:
        return lines
    return [*lines[:limit], f'[Grafana] {len(lines) - limit} more lines not shown']


class HookServer(http.server.ThreadingHTTPServer):
    daemon_threads = True

    def server_bind(self):
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]


class GrafanaHook:
    def __init__(self, config, relay):
        self.cfg = config['grafana']
        self.relay = relay
        self.server = None

    def receive(self, path, headers, rfile):
        if path != '/':
            return 404
        try:
            length = int(headers.get('Content-Length', ''))
        except ValueError:
            return 411
        if length < 0:
            return 400
        if length > self.cfg['max_body']:
            return 413
        try:
            content = json.loads(rfile.read(length))
            messages = grafana_messages(content, self.cfg['max_lines'])
        except OSError as error:
            log.warning(f'Could not read the Grafana request: {error}')
            return 408
        except (ValueError, KeyError, TypeError) as error:
            log.warning(f'Bad Grafana request: {error!r}')
            return 400
        for message in messages:
            self.relay.push(message)
        log.info(f'Queued {len(messages)} Grafana messages')
        return 204

    def handler(self):
        hook = self

        class Handler(http.server.BaseHTTPRequestHandler):
            timeout = 10

            def do_POST(self):
                status = hook.receive(self.path, self.headers, self.rfile)
                self.send_response(status)
                self.send_header('Content-Length', '0')
                self.end_headers()

            def log_message(self, *args):
                log.debug(f'Grafana listener: {args}')

        return Handler

    def serve(self):
        host, port = self.cfg['host'], self.cfg['port']
        with HookServer((host, port), self.handler()) as server:
            self.server = server
            log.info(f'Listening for Grafana on {host}:{port}')
            server.serve_forever()


def supervise(name, target):
    delay = RESTART_MIN
    while True:
        started = time.monotonic()
        try:
            target()
            return
        except Exception:
            log.exception(f'{name} crashed')
        if time.monotonic() - started > RESTART_MAX:
            delay = RESTART_MIN
        log.info(f'Restarting {name} in {delay}s')
        time.sleep(delay)
        delay = min(delay * 2, RESTART_MAX)


def start_thread(name, target):
    threading.Thread(target=supervise, args=(name, target), name=name, daemon=True).start()


def main():
    parser = argparse.ArgumentParser(description='Icinga to IRC and Phorge bot')
    parser.add_argument('-c', '--config', default='config.json')
    parser.add_argument('-v', '--verbose', action='store_true')
    args = parser.parse_args()

    config = load_config(args.config)
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else getattr(logging, config['log_level'].upper(), logging.INFO),
        format='{asctime} {levelname} {threadName} {message}',
        style='{',
    )
    relay = IrcRelay(config)
    start_thread('irc-events', relay.pump)
    start_thread('irc', relay.run)
    start_thread('grafana', GrafanaHook(config, relay).serve)
    with contextlib.suppress(KeyboardInterrupt):
        supervise('phorge', lambda: Bot(config).run())


if __name__ == '__main__':
    main()
