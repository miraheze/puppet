#!/usr/bin/env python3

import argparse
import base64
import contextlib
import json
import logging
import os
import re
import ssl
import sys
import time
import urllib.parse
import urllib.request

log = logging.getLogger('taskbot')

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

REQUIRED = {
    'icinga': [
        'url', 'username', 'password', 'ca_file', 'queue', 'timeout', 'stream_timeout',
    ],
    'phorge': ['url', 'api_token', 'timeout', 'retries', 'proxy'],
    'triggers': ['critical', 'any'],
    'priorities': ['WARNING', 'CRITICAL', 'UNKNOWN'],
    'icingaweb_url': None,
    'skip_in_downtime': None,
    'close_after_recovery_seconds': None,
    'close_status': None,
    'grace_minutes': None,
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


def invalid_values(config):
    problems = []
    for key in ('grace_minutes', 'storm_window_minutes', 'reopen_hours'):
        value = config[key]
        if isinstance(value, bool) or not isinstance(value, (int, float)) or value < 0:
            problems.append(f'{key} must be a number of 0 or more')
    delay = config['close_after_recovery_seconds']
    if delay is not None and (isinstance(delay, bool) or not isinstance(delay, (int, float)) or delay < 0):
        problems.append('close_after_recovery_seconds must be null or a number of 0 or more')
    limit = config['storm_limit']
    if isinstance(limit, bool) or not isinstance(limit, int) or limit < 1:
        problems.append('storm_limit must be a whole number of 1 or more')
    problems.extend(
        f"priorities.{state} must be one of {', '.join(PRIORITIES)}"
        for state, keyword in config['priorities'].items()
        if keyword not in PRIORITIES
    )
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

    def has_human_comment(self, task):
        bot = self.whoami()
        params = {'objectIdentifier': f'T{task}', 'limit': 100}
        while True:
            result = self.call('transaction.search', params)
            for transaction in result['data']:
                comments = transaction.get('comments') or []
                if transaction.get('authorPHID') != bot and any(not comment.get('removed') for comment in comments):
                    return True
            after = (result.get('cursor') or {}).get('after')
            if not after:
                return False
            params = {**params, 'after': after}

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
    def __init__(self, config):
        self.url = config['url'].rstrip('/')
        self.queue = config['queue']
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
        self.services = {}
        self.created = []
        self.storm = None
        self.storm_recovered = None
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
        self.save()

    def set_storm_recovered(self, when):
        self.storm_recovered = when
        self.save()


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

    def hold_off(self, attrs):
        host = attrs.get('host') or {}
        if self.config['skip_in_downtime']:
            if attrs.get('downtime_depth', 0) > 0:
                return 'in downtime'
            if host.get('downtime_depth', 0) > 0:
                return 'its host is in downtime'
        if host.get('state', 0) != 0:
            return 'its host is down'
        age = time.time() - failing_since(attrs)
        if age < self.config['grace_minutes'] * 60:
            return f'it has only been failing for {int(age // 60)} minutes'
        return None

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

    def closing_notice(self):
        delay = self.config['close_after_recovery_seconds']
        if not delay:
            return ''
        return f' This task will be closed automatically in {describe_seconds(delay)} unless someone comments on it.'

    def storm_clear(self, key, state, entry):
        task = entry['task']
        last = not self.storm_members(task, skip=key)
        if state == 'OK':
            text = f'`{key}` recovered.'
        else:
            text = f'`{key}` is now **{state}**, which is not an alert state.'
        if last:
            text += self.closing_notice()
        transactions = [{'type': 'comment', 'value': text}]
        closing = last and self.config['close_after_recovery_seconds'] == 0
        if closing:
            transactions.append({'type': 'status', 'value': self.config['close_status']})
        self.phorge.edit(transactions, task)
        self.state.put(key, {**entry, 'active': False, 'state': state})
        if closing:
            log.info(f'Closed alert storm task T{task}')
            self.state.set_storm(None)
        elif last and self.config['close_after_recovery_seconds']:
            self.state.set_storm_recovered(time.time())

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
                self.storm_note(key, state, entry)
                return
            entry = None
        if entry and self.phorge.is_open(entry['task']):
            self.update(key, entry, attrs, state)
            return
        if entry and self.reopen(key, entry, attrs, state):
            return
        found = self.phorge.find(lambda other: task_key(other) == key)
        if found:
            self.update(key, self.remember(key, found), attrs, state)
            return
        self.create_task(key, attrs, state)

    def clear(self, key, state):
        entry = self.state.get(key)
        if not entry or not entry.get('active'):
            return
        if entry.get('storm'):
            self.storm_clear(key, state, entry)
            return
        delay = self.config['close_after_recovery_seconds']
        if state == 'OK':
            text = 'Recovered, the service is back to **OK**.' + self.closing_notice()
        else:
            text = f'Now **{state}**, which is not an alert state for this service.'
        closing = state == 'OK' and delay == 0
        transactions = [{'type': 'comment', 'value': text}]
        if closing:
            transactions.append({'type': 'status', 'value': self.config['close_status']})
        self.phorge.edit(transactions, entry['task'])
        log.info(f"Updated T{entry['task']} for {key} ({state})")
        updated = {
            'task': entry['task'],
            'active': False,
            'state': state,
            'alert': entry.get('alert') or entry.get('state'),
        }
        if closing:
            updated['closed'] = time.time()
        elif state == 'OK' and delay:
            updated['recovered'] = time.time()
        self.state.put(key, updated)

    def close_unless_handled(self, task):
        if not self.phorge.is_open(task):
            return False
        if self.phorge.has_human_comment(task):
            note = 'The service has recovered, but someone commented on this task, so it stays open for a person to decide.'
            self.phorge.edit([{'type': 'comment', 'value': note}], task)
            log.info(f'Left T{task} open because someone commented on it')
            return False
        delay = describe_seconds(self.config['close_after_recovery_seconds'])
        note = f'Closing automatically, the service has been back to **OK** for {delay} and nobody commented.'
        self.phorge.edit([
            {'type': 'comment', 'value': note},
            {'type': 'status', 'value': self.config['close_status']},
        ], task)
        log.info(f'Closed T{task} after it recovered')
        return True

    def close_recovered(self, key, entry):
        settled = {name: value for name, value in entry.items() if name != 'recovered'}
        if self.close_unless_handled(entry['task']):
            settled['closed'] = time.time()
        self.state.put(key, settled)

    def close_storm(self, task):
        self.close_unless_handled(task)
        self.state.set_storm(None)

    def close_due(self):
        delay = self.config['close_after_recovery_seconds']
        if not delay:
            return
        now = time.time()
        for key, entry in list(self.state.services.items()):
            recovered = entry.get('recovered')
            if entry.get('active') or recovered is None or now - recovered < delay:
                continue
            self.safe(self.close_recovered, key, entry)
        task = self.state.storm
        recovered = self.state.storm_recovered
        if task is not None and recovered is not None and now - recovered >= delay and not self.storm_members(task):
            self.safe(self.close_storm, task)

    def process(self, attrs):
        key = f"{attrs['host_name']}!{attrs['name']}"
        mode = (attrs.get('vars') or {}).get('phorge_task')
        if mode not in self.triggers:
            log.debug(f'{key} does not set phorge_task, skipping')
            return
        if int(attrs.get('state_type', 1)) != 1:
            log.debug(f'{key} is in a soft state, skipping')
            return
        if attrs.get('flapping'):
            log.debug(f'{key} is flapping, skipping')
            return
        state = STATES.get(int(attrs['state']), 'UNKNOWN')
        if state not in self.triggers[mode]:
            self.clear(key, state)
            return
        reason = self.hold_off(attrs)
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
        try:
            with open(self.config['heartbeat_file'], 'w') as handle:
                handle.write(f'{int(time.time())}\n')
        except OSError as error:
            log.error(f'Could not write the heartbeat file: {error}')

    def reconcile(self):
        log.debug('Syncing with current Icinga state')
        self.failures = 0
        seen = set()
        for attrs in self.icinga.problems():
            seen.add(f"{attrs['host_name']}!{attrs['name']}")
            self.safe(self.process, attrs)
        for key, entry in list(self.state.services.items()):
            if not entry.get('active') or key in seen:
                continue
            host, _, name = key.partition('!')
            attrs = self.icinga.service(host, name)
            if attrs:
                self.safe(self.process, attrs)
            else:
                log.warning(f'{key} no longer exists in Icinga')
                self.state.put(key, {**entry, 'active': False, 'state': 'GONE'})
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
