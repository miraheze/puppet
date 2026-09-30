import contextlib
import copy
import hashlib
import http.server
import json
import logging
import re
import ssl
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
    State,
    build_opener,
    check_output,
    flatten,
    load_config,
    missing_keys,
)

MODULE = Path(__file__).resolve().parents[2]
CA_FILE = Path(__file__).resolve().parent / 'icinga-ca.crt'
TEMPLATE = MODULE / 'templates' / 'taskbot' / 'config.json.epp'
SYSTEMD = MODULE / 'templates' / 'initscripts' / 'taskbot.systemd.epp'
MANIFEST = MODULE / 'manifests' / 'taskbot.pp'

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
    'priorities': {'WARNING': 'normal', 'CRITICAL': 'high', 'UNKNOWN': 'normal'},
    'icingaweb_url': 'https://icinga.example.org',
    'skip_in_downtime': True,
    'close_on_recovery': False,
    'close_status': 'resolved',
    'reconcile_interval': 900,
    'reconnect_min': 5,
    'reconnect_max': 40,
    'state_file': '/nonexistent/state.json',
    'dry_run': False,
    'log_level': 'INFO',
}


def make_config(tmp_path, **changes):
    config = copy.deepcopy(BASE_CONFIG)
    config['state_file'] = str(tmp_path / 'state.json')
    config.update(changes)
    return config


def make_bot(tmp_path, **changes):
    bot = Bot(make_config(tmp_path, **changes))
    bot.phorge = FakePhorge()
    bot.icinga = FakeIcinga()
    return bot


def make_service(host='mw1', name='mw1 Disk', state=2, mode='critical', **changes):
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
    }
    attrs.update(changes)
    return attrs


def state_change(host='mw1', name='mw1 Disk', state=2):
    return {'type': 'StateChange', 'host': host, 'service': name, 'state': state, 'state_type': 1}


def comments(phorge):
    return [call[2][0]['value'] for call in phorge.calls if call[0] == 'edit']


class Stop(BaseException):
    pass


def then(outcome, *events):
    yield from events
    raise outcome


class FakePhorge:
    def __init__(self):
        self.calls = []
        self.open_tasks = set()
        self.next_id = 1

    def create(self, title, description, priority, slugs):
        task = self.next_id
        self.next_id += 1
        self.open_tasks.add(task)
        self.calls.append((
            'create',
            {'title': title, 'description': description, 'priority': priority, 'slugs': slugs},
        ))
        return task

    def edit(self, transactions, task=None):
        self.calls.append(('edit', task, transactions))
        return {'object': {'id': task}}

    def is_open(self, task):
        return task in self.open_tasks

    def created(self):
        return [call[1] for call in self.calls if call[0] == 'create']


class FakeIcinga:
    def __init__(self):
        self.services = {}
        self.streams = []
        self.queries = []
        self.query_errors = []

    def add(self, attrs):
        self.services[(attrs['host_name'], attrs['name'])] = attrs

    def query(self, body):
        self.queries.append(body)
        if self.query_errors:
            raise self.query_errors.pop(0)
        return [
            {'attrs': attrs} for attrs in self.services.values()
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
    def __init__(self, ticks=None):
        self.sleeps = []
        self.ticks = None if ticks is None else iter(ticks)

    def monotonic(self):
        return 0.0 if self.ticks is None else next(self.ticks)

    def install(self, monkeypatch):
        monkeypatch.setattr(taskbot, 'time', types.SimpleNamespace(
            sleep=self.sleeps.append,
            monotonic=self.monotonic,
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

    def start(handler=ApiHandler, reply=None, lines=(), hold=False):
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
        server.daemon_threads = True
        server.received = []
        server.log_lines = []
        server.reply = reply or phorge_reply({})
        server.lines = lines
        server.hold = hold
        server.release = threading.Event()
        server.url = f'http://127.0.0.1:{server.server_port}'
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


def form(request):
    return urllib.parse.parse_qs(request['body'])


class TestMissingKeys:
    def test_complete_config(self):
        assert missing_keys(BASE_CONFIG) == []

    @pytest.mark.parametrize('key', ['icingaweb_url', 'dry_run', 'log_level', 'state_file', 'reconnect_max'])
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
        assert State(str(tmp_path / 'state.json')).data == {}

    def test_put_and_get(self, tmp_path):
        state = State(str(tmp_path / 'state.json'))
        assert state.get('mw1!Disk') is None
        state.put('mw1!Disk', {'task': 7, 'active': True, 'state': 'CRITICAL'})
        assert state.get('mw1!Disk') == {'task': 7, 'active': True, 'state': 'CRITICAL'}

    def test_survives_a_restart(self, tmp_path):
        path = str(tmp_path / 'state.json')
        State(path).put('mw1!Disk', {'task': 7, 'active': True, 'state': 'CRITICAL'})
        assert State(path).get('mw1!Disk')['task'] == 7

    def test_write_is_atomic(self, tmp_path):
        path = tmp_path / 'state.json'
        State(str(path)).put('a', {'task': 1})
        assert not (tmp_path / 'state.json.tmp').exists()
        assert json.loads(path.read_text()) == {'a': {'task': 1}}

    def test_nothing_is_written_when_not_persisting(self, tmp_path):
        path = tmp_path / 'state.json'
        state = State(str(path), persist=False)
        state.put('a', {'task': 1})
        assert state.get('a') == {'task': 1}
        assert not path.exists()

    def test_corrupt_file_is_an_error(self, tmp_path):
        path = tmp_path / 'state.json'
        path.write_text('{oops')
        with pytest.raises(ValueError, match='Expecting'):
            State(str(path))


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
        assert self.make(server).create('Disk is full', 'Details', 'high', ['infra']) == 42
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
        assert self.make(server).create('Title', 'Body', priority, []) == 9
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
        self.make(server).create('Title', 'Body', None, ['nope'])
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
            assert phorge.create('Title', 'Body', 'high', []) == 0
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


class TestIcinga:
    @staticmethod
    def make(server, **changes):
        return Icinga(dict(BASE_CONFIG['icinga'], url=server.url, **changes))

    def test_basic_auth_header(self, serve):
        server = serve(reply=(200, b'{"results": []}'))
        self.make(server, username='taskbot', password='p:w').query({})
        assert server.received[0]['headers']['Authorization'] == 'Basic dGFza2JvdDpwOnc='

    def test_query_uses_the_get_override(self, serve):
        reply = {'results': [{'attrs': {'name': 'Disk'}}]}
        server = serve(reply=(200, json.dumps(reply).encode()))
        body = {'filter': 'service.state != 0', 'attrs': ['name']}
        assert self.make(server).query(body) == reply['results']
        request = server.received[0]
        assert request['path'] == '/v1/objects/services'
        assert request['headers']['X-HTTP-Method-Override'] == 'GET'
        assert request['headers']['Content-Type'] == 'application/json'
        assert request['headers']['Accept'] == 'application/json'
        assert json.loads(request['body']) == body

    def test_service_found(self, serve):
        reply = {'results': [{'attrs': make_service()}]}
        server = serve(reply=(200, json.dumps(reply).encode()))
        assert self.make(server).service('mw1', 'mw1 Disk')['host_name'] == 'mw1'
        body = json.loads(server.received[0]['body'])
        assert body['filter'] == 'service.host_name == host && service.name == name'
        assert body['filter_vars'] == {'host': 'mw1', 'name': 'mw1 Disk'}
        assert body['attrs'] == taskbot.ATTRS

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
        assert task['priority'] == 'normal'
        assert 'DISK CRITICAL - free space' in task['description']

    def test_priority_follows_the_state(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(name='a', mode='any', state=1))
        bot.process(make_service(name='b', mode='any', state=2))
        assert [task['priority'] for task in bot.phorge.created()] == ['normal', 'high']

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

    def test_downtime_is_skipped(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(downtime_depth=1.0))
        assert bot.phorge.calls == []

    def test_downtime_can_be_allowed(self, tmp_path):
        bot = make_bot(tmp_path, skip_in_downtime=False)
        bot.process(make_service(downtime_depth=1.0))
        assert len(bot.phorge.created()) == 1

    def test_downtime_does_not_block_recovery(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service())
        bot.process(make_service(state=0, downtime_depth=1.0))
        assert comments(bot.phorge) == ['Recovered, the service is back to **OK**.']

    def test_state_is_recorded(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service())
        assert bot.state.get('mw1!mw1 Disk') == {'task': 1, 'active': True, 'state': 'CRITICAL'}


class TestProblemAndClear:
    def test_repeated_alerts_do_not_duplicate(self, tmp_path):
        bot = make_bot(tmp_path)
        for _ in range(3):
            bot.process(make_service())
        assert len(bot.phorge.created()) == 1
        assert comments(bot.phorge) == []

    def test_escalation_is_commented(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(mode='any', state=1))
        bot.process(make_service(mode='any', state=2))
        assert len(bot.phorge.created()) == 1
        assert comments(bot.phorge) == ['Now **CRITICAL**.\n\n```\nDISK CRITICAL - free space: / 1 GB\n```']
        assert bot.phorge.calls[-1][1] == 1
        assert bot.state.get('mw1!mw1 Disk')['state'] == 'CRITICAL'

    def test_recovery_is_commented_not_closed(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service())
        bot.process(make_service(state=0))
        assert comments(bot.phorge) == ['Recovered, the service is back to **OK**.']
        assert [t['type'] for t in bot.phorge.calls[-1][2]] == ['comment']
        assert bot.state.get('mw1!mw1 Disk') == {'task': 1, 'active': False, 'state': 'OK'}

    def test_recovery_can_close_the_task(self, tmp_path):
        bot = make_bot(tmp_path, close_on_recovery=True, close_status='wontfix')
        bot.process(make_service())
        bot.process(make_service(state=0))
        assert bot.phorge.calls[-1][2][1] == {'type': 'status', 'value': 'wontfix'}

    def test_only_recovery_closes(self, tmp_path):
        bot = make_bot(tmp_path, close_on_recovery=True)
        bot.process(make_service(mode='critical', state=2))
        bot.process(make_service(mode='critical', state=1))
        assert [t['type'] for t in bot.phorge.calls[-1][2]] == ['comment']

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

    def test_a_closed_task_gets_a_new_one(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service())
        bot.process(make_service(state=0))
        bot.phorge.open_tasks.clear()
        bot.process(make_service())
        assert len(bot.phorge.created()) == 2
        assert bot.state.get('mw1!mw1 Disk')['task'] == 2

    def test_a_closed_task_is_replaced_even_while_active(self, tmp_path):
        bot = make_bot(tmp_path, triggers={'critical': ['CRITICAL'], 'any': ['WARNING', 'CRITICAL']})
        bot.process(make_service(mode='any', state=1))
        bot.phorge.open_tasks.clear()
        bot.process(make_service(mode='any', state=2))
        assert len(bot.phorge.created()) == 2

    def test_recovery_without_a_task_does_nothing(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.process(make_service(state=0))
        assert bot.phorge.calls == []
        assert bot.state.data == {}

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
        second.phorge.open_tasks.add(1)
        second.process(make_service())
        assert second.phorge.calls == []

    def test_restart_keeps_recovery_working(self, tmp_path):
        first = make_bot(tmp_path)
        first.process(make_service())
        second = make_bot(tmp_path)
        second.process(make_service(state=0))
        assert comments(second.phorge) == ['Recovered, the service is back to **OK**.']
        assert second.phorge.calls[-1][1] == 1

    def test_dry_run_keeps_state_in_memory_only(self, tmp_path):
        bot = make_bot(tmp_path, dry_run=True)
        bot.process(make_service())
        assert bot.state.get('mw1!mw1 Disk')['active'] is True
        assert not (tmp_path / 'state.json').exists()


class TestSafe:
    def test_errors_are_logged_not_raised(self, tmp_path, caplog):
        bot = make_bot(tmp_path)

        def explode(_value):
            raise PhorgeError(f'boom {_value}')

        with caplog.at_level(logging.ERROR, logger='taskbot'):
            bot.safe(explode, 'now')
        assert 'Failed handling explode' in caplog.text
        assert 'boom now' in caplog.text

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

    def test_query_only_asks_for_hard_problems(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.reconcile()
        assert bot.icinga.queries == [{'filter': 'service.state != 0 && service.state_type == 1', 'attrs': taskbot.ATTRS}]

    def test_running_twice_does_not_duplicate(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service())
        bot.reconcile()
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
        assert bot.state.get('mw1!mw1 Disk') == {'task': 1, 'active': False, 'state': 'GONE'}

    def test_inactive_entries_are_left_alone(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.state.put('mw1!old', {'task': 4, 'active': False, 'state': 'OK'})
        bot.reconcile()
        assert bot.icinga.queries != []
        assert bot.phorge.calls == []

    def test_one_failure_does_not_stop_the_rest(self, tmp_path, caplog):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service(name='a'))
        bot.icinga.add(make_service(name='b'))
        real = bot.phorge.create
        attempts = []

        def flaky(*args):
            attempts.append(args)
            if len(attempts) == 1:
                raise PhorgeError('Phorge is down')
            return real(*args)

        bot.phorge.create = flaky
        with caplog.at_level(logging.ERROR, logger='taskbot'):
            bot.reconcile()
        assert len(attempts) == 2
        assert bot.state.get('mw1!a') is None
        assert bot.state.get('mw1!b')['active'] is True

    def test_a_failed_task_is_retried_on_the_next_sync(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service())
        real = bot.phorge.create
        outcomes = [PhorgeError('down')]

        def flaky(*args):
            if outcomes:
                raise outcomes.pop(0)
            return real(*args)

        bot.phorge.create = flaky
        bot.reconcile()
        assert bot.state.data == {}
        bot.reconcile()
        assert bot.state.get('mw1!mw1 Disk')['task'] == 1

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
        assert len(bot.icinga.queries) == 3

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
        assert bot.icinga.queries[0] == bot.icinga.queries[-1]
        assert len(bot.icinga.queries) == 1
        assert len(bot.phorge.created()) == 1

    def test_a_failing_event_does_not_end_the_stream(self, tmp_path, monkeypatch):
        Clock(range(10)).install(monkeypatch)
        bot = make_bot(tmp_path)
        real = bot.phorge.create
        outcomes = [PhorgeError('down')]

        def flaky(*args):
            if outcomes:
                raise outcomes.pop(0)
            return real(*args)

        def arrives():
            bot.icinga.add(make_service(name='a'))
            bot.icinga.add(make_service(name='b'))
            yield state_change(name='a')
            yield state_change(name='b')
            raise Stop

        bot.phorge.create = flaky
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
        assert len(bot.icinga.queries) == 2

    def test_does_not_reconcile_early(self, tmp_path, monkeypatch):
        Clock([0.0, 10.0, 20.0]).install(monkeypatch)
        bot = make_bot(tmp_path)
        bot.icinga.streams = [then(Stop(), state_change(), state_change())]
        with pytest.raises(Stop):
            bot.run()
        assert len(bot.icinga.queries) == 1

    @pytest.mark.usefixtures('clock')
    def test_keeps_going_when_phorge_is_down(self, tmp_path):
        bot = make_bot(tmp_path)
        bot.icinga.add(make_service())
        real = bot.phorge.create
        outcomes = [PhorgeError('down')]

        def flaky(*args):
            if outcomes:
                raise outcomes.pop(0)
            return real(*args)

        bot.phorge.create = flaky
        bot.icinga.streams = [[], [], Stop()]
        with pytest.raises(Stop):
            bot.run()
        assert bot.state.get('mw1!mw1 Disk')['active'] is True
        assert len(bot.phorge.created()) == 1


class TestEndToEnd:
    def test_problem_and_recovery_through_real_http(self, serve, tmp_path):
        tasks = {}

        def phorge(request):
            fields = form(request)
            if request['path'].endswith('maniphest.search'):
                task = int(fields['constraints[ids][0]'][0])
                return phorge_reply({'data': [{'id': task}] if tasks.get(task) else []})
            if request['path'].endswith('maniphest.edit'):
                if 'objectIdentifier' in fields:
                    task = int(fields['objectIdentifier'][0])
                else:
                    task = len(tasks) + 1
                    tasks[task] = True
                return phorge_reply({'object': {'id': task}})
            return phorge_reply({})

        phorge_server = serve(reply=phorge)
        services = {'mw1!mw1 Disk': make_service()}

        def icinga(request):
            wanted = json.loads(request['body']).get('filter_vars')
            found = [
                {'attrs': attrs} for attrs in services.values()
                if wanted is None or (attrs['host_name'], attrs['name']) == (wanted['host'], wanted['name'])
            ]
            return 200, json.dumps({'results': found}).encode()

        icinga_server = serve(reply=icinga)
        config = make_config(tmp_path)
        config['phorge'].update(url=phorge_server.url, retries=1)
        config['icinga'].update(url=icinga_server.url)
        bot = Bot(config)
        bot.reconcile()
        services['mw1!mw1 Disk'] = make_service(state=0)
        bot.on_event(state_change(state=0))
        edits = [r for r in phorge_server.received if r['path'].endswith('maniphest.edit')]
        assert len(edits) == 2
        created = form(edits[0])
        assert created['transactions[0][value]'] == ['Disk on mw1 is CRITICAL']
        assert created['transactions[2][value]'] == ['high']
        recovered = form(edits[1])
        assert recovered['objectIdentifier'] == ['1']
        assert recovered['transactions[0][value]'] == ['Recovered, the service is back to **OK**.']
        assert all(form(r)['api.token'] == ['api-token'] for r in phorge_server.received)
        assert json.loads((tmp_path / 'state.json').read_text()) == {
            'mw1!mw1 Disk': {'task': 1, 'active': False, 'state': 'OK'},
        }


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
        assert 'does not set phorge_task, skipping' in caplog.text
        assert 'is in a soft state, skipping' in caplog.text
        assert 'is CRITICAL but in downtime, skipping' in caplog.text

    def test_events_are_logged(self, tmp_path, caplog):
        bot = make_bot(tmp_path)
        with caplog.at_level(logging.DEBUG, logger='taskbot'):
            bot.on_event(state_change())
        assert 'Event for mw1!mw1 Disk' in caplog.text

    def test_quiet_by_default(self, tmp_path, caplog):
        bot = make_bot(tmp_path)
        with caplog.at_level(logging.INFO, logger='taskbot'):
            bot.process(make_service(mode=None))
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

    def test_the_bot_accepts_it_as_a_config_file(self, tmp_path):
        path = tmp_path / 'config.json'
        path.write_text(json.dumps(rendered()))
        assert load_config(str(path))['icinga']['username'] == 'taskbot'


class TestDeployment:
    def test_the_manifest_ships_the_ca_from_the_module(self):
        manifest = MANIFEST.read_text()
        assert "source  => 'puppet:///modules/bots/taskbot/icinga-ca.crt'" in manifest
        assert 'icinga2_ca_cert' not in manifest

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
