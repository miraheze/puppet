#!/usr/bin/env python3

import argparse
import base64
import contextlib
import json
import logging
import os
import ssl
import sys
import time
import urllib.parse
import urllib.request

log = logging.getLogger('taskbot')

STATES = {0: 'OK', 1: 'WARNING', 2: 'CRITICAL', 3: 'UNKNOWN'}

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
]

REQUIRED = {
    'icinga': [
        'url', 'username', 'password', 'ca_file', 'queue', 'timeout', 'stream_timeout',
    ],
    'phorge': ['url', 'api_token', 'timeout', 'retries', 'proxy'],
    'triggers': ['critical', 'any'],
    'priorities': ['WARNING', 'CRITICAL', 'UNKNOWN'],
    'icingaweb_url': None,
    'skip_in_downtime': None,
    'close_on_recovery': None,
    'close_status': None,
    'reconcile_interval': None,
    'reconnect_min': None,
    'reconnect_max': None,
    'state_file': None,
    'dry_run': None,
    'log_level': None,
}


class PhorgeError(Exception):
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


class Phorge:
    def __init__(self, config, dry_run=False):
        self.url = config['url'].rstrip('/')
        self.token = config['api_token']
        self.timeout = config['timeout']
        self.retries = max(1, config['retries'])
        self.phids = {}
        self.dry_run = dry_run
        self.opener = build_opener(config['proxy'])

    def call(self, method, params=None):
        fields = [('api.token', self.token), *flatten(params or {})]
        request = urllib.request.Request(
            f'{self.url}/api/{method}',
            data=urllib.parse.urlencode(fields).encode(),
        )
        failure = None
        for attempt in range(1, self.retries + 1):
            log.debug(f'Calling {method}, attempt {attempt} of {self.retries}')
            try:
                with self.opener.open(request, timeout=self.timeout) as response:
                    body = json.load(response)
            except (OSError, ValueError) as error:
                failure = PhorgeError(f'{method} request failed: {error}')
                log.debug(str(failure))
                if attempt < self.retries:
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

    def edit(self, transactions, task=None):
        params = {'transactions': transactions}
        if task is not None:
            params['objectIdentifier'] = task
        if self.dry_run:
            log.info(f'Dry run, would send {json.dumps(params)}')
            return {'object': {'id': task or 0}}
        return self.call('maniphest.edit', params)

    def create(self, title, description, priority, slugs):
        transactions = [
            {'type': 'title', 'value': title},
            {'type': 'description', 'value': description},
        ]
        if priority:
            transactions.append({'type': 'priority', 'value': priority})
        phids = self.resolve(slugs)
        if phids:
            transactions.append({'type': 'projects.add', 'value': phids})
        return self.edit(transactions)['object']['id']

    def is_open(self, task):
        result = self.call('maniphest.search', {
            'queryKey': 'open',
            'constraints': {'ids': [task]},
        })
        return bool(result['data'])


class Icinga:
    def __init__(self, config):
        self.url = config['url'].rstrip('/')
        self.queue = config['queue']
        self.timeout = config['timeout']
        self.stream_timeout = config['stream_timeout']
        login = f"{config['username']}:{config['password']}".encode()
        self.headers = {
            'Authorization': f'Basic {base64.b64encode(login).decode()}',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
        }
        context = None
        if self.url.startswith('https'):
            context = ssl.create_default_context(cafile=config['ca_file'] or None)
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
        with self.request('/v1/objects/services', body, self.timeout, 'GET') as response:
            return json.load(response)['results']

    def service(self, host, name):
        results = self.query({
            'filter': 'service.host_name == host && service.name == name',
            'filter_vars': {'host': host, 'name': name},
            'attrs': ATTRS,
        })
        return results[0]['attrs'] if results else None

    def events(self):
        body = {'queue': self.queue, 'types': ['StateChange']}
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
        self.data = {}
        with contextlib.suppress(FileNotFoundError), open(path) as handle:
            self.data = json.load(handle)

    def get(self, key):
        return self.data.get(key)

    def put(self, key, entry):
        self.data[key] = entry
        if not self.persist:
            return
        temp = f'{self.path}.tmp'
        with open(temp, 'w') as handle:
            json.dump(self.data, handle, indent=2, sort_keys=True)
        os.replace(temp, self.path)


def check_output(attrs):
    result = attrs.get('last_check_result') or {}
    text = (result.get('output') or '').strip().replace('```', "'''")
    return text[:1500] or 'No output.'


class Bot:
    def __init__(self, config):
        self.config = config
        self.triggers = config['triggers']
        self.icinga = Icinga(config['icinga'])
        self.phorge = Phorge(config['phorge'], config['dry_run'])
        self.state = State(config['state_file'], not config['dry_run'])
        self.last_reconcile = 0.0

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
        lines.extend(['', time.strftime('Reported at %Y-%m-%d %H:%M UTC', time.gmtime())])
        return '\n'.join(lines)

    def problem(self, key, attrs, state):
        entry = self.state.get(key)
        if entry and entry.get('active') and entry.get('state') == state:
            return
        if entry and self.phorge.is_open(entry['task']):
            task = entry['task']
            lead = 'Now' if entry.get('active') else 'Alerting again,'
            text = f"{lead} **{state}**.\n\n```\n{check_output(attrs)}\n```"
            self.phorge.edit([{'type': 'comment', 'value': text}], task)
            log.info(f'Commented on T{task} for {key} ({state})')
        else:
            priority = self.config['priorities'][state]
            slugs = attrs['vars'].get('phorge_projects') or []
            task = self.phorge.create(self.title(attrs, state), self.description(attrs, state), priority, slugs)
            log.info(f'Created T{task} for {key} ({state})')
        self.state.put(key, {'task': task, 'active': True, 'state': state})

    def clear(self, key, state):
        entry = self.state.get(key)
        if not entry or not entry.get('active'):
            return
        if state == 'OK':
            text = 'Recovered, the service is back to **OK**.'
        else:
            text = f'Now **{state}**, which is not an alert state for this service.'
        transactions = [{'type': 'comment', 'value': text}]
        if state == 'OK' and self.config['close_on_recovery']:
            transactions.append({'type': 'status', 'value': self.config['close_status']})
        self.phorge.edit(transactions, entry['task'])
        self.state.put(key, {'task': entry['task'], 'active': False, 'state': state})
        log.info(f"Updated T{entry['task']} for {key} ({state})")

    def process(self, attrs):
        key = f"{attrs['host_name']}!{attrs['name']}"
        mode = (attrs.get('vars') or {}).get('phorge_task')
        if mode not in self.triggers:
            log.debug(f'{key} does not set phorge_task, skipping')
            return
        if int(attrs.get('state_type', 1)) != 1:
            log.debug(f'{key} is in a soft state, skipping')
            return
        state = STATES.get(int(attrs['state']), 'UNKNOWN')
        if state in self.triggers[mode]:
            if self.config['skip_in_downtime'] and attrs.get('downtime_depth', 0) > 0:
                log.debug(f'{key} is {state} but in downtime, skipping')
                return
            self.problem(key, attrs, state)
        else:
            self.clear(key, state)

    def safe(self, func, *args):
        try:
            func(*args)
        except Exception:
            log.exception(f'Failed handling {func.__name__}')

    def on_event(self, event):
        if event.get('type') != 'StateChange' or not event.get('service'):
            return
        log.debug(f"Event for {event['host']}!{event['service']}")
        attrs = self.icinga.service(event['host'], event['service'])
        if attrs:
            self.process(attrs)

    def reconcile(self):
        log.info('Syncing with current Icinga state')
        seen = set()
        body = {'filter': 'service.state != 0 && service.state_type == 1', 'attrs': ATTRS}
        for result in self.icinga.query(body):
            attrs = result['attrs']
            seen.add(f"{attrs['host_name']}!{attrs['name']}")
            self.safe(self.process, attrs)
        for key, entry in list(self.state.data.items()):
            if not entry.get('active') or key in seen:
                continue
            host, _, name = key.partition('!')
            attrs = self.icinga.service(host, name)
            if attrs:
                self.safe(self.process, attrs)
            else:
                log.warning(f'{key} no longer exists in Icinga')
                self.state.put(key, {'task': entry['task'], 'active': False, 'state': 'GONE'})
        self.last_reconcile = time.monotonic()

    def run(self):
        delay = self.config['reconnect_min']
        while True:
            try:
                self.reconcile()
                for event in self.icinga.events():
                    delay = self.config['reconnect_min']
                    self.safe(self.on_event, event)
                    if time.monotonic() - self.last_reconcile > self.config['reconcile_interval']:
                        self.reconcile()
            except (OSError, ValueError) as error:
                log.error(f'Icinga connection problem: {error}')
                time.sleep(delay)
                delay = min(delay * 2, self.config['reconnect_max'])
                continue
            log.info('Event stream ended, reconnecting')
            delay = self.config['reconnect_min']
            time.sleep(delay)


def main():
    parser = argparse.ArgumentParser(description='Icinga to Phorge task bot')
    parser.add_argument('-c', '--config', default='config.json')
    parser.add_argument('-v', '--verbose', action='store_true')
    args = parser.parse_args()

    config = load_config(args.config)
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else getattr(logging, config['log_level'].upper(), logging.INFO),
        format='{asctime} {levelname} {message}',
        style='{',
    )
    with contextlib.suppress(KeyboardInterrupt):
        Bot(config).run()


if __name__ == '__main__':
    main()
