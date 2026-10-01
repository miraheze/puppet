import contextlib
import copy
import hashlib
import http.server
import json
import logging
import re
import shutil
import ssl
import subprocess
import sys
import threading
import time
import types
import urllib.parse
import urllib.request
from pathlib import Path

import pytest

import taskbot
from taskbot import (
    Bot,
    Icinga,
    Phorge,
    PhorgeError,
    PhorgeUncertain,
    State,
    build_opener,
    check_output,
    describe_seconds,
    flatten,
    invalid_values,
    is_storm_task,
    load_config,
    missing_keys,
    task_key,
    title_state,
)

MODULE = Path(__file__).resolve().parents[2]
CA_FILE = Path(__file__).resolve().parent / 'icinga-ca.crt'
TEMPLATE = MODULE / 'templates' / 'taskbot' / 'config.json.epp'
SYSTEMD = MODULE / 'templates' / 'initscripts' / 'taskbot.systemd.epp'
MANIFEST = MODULE / 'manifests' / 'taskbot.pp'
MONITORING = MODULE.parent / 'monitoring' / 'manifests'

ICINGA_CA_SHA256 = 'c83902a9260b8ad2cbd7c79b5946ad1adc770723f38e0313bf2d1c560555da57'

BASE_CONFIG = {
    'icinga': {
        'url': 'http://127.0.0.1:5665',
        'username': 'taskbot',
        'password': 'secret',
        'ca_file': '',
        'queue': 'taskbot',
        'timeout': 5,
        'stream_timeout': 5,
    },
    'phorge': {
        'url': 'https://phorge.example.org',
        'api_token': 'api-token',
        'timeout': 5,
        'retries': 3,
        'proxy': None,
    },
    'triggers': {'critical': ['CRITICAL'], 'any': ['WARNING', 'CRITICAL']},
    'priorities': {'WARNING': 'medium', 'CRITICAL': 'high', 'UNKNOWN': 'medium'},
    'icingaweb_url': 'https://icinga.example.org',
    'skip_in_downtime': True,
    'close_after_recovery_seconds': None,
    'close_status': 'resolved',
    'grace_minutes': 0,
    'storm_limit': 1000,
    'storm_window_minutes': 10,
    'reopen_hours': 24,
    'reconcile_interval': 900,
    'reconnect_min': 5,
    'reconnect_max': 40,
    'state_file': '/nonexistent/state.json',
    'heartbeat_file': '/nonexistent/last_sync',
    'dry_run': False,
    'log_level': 'INFO',
}

NOW = 1_000_000.0


def make_config(tmp_path, **changes):
    config = copy.deepcopy(BASE_CONFIG)
    config['state_file'] = str(tmp_path / 'state.json')
    config['heartbeat_file'] = str(tmp_path / 'last_sync')
    config.update(changes)
    return config


def make_bot(tmp_path, **changes):
    bot = Bot(make_config(tmp_path, **changes))
    bot.phorge = FakePhorge()
    bot.icinga = FakeIcinga()
    return bot


def make_service(host='mw1', name='mw1 Disk', state=2, mode='critical', details=None, **changes):
    attrs = {
        'name': name,
        'display_name': 'Disk',
        'host_name': host,
        'vars': {'phorge_task': mode, 'phorge_projects': []} if mode else {},
        'state': float(state),
        'state_type': 1.0,
        'downtime_depth': 0.0,
        'notes_url': '',
        'last_check_result': {'output': 'DISK CRITICAL - free space: / 1 GB'},
        'last_state_ok': 0.0,
        'last_state_change': 0.0,
        'flapping': False,
        'host': {'state': 0.0, 'downtime_depth': 0.0} if details is None else details,
    }
    attrs.update(changes)
    return attrs


def state_change(host='mw1', name='mw1 Disk', state=2):
    return {'type': 'StateChange', 'host': host, 'service': name, 'state': state, 'state_type': 1}


def comments(phorge):
    return [
        transaction['value']
        for call in phorge.calls if call[0] == 'edit'
        for transaction in call[2] if transaction['type'] == 'comment'
    ]


class Stop(BaseException):
    pass


def then(outcome, *events):
    yield from events
    raise outcome


def marker(key):
    return f'Icinga service: `{key}`'


class FakePhorge:
    def __init__(self):
        self.calls = []
        self.tasks = {}
        self.next_id = 1
        self.create_errors = []
        self.read_errors = []
        self.lost_replies = 0
        self.human_comments = set()

    def add_task(self, title='Disk on mw1 is CRITICAL', key='mw1!mw1 Disk', status='open', priority='high', storm=False):
        task = self.next_id
        self.next_id += 1
        description = 'Icinga alert storm summary' if storm else f'Something happened.\n\n{marker(key)}\n'
        self.tasks[task] = {
            'id': task,
            'title': title,
            'description': description,
            'status': status,
            'priority': taskbot.PRIORITIES[priority],
        }
        return task

    def close(self, task, status='resolved'):
        self.tasks[task]['status'] = status

    def close_all(self):
        for task in self.tasks:
            self.close(task)

    def create(self, title, description, priority, slugs, matches):
        if self.create_errors:
            raise self.create_errors.pop(0)
        task = self.add_task(title=title, key='unused', priority=priority or 'medium')
        self.tasks[task]['description'] = description
        self.calls.append((
            'create',
            {'title': title, 'description': description, 'priority': priority, 'slugs': slugs, 'matches': matches},
        ))
        if self.lost_replies:
            self.lost_replies -= 1
            raise PhorgeUncertain('the reply was lost')
        return task

    def edit(self, transactions, task=None):
        self.calls.append(('edit', task, transactions))
        info = self.tasks.get(task)
        for transaction in transactions if info else []:
            if transaction['type'] == 'title':
                info['title'] = transaction['value']
            elif transaction['type'] == 'priority':
                info['priority'] = taskbot.PRIORITIES[transaction['value']]
            elif transaction['type'] == 'status':
                info['status'] = transaction['value']
        return {'object': {'id': task}}

    def is_open(self, task):
        self.check_reads()
        return self.tasks.get(task, {}).get('status') == 'open'

    def details(self, task):
        self.check_reads()
        info = self.tasks.get(task)
        if info is None:
            return None
        return {'title': info['title'], 'status': info['status'], 'priority': info['priority']}

    def open_tasks(self):
        self.check_reads()
        for info in list(self.tasks.values()):
            if info['status'] == 'open':
                yield {'id': info['id'], 'fields': {'name': info['title'], 'description': {'raw': info['description']}}}

    def find(self, matches):
        return next((task for task in self.open_tasks() if matches(task)), None)

    def has_human_comment(self, task):
        self.check_reads()
        return task in self.human_comments

    def check_reads(self):
        if self.read_errors:
            raise self.read_errors.pop(0)

    def created(self):
        return [call[1] for call in self.calls if call[0] == 'create']


class FakeIcinga:
    def __init__(self):
        self.services = {}
        self.streams = []
        self.syncs = 0
        self.query_errors = []

    def add(self, attrs):
        self.services[(attrs['host_name'], attrs['name'])] = attrs

    def problems(self):
        self.syncs += 1
        if self.query_errors:
            raise self.query_errors.pop(0)
        return [
            attrs for attrs in self.services.values()
            if attrs['state'] != 0 and attrs['state_type'] == 1
        ]

    def service(self, host, name):
        return self.services.get((host, name))

    def events(self):
        outcome = self.streams.pop(0)
        if isinstance(outcome, BaseException):
            raise outcome
        yield from outcome


class Clock:
    def __init__(self, ticks=None, now=NOW):
        self.sleeps = []
        self.ticks = None if ticks is None else iter(ticks)
        self.now = now

    def monotonic(self):
        return 0.0 if self.ticks is None else next(self.ticks)

    def time(self):
        return self.now

    def install(self, monkeypatch):
        monkeypatch.setattr(taskbot, 'time', types.SimpleNamespace(
            sleep=self.sleeps.append,
            monotonic=self.monotonic,
            time=self.time,
            strftime=time.strftime,
            gmtime=time.gmtime,
        ))
        return self


@pytest.fixture()
def clock(monkeypatch):
    return Clock().install(monkeypatch)


def phorge_reply(result=None, error_code=None, error_info=None):
    body = {'result': result, 'error_code': error_code, 'error_info': error_info}
    return 200, json.dumps(body).encode()


class ApiHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers['Content-Length'])
        request = {'path': self.path, 'headers': self.headers, 'body': self.rfile.read(length).decode()}
        self.server.received.append(request)
        reply = self.server.reply
        status, payload = reply(request) if callable(reply) else reply
        self.send_response(status)
        self.send_header('Content-Length', str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args):
        self.server.log_lines.append(args)


class StreamHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers['Content-Length'])
        self.server.received.append({
            'path': self.path,
            'headers': self.headers,
            'body': self.rfile.read(length).decode(),
        })
        self.send_response(200)
        self.end_headers()
        for line in self.server.lines:
            self.wfile.write(line)
            self.wfile.flush()
        if self.server.hold:
            self.server.release.wait(10)

    def log_message(self, *args):
        self.server.log_lines.append(args)


@pytest.fixture()
def serve():
    servers = []

    def start(handler=ApiHandler, reply=None, lines=(), hold=False, tls=None):
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
        server.daemon_threads = True
        server.received = []
        server.log_lines = []
        server.reply = reply or phorge_reply({})
        server.lines = lines
        server.hold = hold
        server.release = threading.Event()
        server.url = f'http://127.0.0.1:{server.server_port}'
        if tls:
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(*tls)
            server.socket = context.wrap_socket(server.socket, server_side=True)
            server.url = f'https://localhost:{server.server_port}'
        servers.append(server)
        threading.Thread(target=server.serve_forever, kwargs={'poll_interval': 0.01}, daemon=True).start()
        return server

    yield start
    for server in servers:
        server.release.set()
        server.shutdown()
        server.server_close()


class Script:
    def __init__(self, *outcomes):
        self.outcomes = list(outcomes)
        self.count = 0

    def __call__(self, request):
        self.count += 1
        outcome = self.outcomes.pop(0) if len(self.outcomes) > 1 else self.outcomes[0]
        return outcome(request) if callable(outcome) else outcome


ICINGA_OWN_NAMES = ('host', 'check_command', 'event_command', 'check_period', 'command_endpoint', 'zone')


def icinga_filter_matches(body, attrs):
    scope = dict(body.get('filter_vars') or {})
    scope.update({name: object() for name in ICINGA_OWN_NAMES})
    scope['service'] = types.SimpleNamespace(**attrs)
    return bool(eval(body['filter'].replace('&&', ' and '), {'__builtins__': {}}, scope))


def matches_nothing(task):
    return task_key(task) == 'never!matches'


def form(request):
    return urllib.parse.parse_qs(request['body'])


class TestMissingKeys:
    def test_complete_config(self):
        assert missing_keys(BASE_CONFIG) == []

    @pytest.mark.parametrize('key', [
        'icingaweb_url', 'dry_run', 'log_level', 'state_file', 'reconnect_max',
        'grace_minutes', 'storm_limit', 'storm_window_minutes', 'reopen_hours', 'heartbeat_file',
        'close_after_recovery_seconds',
    ])
    def test_missing_top_level_key(self, key):
        config = copy.deepcopy(BASE_CONFIG)
        del config[key]
        assert missing_keys(config) == [key]

    @pytest.mark.parametrize(('section', 'key'), [
        ('icinga', 'password'),
        ('icinga', 'ca_file'),
        ('icinga', 'queue'),
        ('phorge', 'api_token'),
        ('phorge', 'proxy'),
        ('triggers', 'any'),
        ('priorities', 'UNKNOWN'),
    ])
    def test_missing_nested_key(self, section, key):
        config = copy.deepcopy(BASE_CONFIG)
        del config[section][key]
        assert missing_keys(config) == [f'{section}.{key}']

    def test_section_that_is_not_an_object(self):
        config = dict(BASE_CONFIG, phorge='https://phorge.example.org')
        assert missing_keys(config) == ['phorge']

    def test_lists_everything_that_is_missing(self):
        assert missing_keys({}) == list(taskbot.REQUIRED)

    def test_null_values_count_as_present(self):
        config = copy.deepcopy(BASE_CONFIG)
        config['phorge']['proxy'] = None
        assert missing_keys(config) == []


class TestInvalidValues:
    def test_a_good_config_has_no_problems(self):
        assert invalid_values(BASE_CONFIG) == []

    @pytest.mark.parametrize('key', ['grace_minutes', 'storm_window_minutes', 'reopen_hours'])
    @pytest.mark.parametrize('value', ['15', -1, None, True, [15]])
    def test_durations_must_be_non_negative_numbers(self, key, value):
        assert invalid_values(dict(BASE_CONFIG, **{key: value})) == [f'{key} must be a number of 0 or more']

    @pytest.mark.parametrize('key', ['grace_minutes', 'storm_window_minutes', 'reopen_hours'])
    @pytest.mark.parametrize('value', [0, 0.5, 15, 24.0])
    def test_durations_may_be_zero_or_fractional(self, key, value):
        assert invalid_values(dict(BASE_CONFIG, **{key: value})) == []

    @pytest.mark.parametrize('value', [None, 0, 0.5, 600])
    def test_the_close_delay_may_be_off_zero_or_a_number(self, value):
        assert invalid_values(dict(BASE_CONFIG, close_after_recovery_seconds=value)) == []

    @pytest.mark.parametrize('value', ['600', -1, True, [60]])
    def test_the_close_delay_must_be_null_or_a_non_negative_number(self, value):
        problems = invalid_values(dict(BASE_CONFIG, close_after_recovery_seconds=value))
        assert problems == ['close_after_recovery_seconds must be null or a number of 0 or more']

    @pytest.mark.parametrize('value', [0, -5, 2.5, '5', None, True])
    def test_storm_limit_is_a_positive_whole_number(self, value):
        assert invalid_values(dict(BASE_CONFIG, storm_limit=value)) == ['storm_limit must be a whole number of 1 or more']

    @pytest.mark.parametrize('keyword', ['unbreak', 'triage', 'high', 'medium', 'low', 'lowest'])
    def test_every_phorge_priority_keyword_is_accepted(self, keyword):
        assert invalid_values(dict(BASE_CONFIG, priorities={'WARNING': keyword, 'CRITICAL': keyword, 'UNKNOWN': keyword})) == []

    def test_unknown_priorities_are_caught_early(self):
        problems = invalid_values(dict(BASE_CONFIG, priorities={'WARNING': 'urgent', 'CRITICAL': 'high', 'UNKNOWN': 'Medium'}))
        assert len(problems) == 2
        assert problems[0].startswith('priorities.WARNING must be one of unbreak, triage')
        assert problems[1].startswith('priorities.UNKNOWN must be one of')

    def test_every_problem_is_reported_at_once(self):
        assert len(invalid_values(dict(BASE_CONFIG, grace_minutes=-1, storm_limit=0, reopen_hours='x'))) == 3


class TestLoadConfig:
    @staticmethod
    def write(tmp_path, config):
        path = tmp_path / 'config.json'
        path.write_text(json.dumps(config))
        return str(path)

    def test_valid(self, tmp_path):
        config = load_config(self.write(tmp_path, BASE_CONFIG))
        assert config['icinga']['queue'] == 'taskbot'

    def test_missing_keys_are_all_reported(self, tmp_path):
        config = copy.deepcopy(BASE_CONFIG)
        del config['phorge']['retries']
        del config['dry_run']
        with pytest.raises(SystemExit, match='Missing in config: phorge.retries, dry_run'):
            load_config(self.write(tmp_path, config))

    def test_missing_file(self, tmp_path):
        with pytest.raises(SystemExit, match='Cannot load'):
            load_config(str(tmp_path / 'absent.json'))

    def test_invalid_json(self, tmp_path):
        path = tmp_path / 'config.json'
        path.write_text('{"icinga": ')
        with pytest.raises(SystemExit, match='Cannot load'):
            load_config(str(path))

    def test_not_an_object(self, tmp_path):
        path = tmp_path / 'config.json'
        path.write_text('["a"]')
        with pytest.raises(SystemExit, match='must contain a JSON object'):
            load_config(str(path))

    def test_backslashes_in_secrets_survive(self, tmp_path):
        config = copy.deepcopy(BASE_CONFIG)
        config['icinga']['password'] = 'abc\\Ndef'
        assert load_config(self.write(tmp_path, config))['icinga']['password'] == 'abc\\Ndef'

    def test_dry_run_comes_from_the_file(self, tmp_path):
        assert load_config(self.write(tmp_path, dict(BASE_CONFIG, dry_run=True)))['dry_run'] is True

    def test_bad_values_stop_the_bot_from_starting(self, tmp_path):
        config = dict(BASE_CONFIG, grace_minutes=-5, storm_limit=0)
        with pytest.raises(SystemExit, match='Invalid config: grace_minutes must be a number of 0 or more; storm_limit must be'):
            load_config(self.write(tmp_path, config))

    def test_missing_keys_are_reported_before_bad_values(self, tmp_path):
        config = dict(BASE_CONFIG, grace_minutes=-5)
        del config['dry_run']
        with pytest.raises(SystemExit, match='Missing in config: dry_run'):
            load_config(self.write(tmp_path, config))


class TestFlatten:
    def test_scalar_values_are_strings(self):
        assert flatten({'a': 1, 'b': 'x', 'c': 2.5}) == [('a', '1'), ('b', 'x'), ('c', '2.5')]

    def test_nested_dicts_and_lists(self):
        params = {'constraints': {'slugs': ['a', 'b']}, 'queryKey': 'open'}
        assert flatten(params) == [
            ('constraints[slugs][0]', 'a'),
            ('constraints[slugs][1]', 'b'),
            ('queryKey', 'open'),
        ]

    def test_transactions(self):
        params = {'transactions': [{'type': 'title', 'value': 'Hi'}, {'type': 'projects.add', 'value': ['PHID-1']}]}
        assert flatten(params) == [
            ('transactions[0][type]', 'title'),
            ('transactions[0][value]', 'Hi'),
            ('transactions[1][type]', 'projects.add'),
            ('transactions[1][value][0]', 'PHID-1'),
        ]

    def test_empty(self):
        assert flatten({}) == []
        assert flatten([]) == []

    def test_tuples_behave_like_lists(self):
        assert flatten({'a': ('x', 'y')}) == [('a[0]', 'x'), ('a[1]', 'y')]


def dead_proxy_in_environment(monkeypatch):
    for name in ('http_proxy', 'HTTP_PROXY', 'https_proxy', 'HTTPS_PROXY'):
        monkeypatch.setenv(name, 'http://127.0.0.1:9')
    monkeypatch.delenv('no_proxy', raising=False)
    monkeypatch.delenv('NO_PROXY', raising=False)


class TestBuildOpener:
    def test_proxy_is_used_for_both_schemes(self):
        opener = build_opener('http://bastion.example:8080')
        proxies = [h.proxies for h in opener.handlers if isinstance(h, urllib.request.ProxyHandler)]
        assert proxies == [{'http': 'http://bastion.example:8080', 'https': 'http://bastion.example:8080'}]

    @pytest.mark.parametrize('proxy', [None, ''])
    def test_no_proxy_ignores_the_environment(self, serve, monkeypatch, proxy):
        server = serve()
        dead_proxy_in_environment(monkeypatch)
        with build_opener(proxy).open(server.url, data=b'x', timeout=5) as response:
            assert response.status == 200

    def test_the_environment_would_otherwise_break_the_request(self, serve, monkeypatch):
        server = serve()
        dead_proxy_in_environment(monkeypatch)
        with pytest.raises(OSError, match='refused'):
            urllib.request.build_opener().open(server.url, data=b'x', timeout=5)

    def test_context_is_attached_to_https(self):
        context = ssl.create_default_context()
        opener = build_opener(None, context)
        https = [h for h in opener.handlers if isinstance(h, urllib.request.HTTPSHandler)]
        assert len(https) == 1
        assert https[0]._context is context


class TestCheckOutput:
    def test_plain_text(self):
        assert check_output({'last_check_result': {'output': 'DISK CRITICAL'}}) == 'DISK CRITICAL'

    def test_whitespace_is_stripped(self):
        assert check_output({'last_check_result': {'output': '  spaced\n'}}) == 'spaced'

    def test_code_fences_cannot_break_out(self):
        text = check_output({'last_check_result': {'output': 'a ```b``` c'}})
        assert '```' not in text
        assert text == "a '''b''' c"

    def test_long_output_is_cut(self):
        assert len(check_output({'last_check_result': {'output': 'x' * 5000}})) == 1500

    @pytest.mark.parametrize('attrs', [
        {},
        {'last_check_result': None},
        {'last_check_result': {}},
        {'last_check_result': {'output': ''}},
        {'last_check_result': {'output': None}},
        {'last_check_result': {'output': '   '}},
    ])
    def test_empty_output(self, attrs):
        assert check_output(attrs) == 'No output.'


class TestState:
    def test_missing_file_starts_empty(self, tmp_path):
        state = State(str(tmp_path / 'state.json'))
        assert (state.services, state.created, state.storm) == ({}, [], None)

    def test_put_and_get(self, tmp_path):
        state = State(str(tmp_path / 'state.json'))
        assert state.get('mw1!Disk') is None
        state.put('mw1!Disk', {'task': 7, 'active': True, 'state': 'CRITICAL'})
        assert state.get('mw1!Disk') == {'task': 7, 'active': True, 'state': 'CRITICAL'}

    def test_survives_a_restart(self, tmp_path):
        path = str(tmp_path / 'state.json')
        first = State(path)
        first.put('mw1!Disk', {'task': 7, 'active': True, 'state': 'CRITICAL'})
        first.record_created(500.0, 600)
        first.set_storm(99)
        second = State(path)
        assert second.get('mw1!Disk')['task'] == 7
        assert second.created == [500.0]
        assert second.storm == 99

    def test_write_is_atomic(self, tmp_path):
        path = tmp_path / 'state.json'
        State(str(path)).put('a', {'task': 1})
        assert not (tmp_path / 'state.json.tmp').exists()
        assert json.loads(path.read_text()) == {'services': {'a': {'task': 1}}, 'created': [], 'storm': None, 'storm_recovered': None}

    def test_nothing_is_written_when_not_persisting(self, tmp_path):
        path = tmp_path / 'state.json'
        state = State(str(path), persist=False)
        state.put('a', {'task': 1})
        state.record_created(1.0, 60)
        state.set_storm(5)
        assert state.get('a') == {'task': 1}
        assert state.storm == 5
        assert not path.exists()

    def test_the_old_flat_format_is_still_read(self, tmp_path):
        path = tmp_path / 'state.json'
        path.write_text(json.dumps({'mw1!Disk': {'task': 3, 'active': True, 'state': 'CRITICAL'}}))
        state = State(str(path))
        assert state.get('mw1!Disk')['task'] == 3
        assert state.created == []

    @pytest.mark.parametrize('text', ['{oops', '', '["a"]', '42', '"text"'])
    def test_an_unreadable_file_is_ignored_with_a_warning(self, tmp_path, caplog, text):
        path = tmp_path / 'state.json'
        path.write_text(text)
        with caplog.at_level(logging.WARNING, logger='taskbot'):
            state = State(str(path))
        assert state.services == {}
        assert 'Ignoring' in caplog.text

    def test_the_unreadable_file_is_replaced_on_the_next_write(self, tmp_path):
        path = tmp_path / 'state.json'
        path.write_text('{oops')
        State(str(path)).put('a', {'task': 1})
        assert json.loads(path.read_text())['services'] == {'a': {'task': 1}}

    def test_recent_creations_are_counted_within_the_window(self, tmp_path):
        state = State(str(tmp_path / 'state.json'))
        for stamp in (100.0, 200.0, 300.0):
            state.record_created(stamp, 1000)
        assert state.recent(350.0, 1000) == 3
        assert state.recent(350.0, 100) == 1
        assert state.recent(2000.0, 1000) == 0

    def test_old_creations_are_dropped_when_recording(self, tmp_path):
        state = State(str(tmp_path / 'state.json'))
        state.record_created(100.0, 500)
        state.record_created(900.0, 500)
        assert state.created == [900.0]


class TestPhorge:
    @staticmethod
    def make(server, **changes):
        config = dict(BASE_CONFIG['phorge'], url=server.url)
        config.update(changes)
        return Phorge(config, config.pop('dry_run', False))

    def test_call_sends_token_and_flattened_params(self, serve):
        server = serve(reply=phorge_reply({'data': []}))
        result = self.make(server).call('maniphest.search', {'constraints': {'ids': [5]}})
        assert result == {'data': []}
        request = server.received[0]
        assert request['path'] == '/api/maniphest.search'
        assert form(request) == {'api.token': ['api-token'], 'constraints[ids][0]': ['5']}

    def test_trailing_slash_in_url(self, serve):
        server = serve()
        phorge = Phorge(dict(BASE_CONFIG['phorge'], url=f'{server.url}/'))
        phorge.call('conduit.ping')
        assert server.received[0]['path'] == '/api/conduit.ping'

    def test_conduit_error_is_raised_without_retrying(self, serve):
        script = Script(phorge_reply(None, 'ERR-INVALID-AUTH', 'API token is invalid.'))
        server = serve(reply=script)
        with pytest.raises(PhorgeError, match='ERR-INVALID-AUTH: API token is invalid'):
            self.make(server).call('maniphest.edit')
        assert script.count == 1

    def test_retries_then_succeeds(self, serve, clock):
        script = Script((500, b'oops'), (500, b'oops'), phorge_reply({'ok': True}))
        server = serve(reply=script)
        assert self.make(server).call('conduit.ping') == {'ok': True}
        assert script.count == 3
        assert clock.sleeps == [2, 4]

    def test_gives_up_after_the_configured_retries(self, serve, clock):
        script = Script((503, b'down'))
        server = serve(reply=script)
        with pytest.raises(PhorgeError, match='conduit.ping request failed'):
            self.make(server, retries=4).call('conduit.ping')
        assert script.count == 4
        assert clock.sleeps == [2, 4, 8]

    def test_at_least_one_attempt(self, serve, clock):
        script = Script((500, b'down'))
        server = serve(reply=script)
        with pytest.raises(PhorgeError, match='request failed'):
            self.make(server, retries=0).call('conduit.ping')
        assert script.count == 1
        assert clock.sleeps == []

    def test_backoff_is_capped(self, serve, clock):
        server = serve(reply=Script((500, b'down')))
        with pytest.raises(PhorgeError, match='request failed'):
            self.make(server, retries=8).call('conduit.ping')
        assert clock.sleeps == [2, 4, 8, 16, 30, 30, 30]

    def test_invalid_json_is_retried(self, serve, clock):
        script = Script((200, b'<html>'), phorge_reply({'ok': 1}))
        server = serve(reply=script)
        assert self.make(server).call('conduit.ping') == {'ok': 1}
        assert clock.sleeps == [2]

    def test_unreachable_server(self, clock):
        phorge = Phorge(dict(BASE_CONFIG['phorge'], url='http://127.0.0.1:9', retries=2))
        with pytest.raises(PhorgeError, match='request failed'):
            phorge.call('conduit.ping')
        assert clock.sleeps == [2]

    def test_resolve_looks_up_each_slug_once(self, serve):
        known = {'infra': 'PHID-PROJ-infra', 'dbs': 'PHID-PROJ-dbs'}

        def respond(request):
            slug = form(request)['constraints[slugs][0]'][0]
            return phorge_reply({'data': [{'phid': known[slug]}] if slug in known else []})

        server = serve(reply=respond)
        phorge = self.make(server)
        assert phorge.resolve(['infra', 'dbs']) == ['PHID-PROJ-infra', 'PHID-PROJ-dbs']
        assert phorge.resolve(['dbs']) == ['PHID-PROJ-dbs']
        assert len(server.received) == 2

    def test_resolve_skips_and_reports_unknown_slugs(self, serve, caplog):
        def respond(request):
            slug = form(request)['constraints[slugs][0]'][0]
            return phorge_reply({'data': [{'phid': 'PHID-PROJ-infra'}] if slug == 'infra' else []})

        phorge = self.make(serve(reply=respond))
        with caplog.at_level(logging.WARNING, logger='taskbot'):
            assert phorge.resolve(['nope', 'infra']) == ['PHID-PROJ-infra']
        assert 'Project nope was not found in Phorge' in caplog.text

    def test_unknown_slugs_are_looked_up_again_later(self, serve):
        server = serve(reply=phorge_reply({'data': []}))
        phorge = self.make(server)
        phorge.resolve(['nope'])
        phorge.resolve(['nope'])
        assert len(server.received) == 2

    def test_resolve_nothing(self, serve):
        server = serve()
        assert self.make(server).resolve([]) == []
        assert server.received == []

    def test_create_builds_every_transaction(self, serve):
        def respond(request):
            if request['path'].endswith('project.search'):
                return phorge_reply({'data': [{'phid': 'PHID-PROJ-infra'}]})
            return phorge_reply({'object': {'id': 42, 'phid': 'PHID-TASK-42'}})

        server = serve(reply=respond)
        assert self.make(server).create('Disk is full', 'Details', 'high', ['infra'], matches_nothing) == 42
        fields = form(server.received[-1])
        assert server.received[-1]['path'] == '/api/maniphest.edit'
        assert 'objectIdentifier' not in fields
        assert fields['transactions[0][type]'] == ['title']
        assert fields['transactions[0][value]'] == ['Disk is full']
        assert fields['transactions[1][type]'] == ['description']
        assert fields['transactions[1][value]'] == ['Details']
        assert fields['transactions[2][type]'] == ['priority']
        assert fields['transactions[2][value]'] == ['high']
        assert fields['transactions[3][type]'] == ['projects.add']
        assert fields['transactions[3][value][0]'] == ['PHID-PROJ-infra']

    @pytest.mark.parametrize('priority', [None, ''])
    def test_create_without_priority_or_projects(self, serve, priority):
        server = serve(reply=phorge_reply({'object': {'id': 9}}))
        assert self.make(server).create('Title', 'Body', priority, [], matches_nothing) == 9
        assert len(server.received) == 1
        fields = form(server.received[0])
        assert [fields[f'transactions[{n}][type]'] for n in range(2)] == [['title'], ['description']]
        assert 'transactions[2][type]' not in fields

    def test_create_drops_projects_that_do_not_exist(self, serve):
        def respond(request):
            if request['path'].endswith('project.search'):
                return phorge_reply({'data': []})
            return phorge_reply({'object': {'id': 3}})

        server = serve(reply=respond)
        self.make(server).create('Title', 'Body', None, ['nope'], matches_nothing)
        assert 'transactions[2][type]' not in form(server.received[-1])

    def test_edit_existing_task(self, serve):
        server = serve(reply=phorge_reply({'object': {'id': 12}}))
        self.make(server).edit([{'type': 'comment', 'value': 'Hello'}], 12)
        fields = form(server.received[0])
        assert fields['objectIdentifier'] == ['12']
        assert fields['transactions[0][type]'] == ['comment']

    def test_dry_run_never_calls_phorge(self, serve, caplog):
        server = serve()
        phorge = Phorge(dict(BASE_CONFIG['phorge'], url=server.url), dry_run=True)
        with caplog.at_level(logging.INFO, logger='taskbot'):
            assert phorge.create('Title', 'Body', 'high', [], matches_nothing) == 0
            assert phorge.edit([{'type': 'comment', 'value': 'Hi'}], 5) == {'object': {'id': 5}}
        assert server.received == []
        assert 'Dry run, would send' in caplog.text
        assert 'api-token' not in caplog.text

    @pytest.mark.parametrize(('data', 'expected'), [([{'id': 5}], True), ([], False)])
    def test_is_open(self, serve, data, expected):
        server = serve(reply=phorge_reply({'data': data}))
        assert self.make(server).is_open(5) is expected
        fields = form(server.received[0])
        assert fields['queryKey'] == ['open']
        assert fields['constraints[ids][0]'] == ['5']

    def test_proxy_setting_is_used(self):
        phorge = Phorge(dict(BASE_CONFIG['phorge'], proxy='http://bastion.example:8080'))
        proxies = [h.proxies for h in phorge.opener.handlers if isinstance(h, urllib.request.ProxyHandler)]
        assert proxies == [{'http': 'http://bastion.example:8080', 'https': 'http://bastion.example:8080'}]

    def test_only_the_configured_proxy_is_used(self, serve, monkeypatch):
        server = serve()
        dead_proxy_in_environment(monkeypatch)
        assert self.make(server, proxy=None).call('conduit.ping') == {}


class Api:
    def __init__(self, outcomes):
        self.outcomes = {method: list(queue) for method, queue in outcomes.items()}
        self.count = {}

    def __call__(self, request):
        method = request['path'].rsplit('/', 1)[1]
        self.count[method] = self.count.get(method, 0) + 1
        queue = self.outcomes[method]
        return queue.pop(0) if len(queue) > 1 else queue[0]


def task_data(task, key='mw1!mw1 Disk', title='Disk on mw1 is CRITICAL', storm=False, status='open', priority=80):
    text = 'Icinga alert storm summary' if storm else f'Details.\n\n{marker(key)}\n\nReported at now'
    return {
        'id': task,
        'phid': f'PHID-TASK-{task}',
        'fields': {
            'name': title,
            'description': {'raw': text},
            'status': {'value': status},
            'priority': {'value': priority},
        },
    }


class TestPhorgeTasks:
    @staticmethod
    def make(server, **changes):
        return Phorge(dict(BASE_CONFIG['phorge'], url=server.url, **changes))

    @staticmethod
    def whoami():
        return phorge_reply({'phid': 'PHID-USER-bot', 'userName': 'icingabot'})

    def test_whoami_asks_once(self, serve):
        server = serve(reply=Api({'user.whoami': [self.whoami()]}))
        phorge = self.make(server)
        assert phorge.whoami() == 'PHID-USER-bot'
        assert phorge.whoami() == 'PHID-USER-bot'
        assert len(server.received) == 1

    def test_open_tasks_are_the_bots_own(self, serve):
        api = Api({
            'user.whoami': [self.whoami()],
            'maniphest.search': [phorge_reply({'data': [task_data(4), task_data(9)], 'cursor': {'after': None}})],
        })
        server = serve(reply=api)
        assert [task['id'] for task in self.make(server).open_tasks()] == [4, 9]
        fields = form(server.received[-1])
        assert fields['queryKey'] == ['open']
        assert fields['constraints[authorPHIDs][0]'] == ['PHID-USER-bot']
        assert fields['order'] == ['oldest']
        assert fields['limit'] == ['100']
        assert 'after' not in fields

    def test_open_tasks_follow_the_cursor(self, serve):
        api = Api({
            'user.whoami': [self.whoami()],
            'maniphest.search': [
                phorge_reply({'data': [task_data(1), task_data(2)], 'cursor': {'after': '2'}}),
                phorge_reply({'data': [task_data(3)], 'cursor': {'after': None}}),
            ],
        })
        server = serve(reply=api)
        assert [task['id'] for task in self.make(server).open_tasks()] == [1, 2, 3]
        searches = [request for request in server.received if request['path'].endswith('maniphest.search')]
        assert [form(request).get('after') for request in searches] == [None, ['2']]

    def test_open_tasks_when_there_are_none(self, serve):
        api = Api({'user.whoami': [self.whoami()], 'maniphest.search': [phorge_reply({'data': [], 'cursor': {'after': None}})]})
        assert list(self.make(serve(reply=api)).open_tasks()) == []

    def test_find_returns_the_first_match_without_reading_further(self, serve):
        api = Api({
            'user.whoami': [self.whoami()],
            'maniphest.search': [
                phorge_reply({'data': [task_data(1, key='a!b'), task_data(2, key='c!d')], 'cursor': {'after': '2'}}),
                phorge_reply({'data': [task_data(3, key='c!d')], 'cursor': {'after': None}}),
            ],
        })
        server = serve(reply=api)
        assert self.make(server).find(lambda task: task_key(task) == 'c!d')['id'] == 2
        assert api.count['maniphest.search'] == 1

    def test_find_returns_none_when_nothing_matches(self, serve):
        api = Api({'user.whoami': [self.whoami()], 'maniphest.search': [phorge_reply({'data': [task_data(1)], 'cursor': {'after': None}})]})
        assert self.make(serve(reply=api)).find(lambda task: task_key(task) == 'other!key') is None

    def test_details(self, serve):
        server = serve(reply=phorge_reply({'data': [task_data(7, title='Disk on mw1 is WARNING', status='resolved', priority=50)]}))
        assert self.make(server).details(7) == {'title': 'Disk on mw1 is WARNING', 'status': 'resolved', 'priority': 50}
        fields = form(server.received[0])
        assert fields['queryKey'] == ['all']
        assert fields['constraints[ids][0]'] == ['7']

    def test_details_of_an_unknown_task(self, serve):
        assert self.make(serve(reply=phorge_reply({'data': []}))).details(7) is None

    @staticmethod
    def transactions(*items):
        return phorge_reply({'data': list(items), 'cursor': {'after': None}})

    @staticmethod
    def comment(author, removed=False):
        return {'type': 'comment', 'authorPHID': author, 'comments': [{'removed': removed}]}

    def test_a_comment_from_a_person_is_found(self, serve):
        api = Api({
            'user.whoami': [self.whoami()],
            'transaction.search': [self.transactions(self.comment('PHID-USER-alice'))],
        })
        server = serve(reply=api)
        assert self.make(server).has_human_comment(7) is True
        fields = form(server.received[-1])
        assert fields['objectIdentifier'] == ['T7']

    def test_the_bots_own_comments_do_not_count(self, serve):
        api = Api({
            'user.whoami': [self.whoami()],
            'transaction.search': [self.transactions(self.comment('PHID-USER-bot'), self.comment('PHID-USER-bot'))],
        })
        assert self.make(serve(reply=api)).has_human_comment(7) is False

    def test_deleted_comments_do_not_count(self, serve):
        api = Api({
            'user.whoami': [self.whoami()],
            'transaction.search': [self.transactions(self.comment('PHID-USER-alice', removed=True))],
        })
        assert self.make(serve(reply=api)).has_human_comment(7) is False

    @pytest.mark.parametrize('transaction', [
        {'type': 'status', 'authorPHID': 'PHID-USER-alice', 'comments': []},
        {'type': 'priority', 'authorPHID': 'PHID-USER-alice'},
        {'type': None, 'authorPHID': 'PHID-USER-alice', 'comments': None},
    ])
    def test_edits_without_a_comment_do_not_count(self, serve, transaction):
        api = Api({'user.whoami': [self.whoami()], 'transaction.search': [self.transactions(transaction)]})
        assert self.make(serve(reply=api)).has_human_comment(7) is False

    def test_a_task_without_transactions_has_no_human_comment(self, serve):
        api = Api({'user.whoami': [self.whoami()], 'transaction.search': [self.transactions()]})
        assert self.make(serve(reply=api)).has_human_comment(7) is False

    def test_comments_on_a_later_page_are_found(self, serve):
        api = Api({
            'user.whoami': [self.whoami()],
            'transaction.search': [
                phorge_reply({'data': [self.comment('PHID-USER-bot')], 'cursor': {'after': '9'}}),
                self.transactions(self.comment('PHID-USER-alice')),
            ],
        })
        server = serve(reply=api)
        assert self.make(server).has_human_comment(7) is True
        searches = [request for request in server.received if request['path'].endswith('transaction.search')]
        assert [form(request).get('after') for request in searches] == [None, ['9']]

    @pytest.mark.usefixtures('clock')
    def test_create_trusts_a_clean_answer(self, serve):
        api = Api({'maniphest.edit': [phorge_reply({'object': {'id': 12}})]})
        server = serve(reply=api)
        assert self.make(server).create('T', 'B', 'high', [], matches_nothing) == 12
        assert api.count == {'maniphest.edit': 1}

    def test_create_checks_for_the_task_after_an_unclear_failure(self, serve, clock):
        api = Api({
            'maniphest.edit': [(500, b'lost the response')],
            'user.whoami': [self.whoami()],
            'maniphest.search': [phorge_reply({'data': [task_data(31, key='mw1!mw1 Disk')], 'cursor': {'after': None}})],
        })
        server = serve(reply=api)
        created = self.make(server).create('T', 'B', 'high', [], lambda task: task_key(task) == 'mw1!mw1 Disk')
        assert created == 31
        assert api.count['maniphest.edit'] == 1
        assert clock.sleeps == []

    def test_create_tries_again_when_the_task_really_is_missing(self, serve, clock):
        api = Api({
            'maniphest.edit': [(500, b'down'), phorge_reply({'object': {'id': 40}})],
            'user.whoami': [self.whoami()],
            'maniphest.search': [phorge_reply({'data': [], 'cursor': {'after': None}})],
        })
        server = serve(reply=api)
        assert self.make(server).create('T', 'B', 'high', [], matches_nothing) == 40
        assert api.count['maniphest.edit'] == 2
        assert clock.sleeps == [2]

    def test_create_gives_up_after_the_configured_attempts(self, serve, clock):
        api = Api({
            'maniphest.edit': [(500, b'down')],
            'user.whoami': [self.whoami()],
            'maniphest.search': [phorge_reply({'data': [], 'cursor': {'after': None}})],
        })
        server = serve(reply=api)
        with pytest.raises(PhorgeUncertain, match='maniphest.edit request failed'):
            self.make(server, retries=3).create('T', 'B', 'high', [], matches_nothing)
        assert api.count['maniphest.edit'] == 3
        assert clock.sleeps == [2, 4]

    @pytest.mark.usefixtures('clock')
    def test_create_never_repeats_the_request_blindly(self, serve):
        api = Api({
            'maniphest.edit': [(500, b'down')],
            'user.whoami': [self.whoami()],
            'maniphest.search': [phorge_reply({'data': [task_data(5, key='x!y')], 'cursor': {'after': None}})],
        })
        server = serve(reply=api)
        self.make(server, retries=5).create('T', 'B', 'high', [], lambda task: task_key(task) == 'x!y')
        assert api.count['maniphest.edit'] == 1

    @pytest.mark.usefixtures('clock')
    def test_create_does_not_retry_a_conduit_error(self, serve):
        api = Api({'maniphest.edit': [phorge_reply(None, 'ERR-CONDUIT-CORE', 'Bad project')]})
        server = serve(reply=api)
        with pytest.raises(PhorgeError, match='ERR-CONDUIT-CORE'):
            self.make(server).create('T', 'B', 'high', [], matches_nothing)
        assert api.count == {'maniphest.edit': 1}

    @pytest.mark.usefixtures('clock')
    def test_a_failure_while_looking_for_the_task_is_raised(self, serve):
        api = Api({
            'maniphest.edit': [(500, b'down')],
            'user.whoami': [(500, b'down')],
        })
        server = serve(reply=api)
        with pytest.raises(PhorgeError, match='user.whoami request failed'):
            self.make(server).create('T', 'B', 'high', [], matches_nothing)
        assert api.count['maniphest.edit'] == 1


class TestIcinga:
    @staticmethod
    def make(server, **changes):
        return Icinga(dict(BASE_CONFIG['icinga'], url=server.url, **changes))

    def test_basic_auth_header(self, serve):
        server = serve(reply=(200, b'{"results": []}'))
        self.make(server, username='taskbot', password='p:w').query({})
        assert server.received[0]['headers']['Authorization'] == 'Basic dGFza2JvdDpwOnc='

    def test_query_uses_the_get_override(self, serve):
        reply = {'results': [{'attrs': {'name': 'Disk'}, 'joins': {'host': {'state': 0.0}}}]}
        server = serve(reply=(200, json.dumps(reply).encode()))
        assert self.make(server).query({'filter': 'service.state != 0'}) == [{'name': 'Disk', 'host': {'state': 0.0}}]
        request = server.received[0]
        assert request['path'] == '/v1/objects/services'
        assert request['headers']['X-HTTP-Method-Override'] == 'GET'
        assert request['headers']['Content-Type'] == 'application/json'
        assert request['headers']['Accept'] == 'application/json'
        assert json.loads(request['body']) == {
            'filter': 'service.state != 0',
            'attrs': taskbot.ATTRS,
            'joins': ['host.state', 'host.downtime_depth'],
        }

    def test_the_host_is_merged_into_the_service(self, serve):
        result = {'attrs': make_service(), 'joins': {'host': {'state': 1.0, 'downtime_depth': 2.0}}}
        reply = {'results': [result]}
        server = serve(reply=(200, json.dumps(reply).encode()))
        (service,) = self.make(server).query({})
        assert service['host'] == {'state': 1.0, 'downtime_depth': 2.0}
        assert service['name'] == 'mw1 Disk'

    def test_a_missing_join_leaves_an_empty_host(self, serve):
        server = serve(reply=(200, json.dumps({'results': [{'attrs': {'name': 'Disk'}}]}).encode()))
        assert self.make(server).query({}) == [{'name': 'Disk', 'host': {}}]

    def test_missing_host_details_are_reported_once(self, serve, caplog):
        server = serve(reply=(200, json.dumps({'results': [{'attrs': {'name': 'Disk'}}]}).encode()))
        icinga = self.make(server)
        with caplog.at_level(logging.WARNING, logger='taskbot'):
            icinga.query({})
            icinga.query({})
        assert caplog.text.count('objects/query/Host') == 1

    def test_no_warning_when_host_details_arrive(self, serve, caplog):
        reply = {'results': [{'attrs': {'name': 'Disk'}, 'joins': {'host': {'state': 0.0}}}]}
        server = serve(reply=(200, json.dumps(reply).encode()))
        with caplog.at_level(logging.WARNING, logger='taskbot'):
            self.make(server).query({})
        assert caplog.text == ''

    def test_no_warning_for_an_empty_result(self, serve, caplog):
        server = serve(reply=(200, b'{"results": []}'))
        with caplog.at_level(logging.WARNING, logger='taskbot'):
            self.make(server).query({})
        assert caplog.text == ''

    def test_problems_ask_for_hard_non_ok_services(self, serve):
        server = serve(reply=(200, b'{"results": []}'))
        assert self.make(server).problems() == []
        assert json.loads(server.received[0]['body'])['filter'] == 'service.state != 0 && service.state_type == 1'

    def test_service_found(self, serve):
        reply = {'results': [{'attrs': make_service()}]}
        server = serve(reply=(200, json.dumps(reply).encode()))
        assert self.make(server).service('mw1', 'mw1 Disk')['host_name'] == 'mw1'
        body = json.loads(server.received[0]['body'])
        assert body['filter'] == 'service.host_name == wanted_host && service.name == wanted_service'
        assert body['filter_vars'] == {'wanted_host': 'mw1', 'wanted_service': 'mw1 Disk'}
        assert body['attrs'] == taskbot.ATTRS
        assert body['joins'] == taskbot.JOINS

    def test_the_filter_still_matches_once_icinga_adds_its_own_names_to_the_scope(self, serve):
        server = serve(reply=(200, b'{"results": []}'))
        self.make(server).service('mw1', 'mw1 Disk')
        body = json.loads(server.received[0]['body'])
        assert icinga_filter_matches(body, {'host_name': 'mw1', 'name': 'mw1 Disk'}) is True
        assert icinga_filter_matches(body, {'host_name': 'mw2', 'name': 'mw1 Disk'}) is False
        assert icinga_filter_matches(body, {'host_name': 'mw1', 'name': 'mw1 Load'}) is False

    def test_no_filter_variable_is_one_of_the_names_icinga_reserves(self, serve):
        server = serve(reply=(200, b'{"results": []}'))
        self.make(server).service('mw1', 'mw1 Disk')
        body = json.loads(server.received[0]['body'])
        assert not set(body['filter_vars']) & {*ICINGA_OWN_NAMES, 'service', 'obj'}

    def test_the_problem_filter_selects_hard_non_ok_services(self):
        body = {'filter': 'service.state != 0 && service.state_type == 1'}
        assert icinga_filter_matches(body, {'state': 2.0, 'state_type': 1.0}) is True
        assert icinga_filter_matches(body, {'state': 2.0, 'state_type': 0.0}) is False
        assert icinga_filter_matches(body, {'state': 0.0, 'state_type': 1.0}) is False

    def test_service_not_found(self, serve):
        server = serve(reply=(200, b'{"results": []}'))
        assert self.make(server).service('mw1', 'gone') is None

    def test_http_error_is_an_oserror(self, serve):
        server = serve(reply=(401, b'{"error": 401}'))
        with pytest.raises(OSError, match='401'):
            self.make(server).query({})

    def test_events_request_and_stream(self, serve):
        lines = [
            b'{"type": "StateChange", "host": "mw1", "service": "Disk"}\n',
            b'\n',
            b'  \n',
            b'{"type": "StateChange", "host": "mw2", "service": "Load"}\n',
        ]
        server = serve(handler=StreamHandler, lines=lines)
        events = list(self.make(server).events())
        assert [event['host'] for event in events] == ['mw1', 'mw2']
        request = server.received[0]
        assert request['path'] == '/v1/events'
        assert 'X-HTTP-Method-Override' not in request['headers']
        assert json.loads(request['body']) == {'queue': 'taskbot', 'types': ['StateChange']}

    def test_stream_closed_by_the_server_ends_quietly(self, serve):
        server = serve(handler=StreamHandler, lines=[])
        assert list(self.make(server).events()) == []

    def test_idle_stream_ends_quietly(self, serve):
        line = b'{"type": "StateChange", "host": "mw1", "service": "Disk"}\n'
        server = serve(handler=StreamHandler, lines=[line], hold=True)
        events = list(self.make(server, stream_timeout=0.3).events())
        assert [event['host'] for event in events] == ['mw1']

    def test_garbage_in_the_stream_is_a_valueerror(self, serve):
        server = serve(handler=StreamHandler, lines=[b'not json\n'])
        with pytest.raises(ValueError, match='Expecting'):
            list(self.make(server).events())

    def test_unreachable_server(self):
        icinga = Icinga(dict(BASE_CONFIG['icinga'], url='http://127.0.0.1:9'))
        with pytest.raises(OSError, match='refused'):
            icinga.query({})

    def test_never_uses_a_proxy(self, serve, monkeypatch):
        server = serve(reply=(200, b'{"results": []}'))
        dead_proxy_in_environment(monkeypatch)
        assert self.make(server).query({}) == []

    @pytest.mark.parametrize(('ca_file', 'expected'), [('', None), ('/etc/taskbot/icinga-ca.crt', '/etc/taskbot/icinga-ca.crt')])
    def test_https_verifies_with_the_configured_ca(self, monkeypatch, ca_file, expected):
        calls = []
        real = ssl.create_default_context

        def fake_context(**kwargs):
            calls.append(kwargs)
            return real()

        monkeypatch.setattr(taskbot.ssl, 'create_default_context', fake_context)
        Icinga(dict(BASE_CONFIG['icinga'], url='https://icinga.example.org:5665', ca_file=ca_file))
        assert calls == [{'cafile': expected}]

    def test_http_url_builds_no_context(self, monkeypatch):
        calls = []
        monkeypatch.setattr(taskbot.ssl, 'create_default_context', lambda **kwargs: calls.append(kwargs))
        Icinga(BASE_CONFIG['icinga'])
        assert calls == []

    def test_trailing_slash_in_url(self, serve):
        server = serve(reply=(200, b'{"results": []}'))
        Icinga(dict(BASE_CONFIG['icinga'], url=f'{server.url}/')).query({})
        assert server.received[0]['path'] == '/v1/objects/services'


def openssl(*args):
    subprocess.run(['openssl', *map(str, args)], check=True, capture_output=True)


def make_ca(directory, name):
    config = directory / f'{name}.cnf'
    config.write_text(
        '[req]\ndistinguished_name=dn\nx509_extensions=v3\n[dn]\n[v3]\n'
        'basicConstraints=critical,CA:TRUE\nsubjectKeyIdentifier=none\nauthorityKeyIdentifier=none\n'
    )
    key, cert = directory / f'{name}.key', directory / f'{name}.crt'
    openssl('ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', key)
    openssl('req', '-x509', '-new', '-key', key, '-subj', f'/CN={name}', '-days', '3650', '-config', config, '-out', cert)
    return key, cert


@pytest.fixture(scope='module')
def icinga_pki(tmp_path_factory):
    if shutil.which('openssl') is None:
        pytest.skip('openssl is needed to build the test certificates')
    directory = tmp_path_factory.mktemp('pki')
    try:
        ca_key, ca_cert = make_ca(directory, 'Icinga CA')
        make_ca(directory, 'Other CA')
        (directory / 'leaf.ext').write_text('basicConstraints=CA:FALSE\nsubjectKeyIdentifier=none\nauthorityKeyIdentifier=none\n')
        key, request, cert = directory / 'leaf.key', directory / 'leaf.csr', directory / 'leaf.crt'
        openssl('ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', key)
        openssl('req', '-new', '-key', key, '-subj', '/CN=localhost', '-out', request)
        openssl('x509', '-req', '-in', request, '-CA', ca_cert, '-CAkey', ca_key, '-CAcreateserial', '-days', '365', '-extfile', directory / 'leaf.ext', '-out', cert)
    except subprocess.CalledProcessError as error:
        pytest.skip(f'openssl could not build the test certificates: {error.stderr.decode().strip()}')
    return types.SimpleNamespace(ca=str(ca_cert), other_ca=str(directory / 'Other CA.crt'), cert=str(cert), key=str(key))


@pytest.fixture()
def _strict_by_default(monkeypatch):
    real = ssl.create_default_context

    def strict_context(**kwargs):
        context = real(**kwargs)
        context.verify_flags |= ssl.VERIFY_X509_PARTIAL_CHAIN | ssl.VERIFY_X509_STRICT
        return context

    monkeypatch.setattr(taskbot.ssl, 'create_default_context', strict_context)


@pytest.mark.usefixtures('_strict_by_default')
class TestIcingaTls:
    @staticmethod
    def make(server, pki):
        return Icinga(dict(BASE_CONFIG['icinga'], url=server.url, ca_file=pki.ca))

    def test_strict_checking_is_off(self):
        icinga = Icinga(dict(BASE_CONFIG['icinga'], url='https://icinga.example.org:5665'))
        https = [h for h in icinga.opener.handlers if isinstance(h, urllib.request.HTTPSHandler)]
        assert not https[0]._context.verify_flags & ssl.VERIFY_X509_STRICT

    def test_the_default_context_would_reject_icinga_certificates(self, serve, icinga_pki):
        server = serve(reply=(200, b'{"results": []}'), tls=(icinga_pki.cert, icinga_pki.key))
        context = ssl.create_default_context(cafile=icinga_pki.ca)
        with pytest.raises(OSError, match='Missing Authority Key Identifier'):
            urllib.request.build_opener(urllib.request.HTTPSHandler(context=context)).open(server.url, data=b'x', timeout=5)

    def test_accepts_certificates_without_key_identifiers(self, serve, icinga_pki):
        server = serve(reply=(200, b'{"results": [{"attrs": {"name": "Disk"}}]}'), tls=(icinga_pki.cert, icinga_pki.key))
        assert self.make(server, icinga_pki).query({}) == [{'name': 'Disk', 'host': {}}]
        assert server.received[0]['headers']['Authorization'].startswith('Basic ')

    def test_still_rejects_a_certificate_from_another_ca(self, serve, icinga_pki):
        server = serve(reply=(200, b'{"results": []}'), tls=(icinga_pki.cert, icinga_pki.key))
        icinga = Icinga(dict(BASE_CONFIG['icinga'], url=server.url, ca_file=icinga_pki.other_ca))
        with pytest.raises(OSError, match='CERTIFICATE_VERIFY_FAILED'):
            icinga.query({})
        assert server.received == []

    def test_still_checks_the_hostname(self, serve, icinga_pki):
        server = serve(reply=(200, b'{"results": []}'), tls=(icinga_pki.cert, icinga_pki.key))
        icinga = Icinga(dict(BASE_CONFIG['icinga'], url=f'https://127.0.0.1:{server.server_port}', ca_file=icinga_pki.ca))
        with pytest.raises(OSError, match='mismatch'):
            icinga.query({})
        assert server.received == []

    def test_the_password_is_not_sent_to_an_untrusted_server(self, serve, icinga_pki):
        server = serve(reply=(200, b'{"results": []}'), tls=(icinga_pki.cert, icinga_pki.key))
        icinga = Icinga(dict(BASE_CONFIG['icinga'], url=server.url, ca_file=icinga_pki.other_ca, password='hunter2'))
        with pytest.raises(OSError, match='CERTIFICATE_VERIFY_FAILED'):
            icinga.query({})
        assert all('hunter2' not in request['body'] for request in server.received)


def as_task(text, title='Disk on mw1 is CRITICAL'):
    return {'id': 1, 'fields': {'name': title, 'description': {'raw': text}}}


class TestTaskParsing:
    def test_the_key_is_read_from_the_marker_line(self):
        assert task_key(as_task(f'Some words.\n\n{marker("mw1!mw1 Disk")}\n\nReported at now')) == 'mw1!mw1 Disk'

    @pytest.mark.parametrize('text', [
        '',
        'No marker here.',
        'Mentioned in passing: Icinga service: `a!b` and more words',
        ' Icinga service: `a!b`',
    ])
    def test_no_key_without_a_marker_line(self, text):
        assert task_key(as_task(text)) is None

    @pytest.mark.parametrize('task', [{}, {'fields': None}, {'fields': {}}, {'fields': {'description': None}}, {'fields': {'description': {'raw': None}}}])
    def test_odd_tasks_do_not_break_parsing(self, task):
        assert task_key(task) is None
        assert is_storm_task(task) is False
        assert title_state(task) == 'UNKNOWN'

    def test_the_storm_marker_is_its_own_line(self):
        assert is_storm_task(as_task('Words.\n\nIcinga alert storm summary')) is True
        assert is_storm_task(as_task('This is not an Icinga alert storm summary task')) is False

    @pytest.mark.parametrize(('title', 'state'), [
        ('Disk on mw1 is WARNING', 'WARNING'),
        ('Disk on mw1 is CRITICAL', 'CRITICAL'),
        ('Disk on mw1 is UNKNOWN', 'UNKNOWN'),
        ('Disk on mw1 is OK', 'UNKNOWN'),
        ('Somebody renamed this', 'UNKNOWN'),
        ('Disk on mw1 is CRITICAL, looking into it', 'UNKNOWN'),
    ])
    def test_the_state_comes_from_the_end_of_the_title(self, title, state):
        assert title_state(as_task('x', title=title)) == state


class TestBotMessages:
    def test_title(self, tmp_path):
        bot = make_bot(tmp_path)
        assert bot.title(make_service(), 'CRITICAL') == 'Disk on mw1 is CRITICAL'

    def test_title_falls_back_to_the_service_name(self, tmp_path):
        bot = make_bot(tmp_path)
        assert bot.title(make_service(display_name=''), 'WARNING') == 'mw1 Disk on mw1 is WARNING'

    def test_description_contents(self, tmp_path):
        text = make_bot(tmp_path).description(make_service(), 'CRITICAL')
        assert 'Icinga reported **CRITICAL** for **Disk** on **mw1**.' in text
        assert '```\nDISK CRITICAL - free space: / 1 GB\n```' in text
        assert 'Icinga Web: https://icinga.example.org/icingadb/service?name=mw1%20Disk&host.name=mw1' in text
        assert 'Documentation' not in text
        assert re.search(r'^Reported at \d{4}-\d{2}-\d{2} \d{2}:\d{2} UTC$', text, re.MULTILINE)

    def test_description_carries_the_marker_the_bot_reads_back(self, tmp_path):
        text = make_bot(tmp_path).description(make_service(), 'CRITICAL')
        assert f'\n{marker("mw1!mw1 Disk")}\n' in text
        assert task_key(as_task(text)) == 'mw1!mw1 Disk'

    def test_the_marker_survives_awkward_names(self, tmp_path):
        attrs = make_service(host='db-1.example', name='db-1 Replication lag (s) #2')
        text = make_bot(tmp_path).description(attrs, 'WARNING')
        assert task_key(as_task(text)) == 'db-1.example!db-1 Replication lag (s) #2'

    def test_description_with_documentation(self, tmp_path):
        attrs = make_service(notes_url='https://meta.miraheze.org/wiki/Tech:Disk')
        text = make_bot(tmp_path).description(attrs, 'CRITICAL')
        assert 'Documentation: https://meta.miraheze.org/wiki/Tech:Disk' in text

    def test_description_without_icinga_web(self, tmp_path):
        text = make_bot(tmp_path, icingaweb_url='').description(make_service(), 'CRITICAL')
        assert 'Icinga Web' not in text

    def test_icinga_web_trailing_slash(self, tmp_path):
        text = make_bot(tmp_path, icingaweb_url='https://icinga.example.org/').description(make_service(), 'CRITICAL')
        assert 'https://icinga.example.org/icingadb/service?' in text

    def test_special_characters_in_the_link(self, tmp_path):
        attrs = make_service(host='mw1', name='a&b=c/d')
        text = make_bot(tmp_path).description(attrs, 'CRITICAL')
        assert 'name=a%26b%3Dc%2Fd&host.name=mw1' in text

    def test_the_storm_description_explains_itself_and_is_recognisable(self, tmp_path):
        text = make_bot(tmp_path, storm_limit=7, storm_window_minutes=20).storm_description()
        assert 'More than 7 services started alerting within 20 minutes' in text
        assert is_storm_task(as_task(text)) is True
        assert task_key(as_task(text)) is None


class TestProcess:
    def test_ignores_services_that_do_not_opt_in(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode=None))
        assert bot.phorge.calls == []

    def test_ignores_missing_vars(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode=None, vars=None))
        assert bot.phorge.calls == []

    def test_ignores_unknown_modes(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='sometimes'))
        assert bot.phorge.calls == []

    def test_soft_states_are_ignored(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(state_type=0.0))
        assert bot.phorge.calls == []

    @pytest.mark.parametrize(('mode', 'state', 'opens'), [
        ('critical', 1, False),
        ('critical', 2, True),
        ('critical', 3, False),
        ('any', 1, True),
        ('any', 2, True),
        ('any', 3, False),
    ])
    def test_modes(self, tmp_path, mode, state, opens):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode=mode, state=state))
        assert len(bot.phorge.created()) == (1 if opens else 0)

    def test_task_contents(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='any', state=1))
        task = bot.phorge.created()[0]
        assert task['title'] == 'Disk on mw1 is WARNING'
        assert task['priority'] == 'medium'
        assert 'DISK CRITICAL - free space' in task['description']

    def test_priority_follows_the_state(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(name='a', mode='any', state=1))
        bot.process(make_service(name='b', mode='any', state=2))
        assert [task['priority'] for task in bot.phorge.created()] == ['medium', 'high']

    def test_projects_are_passed_through(self, tmp_path):
        bot = make_bot(tmp_path)
        attrs = make_service()
        attrs['vars']['phorge_projects'] = ['infra', 'databases']
        bot.process(attrs)
        assert bot.phorge.created()[0]['slugs'] == ['infra', 'databases']

    @pytest.mark.parametrize('projects', [None, []])
    def test_no_projects(self, tmp_path, projects):
        bot = make_bot(tmp_path)
        attrs = make_service()
        attrs['vars']['phorge_projects'] = projects
        bot.process(attrs)
        assert bot.phorge.created()[0]['slugs'] == []

    def test_projects_var_may_be_absent(self, tmp_path):
        bot = make_bot(tmp_path)
        attrs = make_service()
        del attrs['vars']['phorge_projects']
        bot.process(attrs)
        assert bot.phorge.created()[0]['slugs'] == []

    def test_state_is_recorded(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service())
        assert bot.state.get('mw1!mw1 Disk') == {'task': 1, 'active': True, 'state': 'CRITICAL', 'alert': 'CRITICAL'}

    def test_the_created_task_can_be_found_again(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service())
        matches = bot.phorge.created()[0]['matches']
        (task,) = list(bot.phorge.open_tasks())
        assert matches(task) is True
        assert matches(as_task(marker('other!service'))) is False


class TestDowntimeAndHosts:
    def test_service_downtime_is_skipped(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(downtime_depth=1.0))
        assert bot.phorge.calls == []

    def test_host_downtime_is_skipped(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(details={'state': 0.0, 'downtime_depth': 1.0}))
        assert bot.phorge.calls == []

    def test_downtime_can_be_allowed(self, tmp_path):
        bot = make_bot(tmp_path, skip_in_downtime=False)
        bot.process(make_service(downtime_depth=1.0))
        bot.process(make_service(name='other', details={'state': 0.0, 'downtime_depth': 1.0}))
        assert len(bot.phorge.created()) == 2

    def test_a_down_host_is_skipped(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(details={'state': 1.0, 'downtime_depth': 0.0}))
        assert bot.phorge.calls == []

    def test_a_down_host_is_skipped_even_when_downtime_is_allowed(self, tmp_path):
        bot = make_bot(tmp_path, skip_in_downtime=False)
        bot.process(make_service(details={'state': 1.0, 'downtime_depth': 0.0}))
        assert bot.phorge.calls == []

    def test_an_up_host_is_fine(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(details={'state': 0.0, 'downtime_depth': 0.0}))
        assert len(bot.phorge.created()) == 1

    @pytest.mark.parametrize('details', [{}, None])
    def test_missing_host_details_do_not_block_tasks(self, tmp_path, details):
        bot = make_bot(tmp_path)
        attrs = make_service()
        attrs['host'] = details
        bot.process(attrs)
        assert len(bot.phorge.created()) == 1

    def test_a_service_without_a_host_key_still_works(self, tmp_path):
        bot = make_bot(tmp_path)
        attrs = make_service()
        del attrs['host']
        bot.process(attrs)
        assert len(bot.phorge.created()) == 1

    def test_a_host_going_down_does_not_touch_an_open_task(self, tmp_path):
        bot = make_bot(tmp_path, triggers={'critical': ['CRITICAL'], 'any': ['WARNING', 'CRITICAL']})
        bot.process(make_service(mode='any', state=1))
        bot.process(make_service(mode='any', state=2, details={'state': 1.0, 'downtime_depth': 0.0}))
        assert comments(bot.phorge) == []

    def test_recovery_is_still_reported_while_the_host_is_down(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service())
        bot.process(make_service(state=0, details={'state': 1.0, 'downtime_depth': 0.0}))
        assert comments(bot.phorge) == ['Recovered, the service is back to **OK**.']

    def test_downtime_does_not_block_recovery(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service())
        bot.process(make_service(state=0, downtime_depth=1.0))
        assert comments(bot.phorge) == ['Recovered, the service is back to **OK**.']


class TestFlapping:
    def test_a_flapping_service_is_left_alone(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(flapping=True))
        assert bot.phorge.calls == []
        assert bot.state.services == {}

    def test_an_open_task_is_not_commented_on_while_flapping(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='any', state=1))
        bot.process(make_service(mode='any', state=2, flapping=True))
        bot.process(make_service(mode='any', state=1, flapping=True))
        assert comments(bot.phorge) == []

    def test_recovery_waits_until_flapping_stops(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service())
        bot.process(make_service(state=0, flapping=True))
        assert comments(bot.phorge) == []
        bot.process(make_service(state=0, flapping=False))
        assert comments(bot.phorge) == ['Recovered, the service is back to **OK**.']

    def test_a_task_opens_once_flapping_stops_if_it_is_still_failing(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(flapping=True))
        assert bot.phorge.created() == []
        bot.process(make_service(flapping=False))
        assert len(bot.phorge.created()) == 1

    def test_a_missing_flag_means_not_flapping(self, tmp_path):
        bot = make_bot(tmp_path)
        attrs = make_service()
        del attrs['flapping']
        bot.process(attrs)
        assert len(bot.phorge.created()) == 1


class TestGrace:
    @staticmethod
    def failing_for(minutes, **changes):
        return make_service(last_state_ok=NOW - minutes * 60, **changes)

    @pytest.mark.usefixtures('clock')
    def test_nothing_happens_before_the_grace_period_ends(self, tmp_path):
        bot = make_bot(tmp_path, grace_minutes=15)
        bot.process(self.failing_for(14.9))
        assert bot.phorge.calls == []
        assert bot.state.services == {}

    @pytest.mark.usefixtures('clock')
    def test_a_task_opens_once_it_has_lasted_long_enough(self, tmp_path):
        bot = make_bot(tmp_path, grace_minutes=15)
        bot.process(self.failing_for(15))
        assert len(bot.phorge.created()) == 1

    def test_the_same_problem_becomes_a_task_as_time_passes(self, tmp_path, clock):
        bot = make_bot(tmp_path, grace_minutes=15)
        attrs = self.failing_for(5)
        bot.process(attrs)
        clock.now += 11 * 60
        bot.process(attrs)
        assert len(bot.phorge.created()) == 1

    @pytest.mark.usefixtures('clock')
    def test_the_clock_starts_at_the_last_ok_result(self, tmp_path):
        bot = make_bot(tmp_path, grace_minutes=15)
        bot.process(make_service(last_state_ok=NOW - 20 * 60, last_state_change=NOW - 60))
        assert len(bot.phorge.created()) == 1

    @pytest.mark.usefixtures('clock')
    def test_going_from_warning_to_critical_does_not_restart_the_clock(self, tmp_path):
        bot = make_bot(tmp_path, grace_minutes=15)
        bot.process(self.failing_for(30, mode='any', state=1))
        bot.process(self.failing_for(30, mode='any', state=2, last_state_change=NOW - 30))
        assert comments(bot.phorge) == ['Now **CRITICAL**.\n\n```\nDISK CRITICAL - free space: / 1 GB\n```']

    @pytest.mark.usefixtures('clock')
    def test_a_service_that_was_never_ok_counts_from_its_last_change(self, tmp_path):
        bot = make_bot(tmp_path, grace_minutes=15)
        bot.process(make_service(last_state_ok=0.0, last_state_change=NOW - 5 * 60))
        assert bot.phorge.calls == []
        bot.process(make_service(last_state_ok=0.0, last_state_change=NOW - 16 * 60))
        assert len(bot.phorge.created()) == 1

    @pytest.mark.usefixtures('clock')
    def test_no_timestamps_means_act_immediately(self, tmp_path):
        bot = make_bot(tmp_path, grace_minutes=15)
        bot.process(make_service(last_state_ok=0.0, last_state_change=0.0))
        assert len(bot.phorge.created()) == 1

    @pytest.mark.usefixtures('clock')
    def test_missing_timestamps_mean_act_immediately(self, tmp_path):
        bot = make_bot(tmp_path, grace_minutes=15)
        attrs = make_service()
        del attrs['last_state_ok']
        del attrs['last_state_change']
        bot.process(attrs)
        assert len(bot.phorge.created()) == 1

    @pytest.mark.usefixtures('clock')
    def test_zero_grace_acts_at_once(self, tmp_path):
        bot = make_bot(tmp_path, grace_minutes=0)
        bot.process(self.failing_for(0))
        assert len(bot.phorge.created()) == 1

    @pytest.mark.usefixtures('clock')
    def test_the_grace_period_can_be_fractional(self, tmp_path):
        bot = make_bot(tmp_path, grace_minutes=0.5)
        bot.process(make_service(last_state_ok=NOW - 20))
        assert bot.phorge.calls == []
        bot.process(make_service(last_state_ok=NOW - 31))
        assert len(bot.phorge.created()) == 1

    @pytest.mark.usefixtures('clock')
    def test_a_clock_running_ahead_of_icinga_waits_rather_than_acts(self, tmp_path):
        bot = make_bot(tmp_path, grace_minutes=15)
        bot.process(make_service(last_state_ok=NOW + 600))
        assert bot.phorge.calls == []

    def test_a_blip_during_the_grace_period_restarts_it(self, tmp_path, clock):
        bot = make_bot(tmp_path, grace_minutes=15)
        bot.process(self.failing_for(14))
        clock.now += 120
        bot.process(make_service(last_state_ok=clock.now - 60))
        assert bot.phorge.calls == []

    @pytest.mark.usefixtures('clock')
    def test_recovering_during_the_grace_period_creates_nothing(self, tmp_path):
        bot = make_bot(tmp_path, grace_minutes=15)
        bot.process(self.failing_for(5))
        bot.process(make_service(state=0, last_state_ok=NOW))
        assert bot.phorge.calls == []
        assert bot.state.services == {}

    @pytest.mark.usefixtures('clock')
    def test_recovery_is_not_delayed_by_the_grace_period(self, tmp_path):
        bot = make_bot(tmp_path, grace_minutes=15)
        bot.process(self.failing_for(20))
        bot.process(make_service(state=0, last_state_ok=NOW))
        assert comments(bot.phorge) == ['Recovered, the service is back to **OK**.']

    def test_alerting_again_also_waits_for_the_grace_period(self, tmp_path, clock):
        bot = make_bot(tmp_path, grace_minutes=15)
        bot.process(self.failing_for(20))
        bot.process(make_service(state=0, last_state_ok=NOW))
        clock.now += 300
        bot.process(make_service(last_state_ok=NOW))
        assert comments(bot.phorge) == ['Recovered, the service is back to **OK**.']
        clock.now += 11 * 60
        bot.process(make_service(last_state_ok=NOW))
        assert comments(bot.phorge)[-1].startswith('Alerting again, **CRITICAL**.')

    @pytest.mark.usefixtures('clock')
    def test_the_reason_is_logged_at_debug(self, tmp_path, caplog):
        bot = make_bot(tmp_path, grace_minutes=15)
        with caplog.at_level(logging.DEBUG, logger='taskbot'):
            bot.process(self.failing_for(7))
        assert 'mw1!mw1 Disk is CRITICAL but it has only been failing for 7 minutes, skipping' in caplog.text


class TestProblemAndClear:
    def test_repeated_alerts_do_not_duplicate(self, tmp_path):
        bot = make_bot(tmp_path)
        for _ in range(3):
            bot.process(make_service())
        assert len(bot.phorge.created()) == 1
        assert comments(bot.phorge) == []

    def test_escalation_is_commented_on_the_same_task(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='any', state=1))
        bot.process(make_service(mode='any', state=2))
        assert len(bot.phorge.created()) == 1
        assert comments(bot.phorge) == ['Now **CRITICAL**.\n\n```\nDISK CRITICAL - free space: / 1 GB\n```']
        assert bot.phorge.calls[-1][1] == 1
        assert bot.state.get('mw1!mw1 Disk')['state'] == 'CRITICAL'

    def test_escalation_updates_the_title_and_raises_the_priority(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='any', state=1))
        assert bot.phorge.tasks[1]['title'] == 'Disk on mw1 is WARNING'
        assert bot.phorge.tasks[1]['priority'] == taskbot.PRIORITIES['medium']
        bot.process(make_service(mode='any', state=2))
        assert bot.phorge.tasks[1]['title'] == 'Disk on mw1 is CRITICAL'
        assert bot.phorge.tasks[1]['priority'] == taskbot.PRIORITIES['high']

    def test_a_title_someone_edited_is_left_alone(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='any', state=1))
        bot.phorge.tasks[1]['title'] = 'Disk on mw1 is WARNING, Alice is on it'
        bot.process(make_service(mode='any', state=2))
        assert bot.phorge.tasks[1]['title'] == 'Disk on mw1 is WARNING, Alice is on it'
        assert bot.phorge.tasks[1]['priority'] == taskbot.PRIORITIES['high']

    def test_a_higher_priority_someone_set_is_never_lowered(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='any', state=1))
        bot.phorge.tasks[1]['priority'] = taskbot.PRIORITIES['unbreak']
        bot.process(make_service(mode='any', state=2))
        assert bot.phorge.tasks[1]['priority'] == taskbot.PRIORITIES['unbreak']

    def test_dropping_from_critical_to_warning_fixes_the_title_and_lowers_the_priority(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='any', state=2))
        bot.process(make_service(mode='any', state=1))
        assert bot.phorge.tasks[1]['title'] == 'Disk on mw1 is WARNING'
        assert bot.phorge.tasks[1]['priority'] == taskbot.PRIORITIES['medium']
        assert comments(bot.phorge)[0].startswith('Now **WARNING**.')

    def test_the_priority_goes_back_up_when_it_returns_to_critical(self, tmp_path):
        bot = make_bot(tmp_path)
        for state in (2, 1, 2):
            bot.process(make_service(mode='any', state=state))
        assert bot.phorge.tasks[1]['priority'] == taskbot.PRIORITIES['high']
        assert bot.phorge.tasks[1]['title'] == 'Disk on mw1 is CRITICAL'

    def test_a_priority_someone_set_is_not_lowered_when_it_improves(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='any', state=2))
        bot.phorge.tasks[1]['priority'] = taskbot.PRIORITIES['unbreak']
        bot.process(make_service(mode='any', state=1))
        assert bot.phorge.tasks[1]['priority'] == taskbot.PRIORITIES['unbreak']

    def test_a_lower_priority_someone_set_is_raised_again_when_it_gets_worse(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='any', state=1))
        bot.phorge.tasks[1]['priority'] = taskbot.PRIORITIES['low']
        bot.process(make_service(mode='any', state=2))
        assert bot.phorge.tasks[1]['priority'] == taskbot.PRIORITIES['high']

    def test_a_priority_someone_lowered_is_left_alone_when_it_improves(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='any', state=2))
        bot.phorge.tasks[1]['priority'] = taskbot.PRIORITIES['lowest']
        bot.process(make_service(mode='any', state=1))
        assert bot.phorge.tasks[1]['priority'] == taskbot.PRIORITIES['lowest']

    def test_nothing_is_sent_for_a_priority_that_is_already_right(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='any', state=2))
        bot.process(make_service(mode='any', state=1))
        bot.process(make_service(mode='any', state=1, last_state_change=5.0))
        assert len(comments(bot.phorge)) == 1

    def test_only_the_changes_are_sent(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='any', state=1))
        bot.phorge.tasks[1]['priority'] = taskbot.PRIORITIES['high']
        bot.process(make_service(mode='any', state=2))
        assert [transaction['type'] for transaction in bot.phorge.calls[-1][2]] == ['comment', 'title']

    def test_alerting_again_in_the_same_state_sends_only_a_comment(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service())
        bot.process(make_service(state=0))
        bot.process(make_service())
        assert [t['type'] for t in bot.phorge.calls[-1][2]] == ['comment']

    def test_recovery_is_commented_not_closed_by_default(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service())
        bot.process(make_service(state=0))
        assert comments(bot.phorge) == ['Recovered, the service is back to **OK**.']
        assert [t['type'] for t in bot.phorge.calls[-1][2]] == ['comment']
        assert bot.state.get('mw1!mw1 Disk') == {'task': 1, 'active': False, 'state': 'OK', 'alert': 'CRITICAL'}
        assert bot.phorge.is_open(1)

    @pytest.mark.usefixtures('clock')
    def test_recovery_can_close_the_task(self, tmp_path):
        bot = make_bot(tmp_path, close_after_recovery_seconds=0, close_status='wontfix')
        bot.process(make_service())
        bot.process(make_service(state=0))
        assert bot.phorge.calls[-1][2][1] == {'type': 'status', 'value': 'wontfix'}
        assert bot.phorge.tasks[1]['status'] == 'wontfix'
        assert bot.state.get('mw1!mw1 Disk')['closed'] == NOW

    def test_only_recovery_closes(self, tmp_path):
        bot = make_bot(tmp_path, close_after_recovery_seconds=0)
        bot.process(make_service(mode='critical', state=2))
        bot.process(make_service(mode='critical', state=1))
        assert [t['type'] for t in bot.phorge.calls[-1][2]] == ['comment']
        assert 'closed' not in bot.state.get('mw1!mw1 Disk')

    @pytest.mark.parametrize('state', [1, 3])
    def test_dropping_below_the_alert_level(self, tmp_path, state):
        bot = make_bot(tmp_path)
        bot.process(make_service())
        bot.process(make_service(state=state))
        name = taskbot.STATES[state]
        assert comments(bot.phorge) == [f'Now **{name}**, which is not an alert state for this service.']
        assert bot.state.get('mw1!mw1 Disk')['active'] is False

    def test_alerting_again_reuses_an_open_task(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service())
        bot.process(make_service(state=0))
        bot.process(make_service())
        assert len(bot.phorge.created()) == 1
        assert comments(bot.phorge)[-1].startswith('Alerting again, **CRITICAL**.')
        assert bot.state.get('mw1!mw1 Disk')['active'] is True

    def test_alerting_again_in_a_worse_state_fixes_the_title(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='any', state=1))
        bot.process(make_service(mode='any', state=0))
        bot.process(make_service(mode='any', state=2))
        assert bot.phorge.tasks[1]['title'] == 'Disk on mw1 is CRITICAL'

    def test_a_task_someone_closed_while_alerting_gets_no_new_one_until_the_state_changes(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='any', state=2))
        bot.phorge.close(1, 'wontfix')
        for _ in range(3):
            bot.process(make_service(mode='any', state=2))
        assert len(bot.phorge.created()) == 1

    def test_a_task_someone_closed_is_replaced_when_the_state_changes(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='any', state=1))
        bot.phorge.close(1, 'wontfix')
        bot.process(make_service(mode='any', state=2))
        assert len(bot.phorge.created()) == 2
        assert bot.state.get('mw1!mw1 Disk')['task'] == 2

    def test_a_task_someone_closed_is_replaced_after_a_recovery(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service())
        bot.phorge.close(1, 'wontfix')
        bot.process(make_service(state=0))
        bot.process(make_service())
        assert len(bot.phorge.created()) == 2

    def test_recovery_without_a_task_does_nothing(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(state=0))
        assert bot.phorge.calls == []
        assert bot.state.services == {}

    def test_recovery_is_only_reported_once(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service())
        bot.process(make_service(state=0))
        bot.process(make_service(state=0))
        assert len(comments(bot.phorge)) == 1

    def test_services_are_tracked_separately(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(host='mw1'))
        bot.process(make_service(host='mw2'))
        bot.process(make_service(host='mw1', state=0))
        assert len(bot.phorge.created()) == 2
        assert bot.state.get('mw1!mw1 Disk')['active'] is False
        assert bot.state.get('mw2!mw1 Disk')['active'] is True

    def test_no_duplicate_task_after_a_restart(self, tmp_path):
        first = make_bot(tmp_path)
        first.process(make_service())
        second = make_bot(tmp_path)
        second.phorge = first.phorge
        second.process(make_service())
        assert len(second.phorge.created()) == 1
        assert comments(second.phorge) == []

    def test_restart_keeps_recovery_working(self, tmp_path):
        first = make_bot(tmp_path)
        first.process(make_service())
        second = make_bot(tmp_path)
        second.phorge = first.phorge
        second.process(make_service(state=0))
        assert comments(second.phorge) == ['Recovered, the service is back to **OK**.']
        assert second.phorge.calls[-1][1] == 1

    def test_dry_run_keeps_state_in_memory_only(self, tmp_path):
        bot = make_bot(tmp_path, dry_run=True)
        bot.process(make_service())
        assert bot.state.get('mw1!mw1 Disk')['active'] is True
        assert not (tmp_path / 'state.json').exists()


class TestReopen:
    @staticmethod
    def closed_task(tmp_path, **config):
        bot = make_bot(tmp_path, close_after_recovery_seconds=0, **config)
        bot.process(make_service())
        bot.process(make_service(state=0))
        assert bot.phorge.tasks[1]['status'] == 'resolved'
        return bot

    def test_a_recent_task_the_bot_closed_is_reopened(self, tmp_path, clock):
        bot = self.closed_task(tmp_path)
        clock.now += 3600
        bot.process(make_service())
        assert len(bot.phorge.created()) == 1
        assert bot.phorge.tasks[1]['status'] == 'open'
        assert [t['type'] for t in bot.phorge.calls[-1][2]][:2] == ['status', 'comment']
        assert bot.phorge.calls[-1][2][0]['value'] == 'open'
        assert comments(bot.phorge)[-1].startswith('Alerting again, **CRITICAL**.')
        assert bot.state.get('mw1!mw1 Disk') == {'task': 1, 'active': True, 'state': 'CRITICAL', 'alert': 'CRITICAL'}

    def test_a_task_closed_long_ago_is_not_reopened(self, tmp_path, clock):
        bot = self.closed_task(tmp_path)
        clock.now += 25 * 3600
        bot.process(make_service())
        assert len(bot.phorge.created()) == 2
        assert bot.phorge.tasks[1]['status'] == 'resolved'

    def test_the_window_is_configurable(self, tmp_path, clock):
        bot = self.closed_task(tmp_path, reopen_hours=1)
        clock.now += 2 * 3600
        bot.process(make_service())
        assert len(bot.phorge.created()) == 2

    def test_a_task_someone_else_changed_is_not_reopened(self, tmp_path, clock):
        bot = self.closed_task(tmp_path)
        bot.phorge.tasks[1]['status'] = 'wontfix'
        clock.now += 60
        bot.process(make_service())
        assert len(bot.phorge.created()) == 2

    @pytest.mark.usefixtures('clock')
    def test_a_task_that_vanished_is_not_reopened(self, tmp_path):
        bot = self.closed_task(tmp_path)
        del bot.phorge.tasks[1]
        bot.process(make_service())
        assert len(bot.phorge.created()) == 2

    @pytest.mark.usefixtures('clock')
    def test_a_task_the_bot_did_not_close_is_not_reopened(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service())
        bot.process(make_service(state=0))
        bot.phorge.close(1)
        bot.process(make_service())
        assert len(bot.phorge.created()) == 2

    def test_a_reopened_task_can_be_closed_again(self, tmp_path, clock):
        bot = self.closed_task(tmp_path)
        clock.now += 600
        bot.process(make_service())
        clock.now += 600
        bot.process(make_service(state=0))
        assert bot.phorge.tasks[1]['status'] == 'resolved'
        assert bot.state.get('mw1!mw1 Disk')['closed'] == clock.now

    def test_reopening_refreshes_the_title_and_priority(self, tmp_path, clock):
        bot = make_bot(tmp_path, close_after_recovery_seconds=0)
        bot.process(make_service(mode='any', state=1))
        bot.process(make_service(mode='any', state=0))
        clock.now += 60
        bot.process(make_service(mode='any', state=2))
        assert bot.phorge.tasks[1]['title'] == 'Disk on mw1 is CRITICAL'
        assert bot.phorge.tasks[1]['priority'] == taskbot.PRIORITIES['high']
        assert bot.phorge.tasks[1]['status'] == 'open'

    def test_the_close_status_is_what_counts(self, tmp_path, clock):
        bot = make_bot(tmp_path, close_after_recovery_seconds=0, close_status='wontfix')
        bot.process(make_service())
        bot.process(make_service(state=0))
        clock.now += 60
        bot.process(make_service())
        assert len(bot.phorge.created()) == 1
        assert bot.phorge.tasks[1]['status'] == 'open'

    def test_reopening_respects_the_grace_period(self, tmp_path, clock):
        bot = self.closed_task(tmp_path, grace_minutes=15)
        clock.now += 300
        bot.process(make_service(last_state_ok=clock.now - 120))
        assert bot.phorge.tasks[1]['status'] == 'resolved'


class TestStorm:
    @staticmethod
    def many(bot, count, **changes):
        for number in range(1, count + 1):
            bot.process(make_service(name=f'svc{number}', **changes))

    @staticmethod
    def comment_for(name, state='CRITICAL'):
        return f'`mw1!{name}` is **{state}**.\n\n```\nDISK CRITICAL - free space: / 1 GB\n```'

    @pytest.mark.usefixtures('clock')
    def test_tasks_open_normally_up_to_the_limit(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=3)
        self.many(bot, 3)
        assert [task['title'] for task in bot.phorge.created()] == ['Disk on mw1 is CRITICAL'] * 3
        assert bot.state.storm is None

    @pytest.mark.usefixtures('clock')
    def test_beyond_the_limit_services_are_collected_in_one_summary(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=2)
        self.many(bot, 5)
        created = bot.phorge.created()
        assert [task['title'] for task in created] == ['Disk on mw1 is CRITICAL'] * 2 + [taskbot.STORM_TITLE]
        assert comments(bot.phorge) == [self.comment_for('svc3'), self.comment_for('svc4'), self.comment_for('svc5')]
        assert {call[1] for call in bot.phorge.calls if call[0] == 'edit'} == {3}
        assert bot.state.storm == 3

    @pytest.mark.usefixtures('clock')
    def test_the_summary_task_itself(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=1)
        self.many(bot, 2)
        summary = bot.phorge.created()[1]
        assert summary['priority'] == 'high'
        assert summary['slugs'] == []
        assert summary['description'] == bot.storm_description()
        assert summary['matches'] is is_storm_task

    @pytest.mark.usefixtures('clock')
    def test_each_collected_service_is_remembered(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=1)
        self.many(bot, 2)
        assert bot.state.get('mw1!svc2') == {'task': 2, 'active': True, 'state': 'CRITICAL', 'alert': 'CRITICAL', 'storm': True}

    @pytest.mark.usefixtures('clock')
    def test_the_summary_does_not_count_towards_the_limit(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=2)
        self.many(bot, 4)
        assert len(bot.state.created) == 2

    def test_old_creations_stop_counting(self, tmp_path, clock):
        bot = make_bot(tmp_path, storm_limit=2, storm_window_minutes=10)
        self.many(bot, 2)
        clock.now += 11 * 60
        bot.process(make_service(name='later'))
        assert [task['title'] for task in bot.phorge.created()] == ['Disk on mw1 is CRITICAL'] * 3
        assert bot.state.storm is None

    def test_recent_creations_still_count(self, tmp_path, clock):
        bot = make_bot(tmp_path, storm_limit=2, storm_window_minutes=10)
        self.many(bot, 2)
        clock.now += 9 * 60
        bot.process(make_service(name='later'))
        assert bot.phorge.created()[-1]['title'] == taskbot.STORM_TITLE

    @pytest.mark.usefixtures('clock')
    def test_a_recovering_member_is_noted_on_the_summary(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=1, close_after_recovery_seconds=0)
        self.many(bot, 3)
        bot.process(make_service(name='svc2', state=0))
        assert comments(bot.phorge)[-1] == '`mw1!svc2` recovered.'
        assert bot.phorge.tasks[2]['status'] == 'open'
        assert bot.state.get('mw1!svc2') == {'task': 2, 'active': False, 'state': 'OK', 'alert': 'CRITICAL', 'storm': True}

    @pytest.mark.usefixtures('clock')
    def test_the_summary_closes_when_every_member_has_recovered(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=1, close_after_recovery_seconds=0, close_status='wontfix')
        self.many(bot, 3)
        bot.process(make_service(name='svc2', state=0))
        bot.process(make_service(name='svc3', state=0))
        assert comments(bot.phorge)[-1] == '`mw1!svc3` recovered.'
        assert bot.phorge.calls[-1][2][1] == {'type': 'status', 'value': 'wontfix'}
        assert bot.phorge.tasks[2]['status'] == 'wontfix'
        assert bot.state.storm is None

    @pytest.mark.usefixtures('clock')
    def test_the_summary_stays_open_when_closing_is_off(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=1, close_after_recovery_seconds=None)
        self.many(bot, 3)
        bot.process(make_service(name='svc2', state=0))
        bot.process(make_service(name='svc3', state=0))
        assert bot.phorge.tasks[2]['status'] == 'open'
        assert bot.state.storm == 2

    @pytest.mark.usefixtures('clock')
    def test_a_normal_task_recovering_leaves_the_summary_alone(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=1, close_after_recovery_seconds=0)
        self.many(bot, 2)
        bot.process(make_service(name='svc1', state=0))
        assert bot.phorge.tasks[1]['status'] == 'resolved'
        assert bot.phorge.tasks[2]['status'] == 'open'

    @pytest.mark.usefixtures('clock')
    def test_a_member_dropping_below_the_alert_level_is_noted(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=1)
        self.many(bot, 2)
        bot.process(make_service(name='svc2', state=1))
        assert comments(bot.phorge)[-1] == '`mw1!svc2` is now **WARNING**, which is not an alert state.'
        assert bot.state.get('mw1!svc2')['active'] is False

    @pytest.mark.usefixtures('clock')
    def test_a_member_getting_worse_is_noted_without_touching_the_summary_title(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=1)
        bot.process(make_service(name='svc1', mode='any', state=2))
        bot.process(make_service(name='svc2', mode='any', state=1))
        bot.process(make_service(name='svc2', mode='any', state=2))
        assert comments(bot.phorge)[-1] == '`mw1!svc2` is now **CRITICAL**.'
        assert bot.phorge.tasks[2]['title'] == taskbot.STORM_TITLE
        assert bot.state.get('mw1!svc2')['state'] == 'CRITICAL'

    @pytest.mark.usefixtures('clock')
    def test_a_member_alerting_again_goes_back_to_the_summary(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=1)
        self.many(bot, 3)
        bot.process(make_service(name='svc2', state=0))
        bot.process(make_service(name='svc2'))
        assert len(bot.phorge.created()) == 2
        assert comments(bot.phorge)[-1] == self.comment_for('svc2')
        assert bot.state.get('mw1!svc2')['active'] is True

    def test_a_member_alerting_again_after_the_storm_gets_its_own_task(self, tmp_path, clock):
        bot = make_bot(tmp_path, storm_limit=1)
        self.many(bot, 3)
        bot.process(make_service(name='svc2', state=0))
        clock.now += 15 * 60
        bot.process(make_service(name='svc2'))
        assert len(bot.phorge.created()) == 3
        assert bot.state.get('mw1!svc2') == {'task': 3, 'active': True, 'state': 'CRITICAL', 'alert': 'CRITICAL'}

    @pytest.mark.usefixtures('clock')
    def test_one_summary_is_reused_not_recreated(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=1)
        self.many(bot, 6)
        assert [task['title'] for task in bot.phorge.created()].count(taskbot.STORM_TITLE) == 1

    @pytest.mark.usefixtures('clock')
    def test_a_summary_someone_closed_is_replaced(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=1)
        self.many(bot, 2)
        bot.phorge.close(2, 'wontfix')
        bot.process(make_service(name='svc3'))
        assert [task['title'] for task in bot.phorge.created()].count(taskbot.STORM_TITLE) == 2
        assert bot.state.storm == 3

    @pytest.mark.usefixtures('clock')
    def test_an_open_summary_is_found_again_if_the_pointer_is_lost(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=1)
        self.many(bot, 2)
        bot.state.set_storm(None)
        bot.process(make_service(name='svc3'))
        assert [task['title'] for task in bot.phorge.created()].count(taskbot.STORM_TITLE) == 1
        assert bot.state.storm == 2

    @pytest.mark.usefixtures('clock')
    def test_a_restart_in_the_middle_of_a_storm_carries_on(self, tmp_path):
        first = make_bot(tmp_path, storm_limit=2)
        self.many(first, 3)
        second = make_bot(tmp_path, storm_limit=2)
        second.phorge = first.phorge
        second.process(make_service(name='svc4'))
        assert [task['title'] for task in second.phorge.created()].count(taskbot.STORM_TITLE) == 1
        assert comments(second.phorge)[-1] == self.comment_for('svc4')

    @pytest.mark.usefixtures('clock')
    def test_a_failed_creation_is_not_counted(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=2)
        bot.phorge.create_errors = [PhorgeError('down')]
        with pytest.raises(PhorgeError, match='down'):
            bot.process(make_service(name='svc1'))
        assert bot.state.created == []

    @pytest.mark.usefixtures('clock')
    def test_dry_run_storms_are_logged_not_sent(self, tmp_path, caplog):
        bot = make_bot(tmp_path, storm_limit=1, dry_run=True)
        bot.phorge = Phorge(BASE_CONFIG['phorge'], dry_run=True)
        bot.phorge.find = FakePhorge().find
        with caplog.at_level(logging.INFO, logger='taskbot'):
            bot.process(make_service(name='svc1'))
            bot.process(make_service(name='svc2'))
        assert caplog.text.count('Dry run, would send') == 3
        assert 'Created alert storm task T0' in caplog.text


class TestAdoption:
    def test_open_tasks_with_a_marker_are_taken_over(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.phorge.add_task(title='Disk on mw1 is CRITICAL', key='mw1!mw1 Disk')
        bot.phorge.add_task(title='Load on mw2 is WARNING', key='mw2!mw2 Load')
        bot.prepare()
        assert bot.state.get('mw1!mw1 Disk') == {'task': 1, 'active': True, 'state': 'CRITICAL', 'alert': 'CRITICAL'}
        assert bot.state.get('mw2!mw2 Load') == {'task': 2, 'active': True, 'state': 'WARNING', 'alert': 'WARNING'}
        assert bot.adopted is True

    def test_an_adopted_alert_that_is_still_firing_causes_nothing(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.phorge.add_task()
        bot.icinga.add(make_service())
        bot.prepare()
        bot.reconcile()
        assert bot.phorge.calls == []

    def test_an_adopted_alert_that_recovered_is_closed_out(self, tmp_path):
        bot = make_bot(tmp_path, close_after_recovery_seconds=0)
        bot.phorge.add_task()
        bot.icinga.add(make_service(state=0))
        bot.prepare()
        bot.reconcile()
        assert comments(bot.phorge) == ['Recovered, the service is back to **OK**.']
        assert bot.phorge.tasks[1]['status'] == 'resolved'

    def test_an_adopted_alert_in_a_different_state_is_updated(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.phorge.add_task(title='Disk on mw1 is WARNING', priority='medium')
        bot.icinga.add(make_service(mode='any', state=2))
        bot.prepare()
        bot.reconcile()
        assert comments(bot.phorge)[0].startswith('Now **CRITICAL**.')
        assert bot.phorge.tasks[1]['title'] == 'Disk on mw1 is CRITICAL'

    def test_a_title_that_cannot_be_read_costs_one_comment(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.phorge.add_task(title='Somebody renamed this')
        bot.icinga.add(make_service())
        bot.prepare()
        bot.reconcile()
        bot.reconcile()
        assert len(comments(bot.phorge)) == 1
        assert bot.phorge.tasks[1]['title'] == 'Somebody renamed this'

    def test_existing_state_is_not_overwritten(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.state.put('mw1!mw1 Disk', {'task': 77, 'active': False, 'state': 'OK', 'alert': 'CRITICAL'})
        bot.phorge.add_task()
        bot.prepare()
        assert bot.state.get('mw1!mw1 Disk')['task'] == 77

    def test_tasks_without_a_marker_are_ignored(self, tmp_path):
        bot = make_bot(tmp_path)
        task = bot.phorge.add_task(title='Hand made task is CRITICAL')
        bot.phorge.tasks[task]['description'] = 'Somebody wrote this by hand.'
        bot.prepare()
        assert bot.state.services == {}

    def test_the_oldest_task_wins_when_there_are_duplicates(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.phorge.add_task()
        bot.phorge.add_task()
        bot.prepare()
        assert bot.state.get('mw1!mw1 Disk')['task'] == 1

    def test_the_storm_summary_is_taken_over(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.phorge.add_task(title=taskbot.STORM_TITLE, storm=True)
        bot.prepare()
        assert bot.state.storm == 1
        assert bot.state.services == {}

    def test_a_known_storm_summary_is_kept(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.state.set_storm(9)
        bot.phorge.add_task(title=taskbot.STORM_TITLE, storm=True)
        bot.prepare()
        assert bot.state.storm == 9

    @pytest.mark.usefixtures('clock')
    def test_the_adopted_summary_is_used_for_the_next_storm(self, tmp_path):
        bot = make_bot(tmp_path, storm_limit=1)
        bot.phorge.add_task(title=taskbot.STORM_TITLE, storm=True)
        bot.prepare()
        bot.process(make_service(name='svc1'))
        bot.process(make_service(name='svc2'))
        assert bot.phorge.created()[-1]['title'] != taskbot.STORM_TITLE
        assert comments(bot.phorge) == [TestStorm.comment_for('svc2')]

    def test_adoption_is_saved_to_disk(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.phorge.add_task()
        bot.prepare()
        assert State(str(tmp_path / 'state.json')).get('mw1!mw1 Disk')['task'] == 1

    def test_a_lost_state_file_is_rebuilt_from_phorge(self, tmp_path):
        first = make_bot(tmp_path)
        first.process(make_service())
        (tmp_path / 'state.json').unlink()
        second = make_bot(tmp_path)
        second.phorge = first.phorge
        second.icinga.add(make_service())
        second.prepare()
        second.reconcile()
        assert len(second.phorge.created()) == 1
        assert comments(second.phorge) == []

    def test_a_corrupt_state_file_is_rebuilt_from_phorge(self, tmp_path):
        first = make_bot(tmp_path)
        first.process(make_service())
        (tmp_path / 'state.json').write_text('{oops')
        second = make_bot(tmp_path)
        second.phorge = first.phorge
        second.icinga.add(make_service())
        second.prepare()
        second.reconcile()
        assert len(second.phorge.created()) == 1

    def test_adoption_only_happens_once(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.phorge.add_task()
        bot.prepare()
        bot.state.services.clear()
        bot.prepare()
        assert bot.state.services == {}

    def test_a_failed_lookup_is_retried(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.phorge.add_task()
        bot.phorge.read_errors = [PhorgeError('down')]
        with pytest.raises(PhorgeError, match='down'):
            bot.prepare()
        assert bot.adopted is False
        bot.prepare()
        assert bot.adopted is True
        assert bot.state.get('mw1!mw1 Disk')['task'] == 1

    def test_adoption_is_logged(self, tmp_path, caplog):
        bot = make_bot(tmp_path)
        bot.phorge.add_task()
        with caplog.at_level(logging.INFO, logger='taskbot'):
            bot.prepare()
        assert 'Adopted T1 for mw1!mw1 Disk (CRITICAL)' in caplog.text


class TestDuplicateSafety:
    def test_an_open_task_for_the_service_is_adopted_instead_of_duplicated(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.phorge.add_task()
        bot.process(make_service())
        assert bot.phorge.created() == []
        assert bot.state.get('mw1!mw1 Disk')['task'] == 1

    def test_an_adopted_task_in_another_state_is_updated(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.phorge.add_task(title='Disk on mw1 is WARNING', priority='medium')
        bot.process(make_service(mode='any', state=2))
        assert bot.phorge.created() == []
        assert comments(bot.phorge)[0].startswith('Now **CRITICAL**.')
        assert bot.phorge.tasks[1]['title'] == 'Disk on mw1 is CRITICAL'

    def test_a_task_for_another_service_is_not_adopted(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.phorge.add_task(key='mw2!mw2 Disk')
        bot.process(make_service())
        assert len(bot.phorge.created()) == 1

    def test_a_closed_task_is_not_adopted(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.phorge.add_task(status='resolved')
        bot.process(make_service())
        assert len(bot.phorge.created()) == 1

    def test_a_lost_reply_does_not_lead_to_a_duplicate(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.phorge.lost_replies = 1
        bot.safe(bot.process, make_service())
        assert bot.state.services == {}
        bot.process(make_service())
        assert len(bot.phorge.tasks) == 1
        assert bot.state.get('mw1!mw1 Disk')['task'] == 1
        assert comments(bot.phorge) == []

    def test_nothing_is_created_when_the_lookup_fails(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.phorge.read_errors = [PhorgeError('down')]
        with pytest.raises(PhorgeError, match='down'):
            bot.process(make_service())
        assert bot.phorge.created() == []


class TestHeartbeat:
    @staticmethod
    def beat_file(tmp_path):
        return tmp_path / 'last_sync'

    @pytest.mark.usefixtures('clock')
    def test_written_after_a_clean_sync(self, tmp_path):
        make_bot(tmp_path).reconcile()
        assert self.beat_file(tmp_path).read_text() == f'{int(NOW)}\n'

    def test_rewritten_on_every_sync(self, tmp_path, clock):
        bot = make_bot(tmp_path)
        bot.reconcile()
        clock.now += 60
        bot.reconcile()
        assert self.beat_file(tmp_path).read_text() == f'{int(NOW) + 60}\n'

    @pytest.mark.usefixtures('clock')
    def test_not_written_when_icinga_cannot_be_reached(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.icinga.query_errors = [OSError('down')]
        with pytest.raises(OSError, match='down'):
            bot.reconcile()
        assert not self.beat_file(tmp_path).exists()

    @pytest.mark.usefixtures('clock')
    def test_not_written_when_a_service_could_not_be_handled(self, tmp_path, caplog):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service())
        bot.phorge.create_errors = [PhorgeError('down')]
        with caplog.at_level(logging.WARNING, logger='taskbot'):
            bot.reconcile()
        assert not self.beat_file(tmp_path).exists()
        assert '1 problems during the sync, not marking it healthy' in caplog.text

    def test_an_old_beat_is_not_refreshed_by_a_failing_sync(self, tmp_path, clock):
        bot = make_bot(tmp_path)
        bot.reconcile()
        clock.now += 600
        bot.icinga.add(make_service())
        bot.phorge.create_errors = [PhorgeError('down')]
        bot.reconcile()
        assert self.beat_file(tmp_path).read_text() == f'{int(NOW)}\n'

    def test_written_again_once_things_recover(self, tmp_path, clock):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service())
        bot.phorge.create_errors = [PhorgeError('down')]
        bot.reconcile()
        clock.now += 60
        bot.reconcile()
        assert self.beat_file(tmp_path).read_text() == f'{int(NOW) + 60}\n'

    @pytest.mark.usefixtures('clock')
    def test_an_unwritable_path_is_logged_not_raised(self, tmp_path, caplog):
        bot = make_bot(tmp_path, heartbeat_file=str(tmp_path / 'missing' / 'last_sync'))
        with caplog.at_level(logging.ERROR, logger='taskbot'):
            bot.reconcile()
        assert 'Could not write the heartbeat file' in caplog.text

    @pytest.mark.usefixtures('clock')
    def test_a_dry_run_still_beats(self, tmp_path):
        make_bot(tmp_path, dry_run=True).reconcile()
        assert self.beat_file(tmp_path).exists()


class TestSafe:
    def test_errors_are_logged_not_raised(self, tmp_path, caplog):
        bot = make_bot(tmp_path)

        def explode(_value):
            raise PhorgeError(f'boom {_value}')

        with caplog.at_level(logging.ERROR, logger='taskbot'):
            bot.safe(explode, 'now')
        assert 'Failed handling explode' in caplog.text
        assert 'boom now' in caplog.text

    def test_failures_are_counted(self, tmp_path):
        bot = make_bot(tmp_path)

        def explode():
            raise PhorgeError('boom')

        bot.safe(explode)
        bot.safe(explode)
        assert bot.failures == 2

    def test_passes_arguments_through(self, tmp_path):
        seen = []
        make_bot(tmp_path).safe(lambda first, second: seen.append((first, second)), 1, 2)
        assert seen == [(1, 2)]

    def test_keyboard_interrupt_is_not_swallowed(self, tmp_path):
        def interrupt():
            raise KeyboardInterrupt

        with pytest.raises(KeyboardInterrupt):
            make_bot(tmp_path).safe(interrupt)


class TestOnEvent:
    def test_state_change_is_processed(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service())
        bot.on_event(state_change())
        assert len(bot.phorge.created()) == 1

    def test_other_event_types_are_ignored(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service())
        bot.on_event(dict(state_change(), type='CheckResult'))
        assert bot.phorge.calls == []

    def test_host_events_are_ignored(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.on_event({'type': 'StateChange', 'host': 'mw1', 'state': 1})
        assert bot.phorge.calls == []

    def test_unknown_services_are_ignored(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.on_event(state_change(name='deleted'))
        assert bot.phorge.calls == []

    def test_uses_the_current_service_state_not_the_event(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service(state=0))
        bot.on_event(state_change(state=2))
        assert bot.phorge.calls == []


class TestReconcile:
    def test_opens_tasks_for_current_problems(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service(name='a'))
        bot.icinga.add(make_service(name='b', mode=None))
        bot.icinga.add(make_service(name='c', state=0))
        bot.reconcile()
        assert [task['title'] for task in bot.phorge.created()] == ['Disk on mw1 is CRITICAL']
        assert bot.state.get('mw1!a')['active'] is True

    def test_asks_icinga_once_per_sync(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.reconcile()
        assert bot.icinga.syncs == 1

    def test_running_twice_does_not_duplicate(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service())
        bot.reconcile()
        bot.reconcile()
        assert len(bot.phorge.created()) == 1

    def test_a_problem_that_outlasts_the_grace_period_gets_its_task_on_a_later_sync(self, tmp_path, clock):
        bot = make_bot(tmp_path, grace_minutes=15)
        bot.icinga.add(make_service(last_state_ok=NOW - 5 * 60))
        bot.reconcile()
        assert bot.phorge.created() == []
        clock.now += 11 * 60
        bot.reconcile()
        assert len(bot.phorge.created()) == 1

    def test_picks_up_recoveries_missed_while_down(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service())
        bot.reconcile()
        bot.icinga.add(make_service(state=0))
        bot.reconcile()
        assert comments(bot.phorge) == ['Recovered, the service is back to **OK**.']
        assert bot.state.get('mw1!mw1 Disk')['active'] is False

    def test_picks_up_a_changed_state_missed_while_down(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service(mode='any', state=1))
        bot.reconcile()
        bot.icinga.add(make_service(mode='any', state=2))
        bot.reconcile()
        assert comments(bot.phorge)[0].startswith('Now **CRITICAL**.')

    def test_services_that_vanished_are_marked_gone(self, tmp_path, caplog):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service())
        bot.reconcile()
        bot.icinga.services.clear()
        with caplog.at_level(logging.WARNING, logger='taskbot'):
            bot.reconcile()
        assert 'mw1!mw1 Disk no longer exists in Icinga' in caplog.text
        assert bot.state.get('mw1!mw1 Disk') == {'task': 1, 'active': False, 'state': 'GONE', 'alert': 'CRITICAL'}

    def test_inactive_entries_are_left_alone(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.state.put('mw1!old', {'task': 4, 'active': False, 'state': 'OK'})
        bot.reconcile()
        assert bot.icinga.syncs == 1
        assert bot.phorge.calls == []

    def test_one_failure_does_not_stop_the_rest(self, tmp_path, caplog):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service(name='a'))
        bot.icinga.add(make_service(name='b'))
        bot.phorge.create_errors = [PhorgeError('Phorge is down')]
        with caplog.at_level(logging.ERROR, logger='taskbot'):
            bot.reconcile()
        assert bot.state.get('mw1!a') is None
        assert bot.state.get('mw1!b')['active'] is True
        assert 'Phorge is down' in caplog.text

    def test_a_failed_task_is_retried_on_the_next_sync(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service())
        bot.phorge.create_errors = [PhorgeError('down')]
        bot.reconcile()
        assert bot.state.services == {}
        bot.reconcile()
        assert bot.state.get('mw1!mw1 Disk')['task'] == 1

    def test_a_failure_count_does_not_carry_over(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service())
        bot.phorge.create_errors = [PhorgeError('down')]
        bot.reconcile()
        assert bot.failures == 1
        bot.reconcile()
        assert bot.failures == 0

    def test_icinga_errors_propagate(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.icinga.query_errors.append(OSError('Icinga is down'))
        with pytest.raises(OSError, match='Icinga is down'):
            bot.reconcile()

    def test_records_when_it_last_ran(self, tmp_path, monkeypatch):
        Clock([123.0]).install(monkeypatch)
        bot = make_bot(tmp_path)
        bot.reconcile()
        assert bot.last_reconcile == 123.0


class TestRun:
    def test_backoff_and_reset(self, tmp_path, clock):
        bot = make_bot(tmp_path)
        bot.icinga.streams = [OSError('down'), [], ConnectionError('closed'), Stop()]
        with pytest.raises(Stop):
            bot.run()
        assert clock.sleeps == [5, 5, 5]

    def test_delay_grows_and_is_capped(self, tmp_path, clock):
        bot = make_bot(tmp_path)
        bot.icinga.streams = [*([OSError()] * 6), Stop()]
        with pytest.raises(Stop):
            bot.run()
        assert clock.sleeps == [5, 10, 20, 40, 40, 40]

    def test_an_event_resets_the_delay(self, tmp_path, monkeypatch):
        clock = Clock(range(10)).install(monkeypatch)
        bot = make_bot(tmp_path)
        bot.icinga.streams = [OSError(), OSError(), then(OSError('dropped'), state_change()), Stop()]
        with pytest.raises(Stop):
            bot.run()
        assert clock.sleeps == [5, 10, 5]

    def test_clean_endings_do_not_back_off(self, tmp_path, clock):
        bot = make_bot(tmp_path)
        bot.icinga.streams = [OSError(), OSError(), [], [], [], Stop()]
        with pytest.raises(Stop):
            bot.run()
        assert clock.sleeps == [5, 10, 5, 5, 5]

    def test_reconcile_errors_back_off(self, tmp_path, clock):
        bot = make_bot(tmp_path)
        bot.icinga.query_errors = [OSError('down'), TimeoutError('slow')]
        bot.icinga.streams = [[], Stop()]
        with pytest.raises(Stop):
            bot.run()
        assert clock.sleeps == [5, 10, 5]

    def test_bad_data_from_icinga_is_a_connection_problem(self, tmp_path, clock, caplog):
        bot = make_bot(tmp_path)
        bot.icinga.streams = [ValueError('garbage'), Stop()]
        with caplog.at_level(logging.ERROR, logger='taskbot'), pytest.raises(Stop):
            bot.run()
        assert 'Icinga connection problem: garbage' in caplog.text
        assert clock.sleeps == [5]

    @pytest.mark.usefixtures('clock')
    def test_syncs_with_icinga_on_every_connect(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.icinga.streams = [[], [], Stop()]
        with pytest.raises(Stop):
            bot.run()
        assert bot.icinga.syncs == 3

    def test_events_are_handled_as_they_arrive(self, tmp_path, monkeypatch):
        Clock(range(10)).install(monkeypatch)
        bot = make_bot(tmp_path)

        def arrives():
            bot.icinga.add(make_service())
            yield state_change()
            yield state_change(name='missing')
            raise Stop

        bot.icinga.streams = [arrives()]
        with pytest.raises(Stop):
            bot.run()
        assert bot.icinga.syncs == 1
        assert len(bot.phorge.created()) == 1

    def test_a_failing_event_does_not_end_the_stream(self, tmp_path, monkeypatch):
        Clock(range(10)).install(monkeypatch)
        bot = make_bot(tmp_path)
        bot.phorge.create_errors = [PhorgeError('down')]

        def arrives():
            bot.icinga.add(make_service(name='a'))
            bot.icinga.add(make_service(name='b'))
            yield state_change(name='a')
            yield state_change(name='b')
            raise Stop

        bot.icinga.streams = [arrives()]
        with pytest.raises(Stop):
            bot.run()
        assert bot.state.get('mw1!a') is None
        assert bot.state.get('mw1!b')['active'] is True

    def test_reconciles_again_when_the_interval_passes(self, tmp_path, monkeypatch):
        Clock([0.0, 1000.0, 1001.0, 1002.0]).install(monkeypatch)
        bot = make_bot(tmp_path)
        bot.icinga.streams = [then(Stop(), state_change(), state_change())]
        with pytest.raises(Stop):
            bot.run()
        assert bot.icinga.syncs == 2

    def test_does_not_reconcile_early(self, tmp_path, monkeypatch):
        Clock([0.0, 10.0, 20.0]).install(monkeypatch)
        bot = make_bot(tmp_path)
        bot.icinga.streams = [then(Stop(), state_change(), state_change())]
        with pytest.raises(Stop):
            bot.run()
        assert bot.icinga.syncs == 1

    @pytest.mark.usefixtures('clock')
    def test_keeps_going_when_phorge_is_down(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service())
        bot.phorge.create_errors = [PhorgeError('down')]
        bot.icinga.streams = [[], [], Stop()]
        with pytest.raises(Stop):
            bot.run()
        assert bot.state.get('mw1!mw1 Disk')['active'] is True
        assert len(bot.phorge.created()) == 1

    @pytest.mark.usefixtures('clock')
    def test_existing_tasks_are_adopted_before_the_first_sync(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.phorge.add_task()
        bot.icinga.add(make_service())
        bot.icinga.streams = [Stop()]
        with pytest.raises(Stop):
            bot.run()
        assert bot.phorge.created() == []
        assert bot.state.get('mw1!mw1 Disk')['task'] == 1

    @pytest.mark.usefixtures('clock')
    def test_adoption_happens_once_per_run(self, tmp_path, monkeypatch):
        bot = make_bot(tmp_path)
        calls = []
        real = bot.adopt
        monkeypatch.setattr(bot, 'adopt', lambda: calls.append(1) or real())
        bot.icinga.streams = [[], [], [], Stop()]
        with pytest.raises(Stop):
            bot.run()
        assert calls == [1]

    def test_a_phorge_outage_at_startup_holds_back_the_first_sync(self, tmp_path, clock, caplog):
        bot = make_bot(tmp_path)
        bot.phorge.read_errors = [PhorgeError('down')]
        bot.icinga.add(make_service())
        bot.icinga.streams = [Stop()]
        with caplog.at_level(logging.ERROR, logger='taskbot'), pytest.raises(Stop):
            bot.run()
        assert 'Phorge connection problem: down' in caplog.text
        assert clock.sleeps == [5]
        assert bot.icinga.syncs == 1
        assert len(bot.phorge.created()) == 1

    def test_no_task_is_created_until_adoption_has_worked(self, tmp_path, clock):
        bot = make_bot(tmp_path)
        bot.phorge.add_task()
        bot.phorge.read_errors = [PhorgeError('down'), PhorgeError('still down')]
        bot.icinga.add(make_service())
        bot.icinga.streams = [Stop()]
        with pytest.raises(Stop):
            bot.run()
        assert clock.sleeps == [5, 10]
        assert bot.phorge.created() == []
        assert bot.icinga.syncs == 1


class TestDescribeSeconds:
    @pytest.mark.parametrize(('seconds', 'text'), [
        (1, '1 second'),
        (30, '30 seconds'),
        (59, '59 seconds'),
        (60, '1 minute'),
        (90, '90 seconds'),
        (600, '10 minutes'),
        (3600, '1 hour'),
        (5400, '90 minutes'),
        (7200, '2 hours'),
        (0.5, '0.5 seconds'),
        (45.0, '45 seconds'),
    ])
    def test_units(self, seconds, text):
        assert describe_seconds(seconds) == text


class TestDelayedClose:
    NOTICE = ' This task will be closed automatically in 10 minutes unless someone comments on it.'

    @staticmethod
    def recovered(tmp_path, delay=600, **config):
        bot = make_bot(tmp_path, close_after_recovery_seconds=delay, **config)
        bot.process(make_service())
        bot.process(make_service(state=0))
        return bot

    @pytest.mark.usefixtures('clock')
    def test_the_recovery_comment_announces_the_delay(self, tmp_path):
        bot = self.recovered(tmp_path)
        assert comments(bot.phorge) == ['Recovered, the service is back to **OK**.' + self.NOTICE]

    @pytest.mark.usefixtures('clock')
    def test_the_delay_is_shown_in_sensible_units(self, tmp_path):
        bot = self.recovered(tmp_path, delay=7200)
        assert 'closed automatically in 2 hours unless' in comments(bot.phorge)[0]

    @pytest.mark.usefixtures('clock')
    def test_nothing_is_closed_straight_away(self, tmp_path):
        bot = self.recovered(tmp_path)
        assert bot.phorge.tasks[1]['status'] == 'open'
        assert bot.state.get('mw1!mw1 Disk') == {'task': 1, 'active': False, 'state': 'OK', 'alert': 'CRITICAL', 'recovered': NOW}

    def test_nothing_happens_before_the_delay_is_over(self, tmp_path, clock):
        bot = self.recovered(tmp_path)
        before = len(bot.phorge.calls)
        clock.now += 599
        bot.close_due()
        assert len(bot.phorge.calls) == before

    def test_the_task_is_closed_once_the_delay_is_over(self, tmp_path, clock):
        bot = self.recovered(tmp_path)
        clock.now += 600
        bot.close_due()
        assert bot.phorge.tasks[1]['status'] == 'resolved'
        assert comments(bot.phorge)[-1] == 'Closing automatically, the service has been back to **OK** for 10 minutes and nobody commented.'
        assert bot.state.get('mw1!mw1 Disk') == {'task': 1, 'active': False, 'state': 'OK', 'alert': 'CRITICAL', 'closed': clock.now}

    def test_the_close_status_is_used(self, tmp_path, clock):
        bot = self.recovered(tmp_path, close_status='wontfix')
        clock.now += 600
        bot.close_due()
        assert bot.phorge.tasks[1]['status'] == 'wontfix'

    def test_a_sync_does_the_closing(self, tmp_path, clock):
        bot = self.recovered(tmp_path)
        bot.icinga.add(make_service(state=0))
        clock.now += 600
        bot.reconcile()
        assert bot.phorge.tasks[1]['status'] == 'resolved'

    def test_a_task_is_only_closed_once(self, tmp_path, clock):
        bot = self.recovered(tmp_path)
        clock.now += 600
        bot.close_due()
        calls = len(bot.phorge.calls)
        clock.now += 600
        bot.close_due()
        assert len(bot.phorge.calls) == calls

    def test_a_comment_from_a_person_keeps_the_task_open(self, tmp_path, clock):
        bot = self.recovered(tmp_path)
        bot.phorge.human_comments.add(1)
        clock.now += 600
        bot.close_due()
        assert bot.phorge.tasks[1]['status'] == 'open'
        assert comments(bot.phorge)[-1] == 'The service has recovered, but someone commented on this task, so it stays open for a person to decide.'
        assert 'recovered' not in bot.state.get('mw1!mw1 Disk')
        assert 'closed' not in bot.state.get('mw1!mw1 Disk')

    def test_the_note_about_a_human_comment_is_posted_once(self, tmp_path, clock):
        bot = self.recovered(tmp_path)
        bot.phorge.human_comments.add(1)
        clock.now += 600
        bot.close_due()
        clock.now += 600
        bot.close_due()
        assert len(comments(bot.phorge)) == 2

    def test_a_task_someone_closed_meanwhile_is_left_alone(self, tmp_path, clock):
        bot = self.recovered(tmp_path)
        bot.phorge.close(1, 'wontfix')
        calls = len(bot.phorge.calls)
        clock.now += 600
        bot.close_due()
        assert len(bot.phorge.calls) == calls
        assert bot.phorge.tasks[1]['status'] == 'wontfix'
        assert bot.state.get('mw1!mw1 Disk') == {'task': 1, 'active': False, 'state': 'OK', 'alert': 'CRITICAL'}

    def test_alerting_again_cancels_the_close(self, tmp_path, clock):
        bot = self.recovered(tmp_path)
        clock.now += 300
        bot.process(make_service())
        assert 'recovered' not in bot.state.get('mw1!mw1 Disk')
        clock.now += 1000
        bot.close_due()
        assert bot.phorge.tasks[1]['status'] == 'open'

    def test_recovering_again_restarts_the_delay(self, tmp_path, clock):
        bot = self.recovered(tmp_path)
        clock.now += 300
        bot.process(make_service())
        clock.now += 100
        bot.process(make_service(state=0))
        clock.now += 599
        bot.close_due()
        assert bot.phorge.tasks[1]['status'] == 'open'
        clock.now += 1
        bot.close_due()
        assert bot.phorge.tasks[1]['status'] == 'resolved'

    def test_a_restart_keeps_the_pending_close(self, tmp_path, clock):
        first = self.recovered(tmp_path)
        second = make_bot(tmp_path, close_after_recovery_seconds=600)
        second.phorge = first.phorge
        clock.now += 600
        second.close_due()
        assert second.phorge.tasks[1]['status'] == 'resolved'

    def test_a_failure_is_retried_on_the_next_sync(self, tmp_path, clock):
        bot = self.recovered(tmp_path)
        clock.now += 600
        bot.phorge.read_errors = [PhorgeError('down')]
        bot.reconcile()
        assert bot.failures == 1
        assert bot.phorge.tasks[1]['status'] == 'open'
        assert not (tmp_path / 'last_sync').exists()
        bot.reconcile()
        assert bot.phorge.tasks[1]['status'] == 'resolved'

    def test_a_task_closed_this_way_can_be_reopened(self, tmp_path, clock):
        bot = self.recovered(tmp_path)
        clock.now += 600
        bot.close_due()
        clock.now += 3600
        bot.process(make_service())
        assert len(bot.phorge.created()) == 1
        assert bot.phorge.tasks[1]['status'] == 'open'

    def test_never_closing_is_possible(self, tmp_path, clock):
        bot = self.recovered(tmp_path, delay=None)
        assert comments(bot.phorge) == ['Recovered, the service is back to **OK**.']
        clock.now += 10**6
        bot.close_due()
        assert bot.phorge.tasks[1]['status'] == 'open'
        assert 'recovered' not in bot.state.get('mw1!mw1 Disk')

    @pytest.mark.usefixtures('clock')
    def test_a_zero_delay_closes_at_once_without_a_notice(self, tmp_path):
        bot = self.recovered(tmp_path, delay=0)
        assert comments(bot.phorge) == ['Recovered, the service is back to **OK**.']
        assert bot.phorge.tasks[1]['status'] == 'resolved'

    @pytest.mark.usefixtures('clock')
    def test_dropping_to_a_non_alert_state_schedules_nothing(self, tmp_path):
        bot = make_bot(tmp_path, close_after_recovery_seconds=600)
        bot.process(make_service())
        bot.process(make_service(state=1))
        assert 'closed automatically' not in comments(bot.phorge)[0]
        assert 'recovered' not in bot.state.get('mw1!mw1 Disk')

    def test_the_storm_summary_waits_too(self, tmp_path, clock):
        bot = make_bot(tmp_path, storm_limit=1, close_after_recovery_seconds=600)
        TestStorm.many(bot, 3)
        bot.process(make_service(name='svc2', state=0))
        assert comments(bot.phorge)[-1] == '`mw1!svc2` recovered.'
        bot.process(make_service(name='svc3', state=0))
        assert comments(bot.phorge)[-1] == '`mw1!svc3` recovered.' + self.NOTICE
        assert bot.state.storm_recovered == NOW
        assert bot.phorge.tasks[2]['status'] == 'open'
        clock.now += 600
        bot.close_due()
        assert bot.phorge.tasks[2]['status'] == 'resolved'
        assert bot.state.storm is None
        assert comments(bot.phorge)[-1].startswith('Closing automatically')

    def test_the_storm_summary_stays_open_if_a_member_alerts_again(self, tmp_path, clock):
        bot = make_bot(tmp_path, storm_limit=1, close_after_recovery_seconds=600)
        TestStorm.many(bot, 2)
        bot.process(make_service(name='svc2', state=0))
        clock.now += 60
        bot.process(make_service(name='svc2'))
        clock.now += 600
        bot.close_due()
        assert bot.phorge.tasks[2]['status'] == 'open'

    def test_the_storm_summary_with_a_human_comment_stays_open(self, tmp_path, clock):
        bot = make_bot(tmp_path, storm_limit=1, close_after_recovery_seconds=600)
        TestStorm.many(bot, 2)
        bot.process(make_service(name='svc2', state=0))
        bot.phorge.human_comments.add(2)
        clock.now += 600
        bot.close_due()
        assert bot.phorge.tasks[2]['status'] == 'open'
        assert 'stays open for a person to decide' in comments(bot.phorge)[-1]
        assert bot.state.storm is None

    def test_a_restart_keeps_the_pending_storm_close(self, tmp_path, clock):
        first = make_bot(tmp_path, storm_limit=1, close_after_recovery_seconds=600)
        TestStorm.many(first, 2)
        first.process(make_service(name='svc2', state=0))
        second = make_bot(tmp_path, storm_limit=1, close_after_recovery_seconds=600)
        second.phorge = first.phorge
        clock.now += 600
        second.close_due()
        assert second.phorge.tasks[2]['status'] == 'resolved'


class PhorgeApp:
    def __init__(self):
        self.tasks = {}
        self.edits = []

    def __call__(self, request):
        method = request['path'].rsplit('/', 1)[1]
        fields = form(request)
        if method == 'user.whoami':
            return phorge_reply({'phid': 'PHID-USER-bot'})
        if method == 'maniphest.search':
            return phorge_reply({'data': self.search(fields), 'cursor': {'after': None}})
        if method == 'maniphest.edit':
            return phorge_reply({'object': {'id': self.edit(fields)}})
        if method == 'transaction.search':
            task = self.tasks[int(fields['objectIdentifier'][0].lstrip('T'))]
            mine = [{'type': 'comment', 'authorPHID': 'PHID-USER-bot', 'comments': [{'removed': False}]} for _ in task['comments']]
            theirs = [{'type': 'comment', 'authorPHID': 'PHID-USER-alice', 'comments': [{'removed': False}]} for _ in range(task.get('humans', 0))]
            return phorge_reply({'data': mine + theirs, 'cursor': {'after': None}})
        return phorge_reply({})

    def search(self, fields):
        wanted = fields.get('constraints[ids][0]')
        everything = fields['queryKey'] == ['all']
        return [
            {
                'id': task['id'],
                'fields': {
                    'name': task['title'],
                    'description': {'raw': task['description']},
                    'status': {'value': task['status']},
                    'priority': {'value': task['priority']},
                },
            }
            for task in self.tasks.values()
            if (everything or task['status'] == 'open') and (not wanted or task['id'] == int(wanted[0]))
        ]

    def edit(self, fields):
        self.edits.append(fields)
        if 'objectIdentifier' in fields:
            task = self.tasks[int(fields['objectIdentifier'][0])]
        else:
            task = {'id': len(self.tasks) + 1, 'title': '', 'description': '', 'status': 'open', 'priority': 50, 'comments': []}
            self.tasks[task['id']] = task
        index = 0
        while f'transactions[{index}][type]' in fields:
            kind = fields[f'transactions[{index}][type]'][0]
            value = fields.get(f'transactions[{index}][value]', [''])[0]
            if kind == 'comment':
                task['comments'].append(value)
            elif kind == 'priority':
                task['priority'] = taskbot.PRIORITIES[value]
            elif kind in ('title', 'description', 'status'):
                task[kind] = value
            index += 1
        return task['id']


class TestEndToEnd:
    @staticmethod
    def icinga_app(services):
        def app(request):
            body = json.loads(request['body'])
            found = []
            for attrs in services.values():
                plain = {key: value for key, value in attrs.items() if key != 'host'}
                if not icinga_filter_matches(body, plain):
                    continue
                found.append({'attrs': plain, 'joins': {'host': attrs['host']}})
            return 200, json.dumps({'results': found}).encode()

        return app

    @staticmethod
    def make(tmp_path, phorge_server, icinga_server, **changes):
        config = make_config(tmp_path, **changes)
        config['phorge'].update(url=phorge_server.url, retries=1)
        config['icinga'].update(url=icinga_server.url)
        return Bot(config)

    def test_the_life_of_an_alert_through_real_http(self, serve, tmp_path, clock):
        app = PhorgeApp()
        phorge_server = serve(reply=app)
        services = {'mw1!mw1 Disk': make_service()}
        icinga_server = serve(reply=self.icinga_app(services))
        bot = self.make(tmp_path, phorge_server, icinga_server, close_after_recovery_seconds=0)
        bot.prepare()
        bot.reconcile()
        task = app.tasks[1]
        assert (task['title'], task['priority']) == ('Disk on mw1 is CRITICAL', taskbot.PRIORITIES['high'])
        assert task_key(as_task(task['description'])) == 'mw1!mw1 Disk'
        services['mw1!mw1 Disk'] = make_service(state=0)
        bot.on_event(state_change(state=0))
        assert task['status'] == 'resolved'
        assert task['comments'] == ['Recovered, the service is back to **OK**.']
        clock.now += 600
        services['mw1!mw1 Disk'] = make_service()
        bot.on_event(state_change())
        assert len(app.tasks) == 1
        assert task['status'] == 'open'
        assert task['comments'][-1].startswith('Alerting again, **CRITICAL**.')
        assert all(form(request)['api.token'] == ['api-token'] for request in phorge_server.received)

    def test_recovered_tasks_close_after_the_delay_unless_a_person_commented(self, serve, tmp_path, clock):
        app = PhorgeApp()
        phorge_server = serve(reply=app)
        services = {
            'mw1!mw1 Disk': make_service(),
            'mw2!mw2 Disk': make_service(host='mw2', name='mw2 Disk'),
        }
        icinga_server = serve(reply=self.icinga_app(services))
        bot = self.make(tmp_path, phorge_server, icinga_server, close_after_recovery_seconds=600)
        bot.prepare()
        bot.reconcile()
        assert len(app.tasks) == 2
        for attrs in services.values():
            attrs['state'] = 0.0
        bot.reconcile()
        assert all(task['status'] == 'open' for task in app.tasks.values())
        assert 'closed automatically in 10 minutes' in app.tasks[1]['comments'][-1]
        app.tasks[2]['humans'] = 1
        clock.now += 600
        bot.reconcile()
        assert app.tasks[1]['status'] == 'resolved'
        assert app.tasks[2]['status'] == 'open'
        assert 'stays open for a person to decide' in app.tasks[2]['comments'][-1]

    @pytest.mark.usefixtures('clock')
    def test_events_find_the_service_through_real_http(self, serve, tmp_path):
        app = PhorgeApp()
        phorge_server = serve(reply=app)
        services = {'mw1!mw1 Disk': make_service()}
        icinga_server = serve(reply=self.icinga_app(services))
        bot = self.make(tmp_path, phorge_server, icinga_server)
        bot.prepare()
        bot.on_event(state_change())
        assert len(app.tasks) == 1

    @pytest.mark.usefixtures('clock')
    def test_a_lost_state_file_is_rebuilt_through_real_http(self, serve, tmp_path):
        app = PhorgeApp()
        phorge_server = serve(reply=app)
        services = {'mw1!mw1 Disk': make_service()}
        icinga_server = serve(reply=self.icinga_app(services))
        first = self.make(tmp_path, phorge_server, icinga_server, close_after_recovery_seconds=0)
        first.prepare()
        first.reconcile()
        edits = len(app.edits)
        fresh = self.make(tmp_path, phorge_server, icinga_server, close_after_recovery_seconds=0, state_file=str(tmp_path / 'fresh.json'))
        fresh.prepare()
        fresh.reconcile()
        assert len(app.tasks) == 1
        assert len(app.edits) == edits
        services['mw1!mw1 Disk'] = make_service(state=0)
        fresh.reconcile()
        assert app.tasks[1]['status'] == 'resolved'

    @pytest.mark.usefixtures('clock')
    def test_a_down_host_creates_nothing_through_real_http(self, serve, tmp_path):
        app = PhorgeApp()
        phorge_server = serve(reply=app)
        services = {'mw1!mw1 Disk': make_service(details={'state': 1.0, 'downtime_depth': 0.0})}
        icinga_server = serve(reply=self.icinga_app(services))
        bot = self.make(tmp_path, phorge_server, icinga_server)
        bot.prepare()
        bot.reconcile()
        assert app.tasks == {}
        services['mw1!mw1 Disk'] = make_service()
        bot.reconcile()
        assert len(app.tasks) == 1

    def test_the_grace_period_holds_back_a_task_through_real_http(self, serve, tmp_path, clock):
        app = PhorgeApp()
        phorge_server = serve(reply=app)
        services = {'mw1!mw1 Disk': make_service(last_state_ok=NOW - 300)}
        icinga_server = serve(reply=self.icinga_app(services))
        bot = self.make(tmp_path, phorge_server, icinga_server, grace_minutes=15)
        bot.prepare()
        bot.reconcile()
        assert app.tasks == {}
        clock.now += 11 * 60
        bot.reconcile()
        assert len(app.tasks) == 1


class TestMain:
    @staticmethod
    def write(tmp_path, config):
        path = tmp_path / 'config.json'
        path.write_text(json.dumps(config))
        return path

    @staticmethod
    def patch(monkeypatch, argv):
        logging_calls = []
        ran = []

        class FakeBot:
            def __init__(self, config):
                ran.append(config)

            def run(self):
                ran.append('run')

        monkeypatch.setattr(sys, 'argv', ['taskbot.py', *argv])
        monkeypatch.setattr(taskbot.logging, 'basicConfig', lambda **kwargs: logging_calls.append(kwargs))
        monkeypatch.setattr(taskbot, 'Bot', FakeBot)
        return logging_calls, ran

    def test_short_config_flag(self, tmp_path, monkeypatch):
        path = self.write(tmp_path, dict(BASE_CONFIG, log_level='warning'))
        logging_calls, ran = self.patch(monkeypatch, ['-c', str(path)])
        taskbot.main()
        assert ran[0]['log_level'] == 'warning'
        assert ran[1] == 'run'
        assert logging_calls[0]['level'] == logging.WARNING

    def test_long_config_flag(self, tmp_path, monkeypatch):
        path = self.write(tmp_path, BASE_CONFIG)
        _, ran = self.patch(monkeypatch, ['--config', str(path)])
        taskbot.main()
        assert ran[1] == 'run'

    def test_config_defaults_to_config_json_in_the_current_directory(self, tmp_path, monkeypatch):
        self.write(tmp_path, BASE_CONFIG)
        monkeypatch.chdir(tmp_path)
        _, ran = self.patch(monkeypatch, [])
        taskbot.main()
        assert ran[0]['icinga']['queue'] == 'taskbot'

    def test_no_default_config_means_exit(self, tmp_path, monkeypatch):
        monkeypatch.chdir(tmp_path)
        _, ran = self.patch(monkeypatch, [])
        with pytest.raises(SystemExit, match='Cannot load config.json'):
            taskbot.main()
        assert ran == []

    def test_verbose_forces_debug(self, tmp_path, monkeypatch):
        path = self.write(tmp_path, dict(BASE_CONFIG, log_level='ERROR'))
        logging_calls, _ = self.patch(monkeypatch, ['-c', str(path), '-v'])
        taskbot.main()
        assert logging_calls[0]['level'] == logging.DEBUG

    def test_long_verbose_flag(self, tmp_path, monkeypatch):
        path = self.write(tmp_path, BASE_CONFIG)
        logging_calls, _ = self.patch(monkeypatch, ['-c', str(path), '--verbose'])
        taskbot.main()
        assert logging_calls[0]['level'] == logging.DEBUG

    @pytest.mark.parametrize(('level', 'expected'), [
        ('debug', logging.DEBUG),
        ('INFO', logging.INFO),
        ('Warning', logging.WARNING),
        ('bogus', logging.INFO),
    ])
    def test_log_level_from_config(self, tmp_path, monkeypatch, level, expected):
        path = self.write(tmp_path, dict(BASE_CONFIG, log_level=level))
        logging_calls, _ = self.patch(monkeypatch, ['-c', str(path)])
        taskbot.main()
        assert logging_calls[0]['level'] == expected

    def test_log_format_uses_braces(self, tmp_path, monkeypatch):
        path = self.write(tmp_path, BASE_CONFIG)
        logging_calls, _ = self.patch(monkeypatch, ['-c', str(path)])
        taskbot.main()
        assert logging_calls[0]['style'] == '{'
        assert logging_calls[0]['format'] == '{asctime} {levelname} {message}'

    @pytest.mark.parametrize('dry_run', [True, False])
    def test_dry_run_is_read_from_the_config(self, tmp_path, monkeypatch, dry_run):
        path = self.write(tmp_path, dict(BASE_CONFIG, dry_run=dry_run))
        _, ran = self.patch(monkeypatch, ['-c', str(path)])
        taskbot.main()
        assert ran[0]['dry_run'] is dry_run

    def test_there_is_no_dry_run_flag(self, tmp_path, monkeypatch):
        path = self.write(tmp_path, BASE_CONFIG)
        _, ran = self.patch(monkeypatch, ['-c', str(path), '--dry-run'])
        with pytest.raises(SystemExit, match='2'):
            taskbot.main()
        assert ran == []

    def test_incomplete_config_never_starts_the_bot(self, tmp_path, monkeypatch):
        config = copy.deepcopy(BASE_CONFIG)
        del config['phorge']['api_token']
        path = self.write(tmp_path, config)
        _, ran = self.patch(monkeypatch, ['-c', str(path)])
        with pytest.raises(SystemExit, match='Missing in config: phorge.api_token'):
            taskbot.main()
        assert ran == []

    def test_ctrl_c_exits_quietly(self, tmp_path, monkeypatch):
        path = self.write(tmp_path, BASE_CONFIG)
        self.patch(monkeypatch, ['-c', str(path)])

        class Interrupted:
            def __init__(self, config):
                self.config = config

            def run(self):
                raise KeyboardInterrupt

        monkeypatch.setattr(taskbot, 'Bot', Interrupted)
        with contextlib.suppress(SystemExit):
            taskbot.main()


class TestVerboseLogging:
    def test_skips_are_explained(self, tmp_path, caplog):
        bot = make_bot(tmp_path)
        with caplog.at_level(logging.DEBUG, logger='taskbot'):
            bot.process(make_service(mode=None))
            bot.process(make_service(state_type=0.0))
            bot.process(make_service(downtime_depth=1.0))
            bot.process(make_service(details={'state': 0.0, 'downtime_depth': 1.0}))
            bot.process(make_service(details={'state': 1.0, 'downtime_depth': 0.0}))
            bot.process(make_service(flapping=True))
        assert 'does not set phorge_task, skipping' in caplog.text
        assert 'is in a soft state, skipping' in caplog.text
        assert 'is CRITICAL but in downtime, skipping' in caplog.text
        assert 'is CRITICAL but its host is in downtime, skipping' in caplog.text
        assert 'is CRITICAL but its host is down, skipping' in caplog.text
        assert 'is flapping, skipping' in caplog.text

    def test_events_are_logged(self, tmp_path, caplog):
        bot = make_bot(tmp_path)
        with caplog.at_level(logging.DEBUG, logger='taskbot'):
            bot.on_event(state_change())
        assert 'Event for mw1!mw1 Disk' in caplog.text

    def test_quiet_by_default(self, tmp_path, caplog):
        bot = make_bot(tmp_path)
        with caplog.at_level(logging.INFO, logger='taskbot'):
            bot.process(make_service(mode=None))
            bot.reconcile()
        assert caplog.text == ''

    @pytest.mark.usefixtures('clock')
    def test_a_healthy_idle_bot_logs_nothing_at_info(self, tmp_path, caplog):
        bot = make_bot(tmp_path)
        bot.icinga.streams = [[], [], Stop()]
        with caplog.at_level(logging.INFO, logger='taskbot'), pytest.raises(Stop):
            bot.run()
        assert caplog.text == ''

    @pytest.mark.usefixtures('clock')
    def test_the_token_is_never_logged(self, serve, caplog):
        server = serve(reply=Script((500, b'down')))
        phorge = Phorge(dict(BASE_CONFIG['phorge'], url=server.url, retries=2))
        with caplog.at_level(logging.DEBUG, logger='taskbot'), pytest.raises(PhorgeError, match='request failed'):
            phorge.call('conduit.ping')
        assert 'Calling conduit.ping, attempt 1 of 2' in caplog.text
        assert 'api-token' not in caplog.text


def render_template(**values):
    text = re.sub(r'\A<%-.*?-%>\n', '', TEMPLATE.read_text(), flags=re.DOTALL)
    return json.loads(re.sub(r'<%= stdlib::to_json\(\$(\w+)\) %>', lambda match: json.dumps(values[match.group(1)]), text))


def rendered(**changes):
    values = {
        'icinga_url': 'https://mon181.example.org:5665',
        'icinga_password': 'icinga-secret',
        'phorge_token': 'api-token',
        'http_proxy': None,
    }
    values.update(changes)
    return render_template(**values)


def unit_setting(name):
    match = re.search(f'^{name}=(.*)$', SYSTEMD.read_text(), re.MULTILINE)
    assert match, f'{name} is not set in the unit'
    return match.group(1)


class TestShippedCa:
    def test_the_bot_can_load_it(self):
        assert ssl.create_default_context(cafile=str(CA_FILE)).get_ca_certs() != []

    def test_is_the_icinga_ca(self):
        der = ssl.PEM_cert_to_DER_cert(CA_FILE.read_text())
        assert hashlib.sha256(der).hexdigest() == ICINGA_CA_SHA256, 'update ICINGA_CA_SHA256 if the CA was replaced on purpose'
        subjects = [certificate['subject'] for certificate in ssl.create_default_context(cafile=str(CA_FILE)).get_ca_certs()]
        assert subjects == [((('commonName', 'Icinga CA'),),)]

    def test_is_a_single_certificate_and_no_key(self):
        text = CA_FILE.read_text()
        assert text.count('-----BEGIN CERTIFICATE-----') == 1
        assert 'PRIVATE KEY' not in text


class TestConfigTemplate:
    def test_has_every_key_the_bot_requires(self):
        assert missing_keys(rendered()) == []

    def test_has_no_key_the_bot_does_not_know(self):
        config = rendered()
        assert set(config) <= set(taskbot.REQUIRED)
        for section, keys in taskbot.REQUIRED.items():
            if keys:
                assert set(config[section]) <= set(keys), section

    def test_passes_the_values_it_is_given(self):
        config = rendered(icinga_url='https://icinga.example.org:5665', http_proxy='http://bastion.example.org:8080')
        assert config['icinga']['url'] == 'https://icinga.example.org:5665'
        assert config['icinga']['password'] == 'icinga-secret'
        assert config['phorge']['api_token'] == 'api-token'
        assert config['phorge']['proxy'] == 'http://bastion.example.org:8080'

    def test_no_proxy_is_null(self):
        assert rendered()['phorge']['proxy'] is None

    def test_awkward_secrets_survive(self):
        config = rendered(icinga_password='a"b\\c', phorge_token='x\ny')
        assert config['icinga']['password'] == 'a"b\\c'
        assert config['phorge']['api_token'] == 'x\ny'

    def test_triggers_only_use_known_states(self):
        config = rendered()
        states = set(taskbot.STATES.values())
        assert all(set(levels) <= states for levels in config['triggers'].values())
        assert set(config['triggers']) == {'critical', 'any'}

    def test_every_triggering_state_has_a_priority(self):
        config = rendered()
        triggering = {state for levels in config['triggers'].values() for state in levels}
        assert triggering <= set(config['priorities'])

    def test_reconnect_delays_make_sense(self):
        config = rendered()
        assert 0 < config['reconnect_min'] <= config['reconnect_max']

    def test_the_sync_runs_often_enough_for_the_grace_period_to_be_precise(self):
        config = rendered()
        assert config['reconcile_interval'] <= 120
        assert config['icinga']['stream_timeout'] <= 120

    def test_a_grace_period_is_set(self):
        assert rendered()['grace_minutes'] > 0

    def test_reopening_only_makes_sense_when_the_bot_closes_tasks(self):
        config = rendered()
        assert config['reopen_hours'] > 0
        assert config['close_after_recovery_seconds'] is not None

    def test_the_storm_settings_are_usable(self):
        config = rendered()
        assert config['storm_limit'] >= 1
        assert config['storm_window_minutes'] > 0

    def test_the_bot_accepts_it_as_a_config_file(self, tmp_path):
        path = tmp_path / 'config.json'
        path.write_text(json.dumps(rendered()))
        assert load_config(str(path))['icinga']['username'] == 'taskbot'


class TestDeployment:

    def test_the_config_points_at_the_deployed_ca(self):
        assert f"file {{ '{rendered()['icinga']['ca_file']}':" in MANIFEST.read_text()

    def test_the_service_runs_the_deployed_script_and_config(self):
        manifest = MANIFEST.read_text()
        command = unit_setting('ExecStart')
        match = re.fullmatch(r'/usr/bin/python3 (\S+) -c (\S+)', command)
        assert match, command
        for path in match.groups():
            assert f"file {{ '{path}':" in manifest

    def test_the_state_file_lives_in_the_state_directory(self):
        state_file = rendered()['state_file']
        assert state_file == f"/var/lib/{unit_setting('StateDirectory')}/state.json"

    def test_the_service_user_can_read_the_config(self):
        manifest = MANIFEST.read_text()
        config_block = manifest[manifest.index("'/etc/taskbot/config.json'"):]
        assert f"group   => '{unit_setting('User')}'" in config_block.split('}', 1)[0]
        assert "mode    => '0640'" in config_block.split('}', 1)[0]

    def test_the_process_check_matches_the_running_script(self):
        manifest = MANIFEST.read_text()
        script = re.search(r'taskbot\.py', unit_setting('ExecStart'))
        assert script
        assert '-a taskbot.py' in manifest

    def test_the_heartbeat_file_lives_in_the_state_directory(self):
        heartbeat = rendered()['heartbeat_file']
        assert heartbeat == f"/var/lib/{unit_setting('StateDirectory')}/last_sync"

    def test_the_sync_check_watches_the_heartbeat_file(self):
        manifest = MANIFEST.read_text()
        heartbeat = rendered()['heartbeat_file']
        assert re.search(rf"check_file_age -w \d+ -c \d+ -f {re.escape(heartbeat)}'", manifest)

    def test_the_sync_check_does_not_warn_between_normal_syncs(self):
        config = rendered()
        match = re.search(r'check_file_age -w (\d+) -c (\d+)', MANIFEST.read_text())
        warning, critical = int(match.group(1)), int(match.group(2))
        healthy_cycle = config['icinga']['stream_timeout'] + config['reconnect_min']
        assert warning > 2 * healthy_cycle
        assert critical > warning

    def test_the_api_user_may_read_hosts_for_the_host_down_check(self):
        text = (MONITORING / 'init.pp').read_text()
        permissions = re.search(r"apiuser \{ 'taskbot':.*?permissions => \[(.*?)\]", text, re.DOTALL).group(1)
        assert "'objects/query/Host'" in permissions
        assert "'objects/query/Service'" in permissions
        assert "'events/StateChange'" in permissions
