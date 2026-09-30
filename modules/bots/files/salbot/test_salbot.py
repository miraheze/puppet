import asyncio
import base64
import contextlib
import copy
import hashlib
import http.client
import http.server
import importlib.util
import json
import re
import socket
import sys
import threading
import types
import urllib.parse
from pathlib import Path
from unittest.mock import MagicMock

import pytest

import salbot
from salbot import (
    LOGGED_REPLY,
    Bot,
    Phorge,
    PhorgeError,
    Proxy,
    ProxiedHTTPConnection,
    ProxiedHTTPSConnection,
    extract_entry,
    fingerprint,
    http_connect,
    load_config,
    open_socket,
    parse_irc,
    socks5_connect,
)

SAL_URL = 'https://meta.miraheze.org/wiki/Tech:Server_admin_log'
CHANNEL = '#miraheze-tech-ops'
LSBOT = 'MirahezeLSBot!~MirahezeL@miraheze/bots'
LOGBOT = 'MirahezeLogbot!~MirahezeL@miraheze/bots'
STRANGER = 'someone!~x@203.0.113.9'
ADMINLOG = Path(__file__).resolve().parents[1] / 'irclogbot' / 'adminlog.py'

BASE_CONFIG = {
    'irc': {
        'server': '127.0.0.1',
        'port': 6697,
        'ssl': False,
        'nick': 'salbot',
        'username': 'salbot',
        'password': 'secret',
        'channels': [CHANNEL],
        'reconnect_min': 5,
        'reconnect_max': 40,
    },
    'phorge': {'url': 'https://phorge.example.org', 'api_token': 'api-token'},
    'allowed_senders': ['*!*@miraheze/bots'],
    'sal_url': SAL_URL,
    'time_format': '%Y-%m-%d %H:%M UTC',
    'logbot_nick': 'MirahezeLogbot',
    'logbot_mask': 'MirahezeLogbot!~MirahezeL@miraheze/bots',
    'link_wait': 60,
    'min_post_interval': 0,
    'dedupe_seconds': 60,
}

NAV = re.compile(
    r'^\{nav icon=file, name=Mentioned in SAL \((?P<channel>[^)]+)\), href=(?P<href>[^}]+)\} '
    r'\[(?P<time>[^\]]+)\] <(?P<actor>[^>]+)> (?P<message>.*)$'
)


def make_bot(irc=None, **changes):
    config = copy.deepcopy(BASE_CONFIG)
    config['irc'].update(irc or {})
    config.update(changes)
    return Bot(config)


def drain(bot):
    items = []
    while not bot.queue.empty():
        items.append(bot.queue.get_nowait())
    return items


def cancel_timers(bot):
    for waiting in bot.pending.values():
        for pending in waiting:
            pending.timer.cancel()


def logged(line, url=SAL_URL, suffix=''):
    return f'Logged the message at {url}#sal-20260930010101-{fingerprint(line)}{suffix}'


def parse_comment(body):
    match = NAV.match(body)
    assert match, body
    return match.groupdict()


class FakeSocket:
    def __init__(self, reply=b''):
        self.reply = bytearray(reply)
        self.sent = b''
        self.closed = False

    def sendall(self, data):
        self.sent += data

    def recv(self, count):
        chunk, self.reply = self.reply[:count], self.reply[count:]
        return bytes(chunk)

    def close(self):
        self.closed = True


class FakeResponse:
    def __init__(self, status, body):
        self.status = status
        self.body = body

    def read(self):
        return self.body


class FakeConnection:
    def __init__(self, status=200, body=b'{"result": {}, "error_code": null}', error=None):
        self.status = status
        self.body = body
        self.error = error
        self.requests = []
        self.closed = False

    def request(self, method, path, body, headers):
        if self.error:
            raise self.error
        self.requests.append((method, path, body, headers))

    def getresponse(self):
        return FakeResponse(self.status, self.body)

    def close(self):
        self.closed = True


SOCKS_OK = b'\x05\x00\x00\x01' + b'\x00' * 6


class TestParseIrc:
    def test_prefix_and_trailing(self):
        line = ':nick!user@host PRIVMSG #chan :hello there world'
        assert parse_irc(line) == ('nick!user@host', 'PRIVMSG', ['#chan', 'hello there world'])

    def test_no_prefix(self):
        assert parse_irc('PING :token') == (None, 'PING', ['token'])

    def test_no_trailing(self):
        assert parse_irc(':srv 903 nick') == ('srv', '903', ['nick'])

    def test_command_is_uppercased(self):
        assert parse_irc('ping :x')[1] == 'PING'

    def test_empty_line(self):
        assert parse_irc('') == (None, '', [])

    def test_trailing_keeps_colons(self):
        assert parse_irc(':a PRIVMSG #c :!log x: y :z')[2] == ['#c', '!log x: y :z']


class TestExtractEntry:
    def test_actor_message_and_task(self):
        line = '!log [universalomega@mwtask181] /usr/local/bin/mwscript foo.php metawiki (T123)'
        assert extract_entry(line) == (
            'universalomega@mwtask181',
            '/usr/local/bin/mwscript foo.php metawiki',
            ['T123'],
        )

    def test_no_actor(self):
        assert extract_entry('!log restarted nginx (T5)') == (None, 'restarted nginx', ['T5'])

    def test_case_insensitive_command(self):
        assert extract_entry('!LOG [a@b] thing (T5)') == ('a@b', 'thing', ['T5'])

    def test_task_must_be_the_suffix(self):
        assert extract_entry('!log [a@b] fixing T99 for now') is None
        assert extract_entry('!log [a@b] thing (T5) trailing') is None

    def test_no_task(self):
        assert extract_entry('!log [a@b] thing') is None

    def test_not_a_log_line(self):
        assert extract_entry('hello (T5)') is None
        assert extract_entry('') is None

    def test_task_only_message_is_dropped(self):
        assert extract_entry('!log [a@b] (T5)') is None

    def test_start_and_end_lines_keep_their_markers(self):
        line = '!log [a@b] cmd (END - exit=0; time=3s) (T7)'
        assert extract_entry(line) == ('a@b', 'cmd (END - exit=0; time=3s)', ['T7'])

    def test_any_mode_finds_every_task_once(self):
        line = '!log [a@b] moving T1 then T2 then T1 again'
        assert extract_entry(line, 'any') == ('a@b', 'moving T1 then T2 then T1 again', ['T1', 'T2'])

    def test_any_mode_without_task(self):
        assert extract_entry('!log [a@b] nothing here', 'any') is None

    def test_task_id_needs_digits(self):
        assert extract_entry('!log [a@b] thing (Tabc)') is None


class TestFingerprint:
    def test_uses_text_after_the_command(self):
        line = '!log [a@b] thing (T1)'
        assert fingerprint(line) == hashlib.sha1(b'[a@b] thing (T1)').hexdigest()[:8]

    def test_differs_between_messages(self):
        assert fingerprint('!log one') != fingerprint('!log two')

    def test_survives_undecodable_text(self):
        assert re.fullmatch(r'[0-9a-f]{8}', fingerprint('!log \udcff broken'))


class TestLoggedReply:
    def test_matches_plain_and_collision_urls(self):
        base = 'Logged the message at https://meta.miraheze.org/wiki/Tech:Server_admin_log#sal-20260930010101-0a1b2c3d'
        assert LOGGED_REPLY.match(base).group('fp') == '0a1b2c3d'
        assert LOGGED_REPLY.match(f'{base}-2').group('fp') == '0a1b2c3d'

    @pytest.mark.parametrize('text', [
        'Logged the message at http://meta.miraheze.org/wiki/X#sal-20260930010101-0a1b2c3d',
        'Logged the message at https://meta.miraheze.org/wiki/X#sal-20260930010101',
        'Logged the message at https://meta.miraheze.org/wiki/X#sal-20260930010101-ABCDEF12',
        'Logged the message at https://meta.miraheze.org/wiki/X#2026-09-30',
        'Message missing. Nothing logged.',
    ])
    def test_rejects(self, text):
        assert LOGGED_REPLY.match(text) is None


class TestProxy:
    def test_socks5_with_credentials(self):
        proxy = Proxy('socks5://bast:p%40ss@10.0.0.1:9050')
        assert (proxy.kind, proxy.host, proxy.port) == ('socks5', '10.0.0.1', 9050)
        assert (proxy.username, proxy.password) == ('bast', 'p@ss')

    def test_socks5h_is_socks5(self):
        assert Proxy('socks5h://proxy.example:1080').kind == 'socks5'

    def test_http_defaults(self):
        proxy = Proxy('http://bastion.fsslc.wtnet')
        assert (proxy.kind, proxy.port, proxy.username) == ('http', 8080, None)

    def test_socks_default_port(self):
        assert Proxy('socks5://proxy.example').port == 1080

    def test_username_without_password(self):
        proxy = Proxy('http://bast@proxy.example:8080')
        assert (proxy.username, proxy.password) == ('bast', '')

    def test_str_hides_credentials(self):
        assert str(Proxy('http://bast:pw@proxy.example:8080')) == 'http://proxy.example:8080'

    @pytest.mark.parametrize('url', ['ftp://proxy.example:21', 'proxy.example:8080', 'https://proxy.example:443'])
    def test_rejects_scheme(self, url):
        with pytest.raises(ValueError, match='Unsupported proxy scheme'):
            Proxy(url)

    def test_rejects_missing_host(self):
        with pytest.raises(ValueError, match='no host'):
            Proxy('http://:8080')


class TestSocks5Connect:
    @staticmethod
    def request(host, port):
        name = host.encode()
        return b'\x05\x01\x00\x03' + bytes([len(name)]) + name + port.to_bytes(2, 'big')

    def test_domain_without_auth(self):
        sock = FakeSocket(b'\x05\x00' + SOCKS_OK)
        socks5_connect(sock, Proxy('socks5://proxy:1080'), 'irc.libera.chat', 6697)
        assert sock.sent == b'\x05\x01\x00' + self.request('irc.libera.chat', 6697)

    def test_username_password_auth(self):
        sock = FakeSocket(b'\x05\x02' + b'\x01\x00' + SOCKS_OK)
        socks5_connect(sock, Proxy('socks5://bast:pw@proxy:1080'), 'irc.libera.chat', 6697)
        assert sock.sent == (
            b'\x05\x02\x00\x02' + b'\x01\x04bast\x02pw' + self.request('irc.libera.chat', 6697)
        )

    def test_credentials_offered_but_proxy_wants_none(self):
        sock = FakeSocket(b'\x05\x00' + SOCKS_OK)
        socks5_connect(sock, Proxy('socks5://bast:pw@proxy:1080'), 'irc.libera.chat', 6697)
        assert sock.sent.startswith(b'\x05\x02\x00\x02\x05\x01\x00\x03')

    def test_ipv4_target(self):
        sock = FakeSocket(b'\x05\x00' + SOCKS_OK)
        socks5_connect(sock, Proxy('socks5://proxy:1080'), '192.0.2.10', 443)
        assert sock.sent.endswith(b'\x05\x01\x00\x01' + bytes([192, 0, 2, 10]) + b'\x01\xbb')

    def test_ipv6_target(self):
        sock = FakeSocket(b'\x05\x00' + SOCKS_OK)
        socks5_connect(sock, Proxy('socks5://proxy:1080'), '2001:db8::1', 443)
        assert b'\x05\x01\x00\x04' + socket.inet_pton(socket.AF_INET6, '2001:db8::1') in sock.sent

    def test_reads_ipv6_bind_address_in_reply(self):
        sock = FakeSocket(b'\x05\x00' + b'\x05\x00\x00\x04' + b'\x00' * 18)
        socks5_connect(sock, Proxy('socks5://proxy:1080'), 'irc.libera.chat', 6697)
        assert not sock.reply

    def test_reads_domain_bind_address_in_reply(self):
        sock = FakeSocket(b'\x05\x00' + b'\x05\x00\x00\x03' + b'\x03abc' + b'\x00\x00')
        socks5_connect(sock, Proxy('socks5://proxy:1080'), 'irc.libera.chat', 6697)
        assert not sock.reply

    def test_connect_failure_code(self):
        sock = FakeSocket(b'\x05\x00' + b'\x05\x05\x00\x01' + b'\x00' * 6)
        with pytest.raises(ConnectionError, match='code 5'):
            socks5_connect(sock, Proxy('socks5://proxy:1080'), 'irc.libera.chat', 6697)

    def test_credentials_rejected(self):
        sock = FakeSocket(b'\x05\x02' + b'\x01\x01')
        with pytest.raises(ConnectionError, match='rejected the credentials'):
            socks5_connect(sock, Proxy('socks5://bast:bad@proxy:1080'), 'irc.libera.chat', 6697)

    def test_no_acceptable_method(self):
        sock = FakeSocket(b'\x05\xff')
        with pytest.raises(ConnectionError, match='acceptable auth method'):
            socks5_connect(sock, Proxy('socks5://proxy:1080'), 'irc.libera.chat', 6697)

    def test_not_a_socks5_proxy(self):
        sock = FakeSocket(b'\x04\x00')
        with pytest.raises(ConnectionError, match='SOCKS5'):
            socks5_connect(sock, Proxy('socks5://proxy:1080'), 'irc.libera.chat', 6697)

    def test_unknown_address_type_in_reply(self):
        sock = FakeSocket(b'\x05\x00' + b'\x05\x00\x00\x09')
        with pytest.raises(ConnectionError, match='unknown address type'):
            socks5_connect(sock, Proxy('socks5://proxy:1080'), 'irc.libera.chat', 6697)

    def test_credentials_too_long(self):
        sock = FakeSocket(b'\x05\x02')
        proxy = Proxy(f'socks5://bast:{"x" * 300}@proxy:1080')
        with pytest.raises(ConnectionError, match='too long'):
            socks5_connect(sock, proxy, 'irc.libera.chat', 6697)

    def test_proxy_hangs_up_mid_handshake(self):
        sock = FakeSocket(b'\x05')
        with pytest.raises(ConnectionError, match='closed the connection'):
            socks5_connect(sock, Proxy('socks5://proxy:1080'), 'irc.libera.chat', 6697)


class TestHttpConnect:
    OK = b'HTTP/1.1 200 Connection established\r\nVia: squid\r\n\r\n'

    def test_sends_connect_request(self):
        sock = FakeSocket(self.OK)
        http_connect(sock, Proxy('http://proxy:8080'), 'irc.libera.chat', 6697)
        assert sock.sent == (
            b'CONNECT irc.libera.chat:6697 HTTP/1.1\r\nHost: irc.libera.chat:6697\r\n\r\n'
        )

    def test_reads_only_the_headers(self):
        sock = FakeSocket(self.OK + b'tunnel data')
        http_connect(sock, Proxy('http://proxy:8080'), 'irc.libera.chat', 6697)
        assert bytes(sock.reply) == b'tunnel data'

    def test_basic_auth_header(self):
        sock = FakeSocket(self.OK)
        http_connect(sock, Proxy('http://bast:pw@proxy:8080'), 'irc.libera.chat', 6697)
        token = base64.b64encode(b'bast:pw')
        assert b'Proxy-Authorization: Basic ' + token + b'\r\n' in sock.sent

    def test_ipv6_target_is_bracketed(self):
        sock = FakeSocket(self.OK)
        http_connect(sock, Proxy('http://proxy:8080'), '2001:db8::1', 6697)
        assert sock.sent.startswith(b'CONNECT [2001:db8::1]:6697 HTTP/1.1')

    def test_refused(self):
        sock = FakeSocket(b'HTTP/1.1 403 Forbidden\r\n\r\n')
        with pytest.raises(ConnectionError, match='Proxy refused CONNECT: HTTP/1.1 403 Forbidden'):
            http_connect(sock, Proxy('http://proxy:8080'), 'irc.libera.chat', 6697)

    def test_garbage_status_line(self):
        sock = FakeSocket(b'garbage\r\n\r\n')
        with pytest.raises(ConnectionError, match='Proxy refused CONNECT'):
            http_connect(sock, Proxy('http://proxy:8080'), 'irc.libera.chat', 6697)

    def test_oversized_headers(self):
        sock = FakeSocket(b'x' * 9000)
        with pytest.raises(ConnectionError, match='too large'):
            http_connect(sock, Proxy('http://proxy:8080'), 'irc.libera.chat', 6697)

    def test_truncated_response(self):
        sock = FakeSocket(b'HTTP/1.1 200')
        with pytest.raises(ConnectionError, match='closed the connection'):
            http_connect(sock, Proxy('http://proxy:8080'), 'irc.libera.chat', 6697)


class TestOpenSocket:
    def test_direct(self, monkeypatch):
        calls = []
        monkeypatch.setattr(socket, 'create_connection', lambda *args: calls.append(args) or 'sock')
        assert open_socket('irc.libera.chat', 6697, 30) == 'sock'
        assert calls == [(('irc.libera.chat', 6697), 30)]

    def test_connects_to_the_proxy_not_the_target(self, monkeypatch):
        fake = FakeSocket(b'HTTP/1.1 200 OK\r\n\r\n')
        calls = []
        monkeypatch.setattr(socket, 'create_connection', lambda *args: calls.append(args) or fake)
        assert open_socket('irc.libera.chat', 6697, 30, Proxy('http://proxy:8080')) is fake
        assert calls == [(('proxy', 8080), 30)]

    def test_closes_the_socket_when_the_handshake_fails(self, monkeypatch):
        fake = FakeSocket(b'HTTP/1.1 403 Forbidden\r\n\r\n')
        monkeypatch.setattr(socket, 'create_connection', MagicMock(return_value=fake))
        with pytest.raises(ConnectionError):
            open_socket('irc.libera.chat', 6697, 30, Proxy('http://proxy:8080'))
        assert fake.closed

    def test_uses_socks5_for_socks_proxies(self, monkeypatch):
        fake = FakeSocket(b'\x05\x00' + SOCKS_OK)
        monkeypatch.setattr(socket, 'create_connection', MagicMock(return_value=fake))
        open_socket('irc.libera.chat', 6697, 30, Proxy('socks5://proxy:1080'))
        assert fake.sent.startswith(b'\x05\x01\x00')


class TestProxiedConnections:
    def test_http_connection_opens_through_the_proxy(self, monkeypatch):
        proxy = Proxy('http://proxy:8080')
        calls = []
        monkeypatch.setattr(salbot, 'open_socket', lambda *args: calls.append(args) or 'sock')
        conn = ProxiedHTTPConnection('example.org', 80, timeout=7, proxy=proxy)
        conn.connect()
        assert conn.sock == 'sock'
        assert calls == [('example.org', 80, 7, proxy)]

    def test_https_connection_wraps_the_tunnel(self, monkeypatch):
        monkeypatch.setattr(salbot, 'open_socket', MagicMock(return_value='raw'))
        conn = ProxiedHTTPSConnection('example.org', 443, timeout=7, proxy=Proxy('http://proxy:8080'))
        conn._context = MagicMock()
        conn._context.wrap_socket.return_value = 'wrapped'
        conn.connect()
        conn._context.wrap_socket.assert_called_once_with('raw', server_hostname='example.org')
        assert conn.sock == 'wrapped'


class TestPhorge:
    @staticmethod
    def phorge(monkeypatch, connection, **extra):
        cfg = {'url': 'https://phorge.example.org', 'api_token': 'api-token'}
        cfg.update(extra)
        client = Phorge(cfg)
        monkeypatch.setattr(client, 'connection', lambda: connection)
        return client

    def test_posts_a_comment(self, monkeypatch):
        conn = FakeConnection()
        self.phorge(monkeypatch, conn).comment('T42', 'hello world')
        (method, path, body, headers), = conn.requests
        assert (method, path) == ('POST', '/api/maniphest.edit')
        assert urllib.parse.parse_qs(body) == {
            'api.token': ['api-token'],
            'objectIdentifier': ['T42'],
            'transactions[0][type]': ['comment'],
            'transactions[0][value]': ['hello world'],
        }
        assert headers['Content-Type'] == 'application/x-www-form-urlencoded'
        assert conn.closed

    def test_keeps_a_url_path_prefix(self, monkeypatch):
        conn = FakeConnection()
        self.phorge(monkeypatch, conn, url='https://example.org/phorge/').comment('T1', 'x')
        assert conn.requests[0][1] == '/phorge/api/maniphest.edit'

    def test_api_error_is_not_retried(self, monkeypatch):
        body = json.dumps({'error_code': 'ERR-CONDUIT-CORE', 'error_info': 'No such task'}).encode()
        conn = FakeConnection(body=body)
        with pytest.raises(PhorgeError, match='ERR-CONDUIT-CORE: No such task') as error:
            self.phorge(monkeypatch, conn).comment('T1', 'x')
        assert error.value.retry is False
        assert conn.closed

    @pytest.mark.parametrize(('status', 'retry'), [(500, True), (503, True), (403, False), (404, False)])
    def test_http_errors(self, monkeypatch, status, retry):
        with pytest.raises(PhorgeError, match=f'HTTP {status}') as error:
            self.phorge(monkeypatch, FakeConnection(status=status)).comment('T1', 'x')
        assert error.value.retry is retry

    @pytest.mark.parametrize('error', [OSError('boom'), TimeoutError(), http.client.BadStatusLine('x')])
    def test_network_errors_are_retried(self, monkeypatch, error):
        conn = FakeConnection(error=error)
        with pytest.raises(PhorgeError) as raised:
            self.phorge(monkeypatch, conn).comment('T1', 'x')
        assert raised.value.retry is True
        assert conn.closed

    def test_bad_json_is_retried(self, monkeypatch):
        with pytest.raises(PhorgeError, match='Bad JSON') as error:
            self.phorge(monkeypatch, FakeConnection(body=b'<html>')).comment('T1', 'x')
        assert error.value.retry is True

    def test_token_from_environment_wins(self, monkeypatch):
        monkeypatch.setenv('PHORGE_API_TOKEN', 'from-env')
        assert Phorge({'url': 'https://p.example', 'api_token': 'from-config'}).token == 'from-env'

    def test_token_only_in_environment(self, monkeypatch):
        monkeypatch.setenv('PHORGE_API_TOKEN', 'from-env')
        assert Phorge({'url': 'https://p.example'}).token == 'from-env'

    def test_connection_class_and_port(self):
        secure = Phorge({'url': 'https://p.example', 'api_token': 't'})
        assert isinstance(secure.connection(), ProxiedHTTPSConnection)
        assert secure.port == 443
        plain = Phorge({'url': 'http://p.example:8000', 'api_token': 't'})
        assert isinstance(plain.connection(), ProxiedHTTPConnection)
        assert plain.port == 8000

    def test_connection_gets_the_proxy_and_timeout(self):
        client = Phorge({'url': 'https://p.example', 'api_token': 't', 'proxy': 'http://bastion:8080', 'timeout': 5})
        conn = client.connection()
        assert conn.proxy is client.proxy
        assert conn.timeout == 5


class FakeProxy:
    def __init__(self, kind):
        self.kind = kind
        self.requests = []
        self.credentials = []
        self.listener = socket.socket()
        self.listener.bind(('127.0.0.1', 0))
        self.listener.listen(5)
        self.port = self.listener.getsockname()[1]
        threading.Thread(target=self.serve, daemon=True).start()

    @property
    def url(self):
        scheme = 'http' if self.kind == 'http' else 'socks5'
        return f'{scheme}://bast:pw@127.0.0.1:{self.port}'

    def close(self):
        self.listener.close()

    def serve(self):
        while True:
            try:
                client, _ = self.listener.accept()
            except OSError:
                return
            threading.Thread(target=self.handle, args=(client,), daemon=True).start()

    @staticmethod
    def read(client, count):
        data = b''
        while len(data) < count:
            data += client.recv(count - len(data))
        return data

    def handshake_socks5(self, client):
        count = self.read(client, 2)[1]
        self.read(client, count)
        if self.kind == 'socks5-auth':
            client.sendall(b'\x05\x02')
            user = self.read(client, self.read(client, 2)[1])
            password = self.read(client, self.read(client, 1)[0])
            self.credentials.append((user, password))
            client.sendall(b'\x01\x00')
        else:
            client.sendall(b'\x05\x00')
        header = self.read(client, 4)
        if header[3] == 1:
            host = socket.inet_ntoa(self.read(client, 4))
        else:
            host = self.read(client, self.read(client, 1)[0]).decode()
        port = int.from_bytes(self.read(client, 2), 'big')
        client.sendall(SOCKS_OK)
        return host, port

    def handshake_http(self, client):
        head = b''
        while not head.endswith(b'\r\n\r\n'):
            head += self.read(client, 1)
        token = base64.b64encode(b'bast:pw')
        self.credentials.append(b'Proxy-Authorization: Basic ' + token in head)
        host, _, port = head.split()[1].decode().rpartition(':')
        client.sendall(b'HTTP/1.1 200 Connection established\r\n\r\n')
        return host, int(port)

    def handle(self, client):
        if self.kind == 'http':
            host, port = self.handshake_http(client)
        else:
            host, port = self.handshake_socks5(client)
        self.requests.append((host, port))
        upstream = socket.create_connection(('127.0.0.1', port))
        threading.Thread(target=self.pipe, args=(upstream, client), daemon=True).start()
        self.pipe(client, upstream)

    @staticmethod
    def pipe(source, target):
        try:
            with contextlib.suppress(OSError):
                while True:
                    data = source.recv(4096)
                    if not data:
                        break
                    target.sendall(data)
        finally:
            for sock in (source, target):
                with contextlib.suppress(OSError):
                    sock.shutdown(socket.SHUT_RDWR)


class WebHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers['Content-Length'])
        self.server.received.append((self.path, self.rfile.read(length).decode()))
        body = b'{"result": {}, "error_code": null}'
        self.send_response(200)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        self.server.log_lines.append(args)


@pytest.fixture()
def web():
    server = http.server.HTTPServer(('127.0.0.1', 0), WebHandler)
    server.received = []
    server.log_lines = []
    threading.Thread(target=server.serve_forever, daemon=True).start()
    yield server
    server.shutdown()
    server.server_close()


@pytest.fixture()
def proxy_of():
    proxies = []

    def start(kind):
        proxies.append(FakeProxy(kind))
        return proxies[-1]

    yield start
    for proxy in proxies:
        proxy.close()


@pytest.mark.parametrize('kind', ['socks5', 'socks5-auth', 'http'])
def test_phorge_comment_through_a_real_proxy(web, proxy_of, kind):
    proxy = proxy_of(kind)
    client = Phorge({
        'url': f'http://phorge.internal:{web.server_port}',
        'api_token': 'tok',
        'proxy': proxy.url,
    })
    client.comment('T9', 'through the tunnel')
    assert proxy.requests == [('phorge.internal', web.server_port)]
    assert [path for path, _ in web.received] == ['/api/maniphest.edit']
    assert 'through+the+tunnel' in web.received[0][1]
    if kind == 'socks5-auth':
        assert proxy.credentials == [(b'bast', b'pw')]
    if kind == 'http':
        assert proxy.credentials == [True]


class TestSenders:
    def test_everyone_when_unrestricted(self):
        assert make_bot(allowed_senders=[]).sender_allowed(STRANGER)

    def test_matches_cloak_patterns_case_insensitively(self):
        bot = make_bot()
        assert bot.sender_allowed(LSBOT)
        assert bot.sender_allowed('X!~y@Miraheze/Bots')
        assert not bot.sender_allowed(STRANGER)
        assert not bot.sender_allowed('MirahezeLSBot!~a@miraheze/bots.evil.example')


class TestDedupe:
    def test_second_sighting_is_recent(self):
        bot = make_bot()
        assert bot.seen_recently(('T1', 'a', 'm')) is False
        assert bot.seen_recently(('T1', 'a', 'm')) is True
        assert bot.seen_recently(('T2', 'a', 'm')) is False

    def test_window_expires(self, monkeypatch):
        bot = make_bot(dedupe_seconds=10)
        clock = [100.0]
        monkeypatch.setattr(salbot.time, 'monotonic', lambda: clock[0])
        assert bot.seen_recently('k') is False
        clock[0] = 105.0
        assert bot.seen_recently('k') is True
        clock[0] = 111.0
        assert bot.seen_recently('k') is False


class TestIsLogged:
    @pytest.mark.parametrize('line', ['!log hello', '!LOG hello', '!Log [a@b] x (T1)'])
    def test_logged(self, line):
        assert make_bot().is_logged(line)

    @pytest.mark.parametrize('line', [
        '!log help',
        '!LOG HELP',
        '!log',
        'hello',
        'MirahezeLogbot: hi',
        '!MirahezeLogbot',
        'say !log hello',
    ])
    def test_not_logged(self, line):
        assert not make_bot().is_logged(line)


class TestBuildComment:
    def test_layout(self):
        bot = make_bot()
        when = salbot.datetime(2026, 9, 29, 12, 42, 15, tzinfo=salbot.timezone.utc)
        body = bot.build_comment(CHANNEL, 'universalomega@mw151', 'START - thing', when, f'{SAL_URL}#sal-x')
        assert body == (
            '{nav icon=file, name=Mentioned in SAL (#miraheze-tech-ops), '
            'href=https://meta.miraheze.org/wiki/Tech:Server_admin_log#sal-x} '
            '[2026-09-29 12:42 UTC] <universalomega@mw151> START - thing'
        )

    def test_time_format_is_configurable(self):
        bot = make_bot(time_format='%Y-%m-%dT%H:%M:%SZ')
        when = salbot.datetime(2026, 9, 29, 12, 42, 15, tzinfo=salbot.timezone.utc)
        assert '[2026-09-29T12:42:15Z]' in bot.build_comment(CHANNEL, 'a', 'm', when, 'link')


class TestHandleMessage:
    def test_reply_pairs_entries_out_of_order(self):
        first = '!log [universalomega@mw151] first (T1)'
        second = '!log [someone@mw152] second (T2)'

        async def scenario():
            bot = make_bot()
            bot.handle_message(LSBOT, CHANNEL, first)
            bot.handle_message(LSBOT, CHANNEL, second)
            bot.handle_message(LOGBOT, CHANNEL, logged(second))
            bot.handle_message(LOGBOT, CHANNEL, logged(first))
            return bot, drain(bot)

        bot, items = asyncio.run(scenario())
        assert [task for task, _ in items] == ['T2', 'T1']
        by_task = {task: parse_comment(body) for task, body in items}
        assert by_task['T1']['href'] == f'{SAL_URL}#sal-20260930010101-{fingerprint(first)}'
        assert by_task['T2']['href'] == f'{SAL_URL}#sal-20260930010101-{fingerprint(second)}'
        assert (by_task['T1']['actor'], by_task['T1']['message']) == ('universalomega@mw151', 'first')
        assert by_task['T1']['channel'] == CHANNEL
        assert re.fullmatch(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2} UTC', by_task['T1']['time'])
        assert bot.pending == {}

    def test_collision_suffix_still_pairs(self):
        line = '!log [a@b] same text (T3)'

        async def scenario():
            bot = make_bot()
            bot.handle_message(LSBOT, CHANNEL, line)
            bot.handle_message(LOGBOT, CHANNEL, logged(line, suffix='-2'))
            return drain(bot)

        (task, body), = asyncio.run(scenario())
        assert task == 'T3'
        assert parse_comment(body)['href'].endswith(f'-{fingerprint(line)}-2')

    def test_nickname_is_the_actor_without_a_bracket_prefix(self):
        line = '!log restarted nginx (T4)'

        async def scenario():
            bot = make_bot(allowed_senders=[])
            bot.handle_message('human!~h@host', CHANNEL, line)
            bot.handle_message(LOGBOT, CHANNEL, logged(line))
            return drain(bot)

        (_, body), = asyncio.run(scenario())
        assert parse_comment(body)['actor'] == 'human'

    def test_identical_lines_pair_in_arrival_order(self):
        line = '!log [a@b] same (T1)'

        async def scenario():
            bot = make_bot(dedupe_seconds=0)
            bot.handle_message(LSBOT, CHANNEL, line)
            bot.handle_message(LSBOT, CHANNEL, line)
            bot.handle_message(LOGBOT, CHANNEL, logged(line))
            assert sum(len(w) for w in bot.pending.values()) == 1
            bot.handle_message(LOGBOT, CHANNEL, logged(line, suffix='-2'))
            return drain(bot)

        hrefs = [parse_comment(body)['href'] for _, body in asyncio.run(scenario())]
        assert hrefs[0].endswith(fingerprint(line))
        assert hrefs[1].endswith(f'{fingerprint(line)}-2')

    def test_several_tasks_share_one_reply(self):
        line = '!log [a@b] moving T1 and T2'

        async def scenario():
            bot = make_bot(task_mode='any')
            bot.handle_message(LSBOT, CHANNEL, line)
            bot.handle_message(LOGBOT, CHANNEL, logged(line))
            return drain(bot)

        items = asyncio.run(scenario())
        assert [task for task, _ in items] == ['T1', 'T2']
        assert items[0][1] == items[1][1]

    def test_unconfigured_channel_is_ignored(self):
        async def scenario():
            bot = make_bot()
            bot.handle_message(LSBOT, '#elsewhere', '!log [a@b] x (T1)')
            return bot

        assert asyncio.run(scenario()).pending == {}

    def test_sender_not_allowed(self):
        async def scenario():
            bot = make_bot()
            bot.handle_message(STRANGER, CHANNEL, '!log [a@b] x (T1)')
            return bot

        assert asyncio.run(scenario()).pending == {}

    def test_skip_patterns(self):
        async def scenario():
            bot = make_bot(skip_patterns=[r'\(START\)'])
            bot.handle_message(LSBOT, CHANNEL, '!log [a@b] cmd (START) (T1)')
            bot.handle_message(LSBOT, CHANNEL, '!log [a@b] cmd (END - exit=0) (T1)')
            return bot

        bot = asyncio.run(scenario())
        assert [len(w) for w in bot.pending.values()] == [1]
        cancel_timers(bot)

    def test_duplicate_entry_is_not_commented_twice(self):
        line = '!log [a@b] once (T1)'

        async def scenario():
            bot = make_bot()
            bot.handle_message(LSBOT, CHANNEL, line)
            bot.handle_message(LSBOT, CHANNEL, line)
            return bot

        bot = asyncio.run(scenario())
        assert sum(len(w) for w in bot.pending.values()) == 1
        cancel_timers(bot)

    def test_only_new_tasks_of_a_repeated_line_are_kept(self):
        async def scenario():
            bot = make_bot(task_mode='any')
            bot.handle_message(LSBOT, CHANNEL, '!log [a@b] one T1')
            bot.handle_message(LSBOT, CHANNEL, '!log [a@b] one T1')
            return bot

        bot = asyncio.run(scenario())
        assert sum(len(w) for w in bot.pending.values()) == 1
        cancel_timers(bot)

    def test_help_and_plain_chatter_are_ignored(self):
        async def scenario():
            bot = make_bot()
            for text in ('!log help', 'hello (T1)', '<x> !log [a@b] y (T1)'):
                bot.handle_message(LSBOT, CHANNEL, text)
            return bot

        assert asyncio.run(scenario()).pending == {}

    def test_line_without_a_task_is_ignored(self):
        async def scenario():
            bot = make_bot()
            bot.handle_message(LSBOT, CHANNEL, '!log [a@b] no task here')
            return bot

        assert asyncio.run(scenario()).pending == {}

    def test_reply_with_nothing_waiting(self):
        async def scenario():
            bot = make_bot()
            bot.handle_message(LOGBOT, CHANNEL, logged('!log [a@b] ghost (T1)'))
            return drain(bot)

        assert asyncio.run(scenario()) == []

    def test_reply_for_a_different_message_does_not_pair(self):
        async def scenario():
            bot = make_bot()
            bot.handle_message(LSBOT, CHANNEL, '!log [a@b] real (T1)')
            bot.handle_message(LOGBOT, CHANNEL, logged('!log [a@b] other (T1)'))
            cancel_timers(bot)
            return drain(bot)

        assert asyncio.run(scenario()) == []

    def test_reply_from_anyone_but_the_logbot_is_ignored(self):
        line = '!log [a@b] real (T1)'

        async def scenario():
            bot = make_bot()
            bot.handle_message(LSBOT, CHANNEL, line)
            bot.handle_message(STRANGER, CHANNEL, logged(line))
            cancel_timers(bot)
            return drain(bot)

        assert asyncio.run(scenario()) == []

    def test_entries_are_read_even_when_the_logbot_mask_is_too_broad(self):
        line = '!log [a@b] real (T1)'

        async def scenario():
            bot = make_bot(logbot_mask='*!~MirahezeL@miraheze/bots')
            bot.handle_message(LSBOT, CHANNEL, line)
            pending = sum(len(waiting) for waiting in bot.pending.values())
            bot.handle_message(LOGBOT, CHANNEL, logged(line))
            return pending, drain(bot)

        pending, items = asyncio.run(scenario())
        assert pending == 1
        assert [task for task, _ in items] == ['T1']

    def test_reply_from_a_bot_sharing_the_logbots_user_and_host_is_ignored(self):
        line = '!log [a@b] real (T1)'

        async def scenario():
            bot = make_bot()
            bot.handle_message(LSBOT, CHANNEL, line)
            bot.handle_message(LSBOT, CHANNEL, logged(line))
            cancel_timers(bot)
            return drain(bot)

        assert asyncio.run(scenario()) == []

    def test_reply_in_another_channel_does_not_pair(self):
        line = '!log [a@b] real (T1)'

        async def scenario():
            bot = make_bot(irc={'channels': [CHANNEL, '#other']})
            bot.handle_message(LSBOT, CHANNEL, line)
            bot.handle_message(LOGBOT, '#other', logged(line))
            cancel_timers(bot)
            return drain(bot)

        assert asyncio.run(scenario()) == []

    def test_link_on_another_host_falls_back_to_the_date_link(self):
        line = '!log [a@b] real (T1)'

        async def scenario():
            bot = make_bot()
            bot.handle_message(LSBOT, CHANNEL, line)
            bot.handle_message(LOGBOT, CHANNEL, logged(line, url='https://evil.example/wiki/Page'))
            return drain(bot)

        (_, body), = asyncio.run(scenario())
        assert re.fullmatch(SAL_URL + r'#\d{4}-\d{2}-\d{2}', parse_comment(body)['href'])

    def test_other_logbot_chatter_is_ignored(self):
        async def scenario():
            bot = make_bot()
            bot.handle_message(LSBOT, CHANNEL, '!log [a@b] real (T1)')
            bot.handle_message(LOGBOT, CHANNEL, 'I am a logbot running on irc1.')
            bot.handle_message(LOGBOT, CHANNEL, 'Message missing. Nothing logged.')
            cancel_timers(bot)
            return drain(bot)

        assert asyncio.run(scenario()) == []

    def test_queue_overflow_drops_the_comment(self):
        line = '!log [a@b] real (T1)'

        async def scenario():
            bot = make_bot(queue_size=1)
            bot.queue.put_nowait(('T0', 'already queued'))
            bot.handle_message(LSBOT, CHANNEL, line)
            bot.handle_message(LOGBOT, CHANNEL, logged(line))
            return drain(bot)

        assert asyncio.run(scenario()) == [('T0', 'already queued')]


class TestFallback:
    def test_no_reply_uses_the_date_link(self):
        async def scenario():
            bot = make_bot(link_wait=0.05)
            bot.handle_message(LSBOT, CHANNEL, '!log [a@b] lonely (T1)')
            await asyncio.sleep(0.2)
            return bot, drain(bot)

        bot, items = asyncio.run(scenario())
        (task, body), = items
        assert task == 'T1'
        assert re.fullmatch(SAL_URL + r'#\d{4}-\d{2}-\d{2}', parse_comment(body)['href'])
        assert bot.pending == {}

    def test_late_reply_does_not_comment_again(self):
        line = '!log [a@b] slow (T1)'

        async def scenario():
            bot = make_bot(link_wait=0.05)
            bot.handle_message(LSBOT, CHANNEL, line)
            await asyncio.sleep(0.2)
            first = drain(bot)
            bot.handle_message(LOGBOT, CHANNEL, logged(line))
            return first, drain(bot)

        first, second = asyncio.run(scenario())
        assert len(first) == 1
        assert second == []

    def test_reply_in_time_cancels_the_fallback(self):
        line = '!log [a@b] quick (T1)'

        async def scenario():
            bot = make_bot(link_wait=0.05)
            bot.handle_message(LSBOT, CHANNEL, line)
            bot.handle_message(LOGBOT, CHANNEL, logged(line))
            await asyncio.sleep(0.2)
            return drain(bot)

        assert len(asyncio.run(scenario())) == 1

    def test_expire_is_a_noop_once_done(self):
        async def scenario():
            bot = make_bot()
            bot.handle_message(LSBOT, CHANNEL, '!log [a@b] x (T1)')
            (waiting,) = bot.pending.values()
            pending = waiting[0]
            pending.timer.cancel()
            pending.done = True
            bot.expire(pending)
            return drain(bot)

        assert asyncio.run(scenario()) == []


class SleepLog(list):
    async def __call__(self, delay):
        self.append(delay)


@pytest.fixture()
def sleeps(monkeypatch):
    monkeypatch.setattr(salbot.asyncio, 'sleep', SleepLog())
    return salbot.asyncio.sleep


class TestPosting:
    def post(self, bot):
        async def scenario():
            await bot.post_with_retries(asyncio.get_running_loop(), 'T1', 'body')

        asyncio.run(scenario())

    def test_success(self):
        bot = make_bot()
        bot.phorge.comment = MagicMock()
        self.post(bot)
        bot.phorge.comment.assert_called_once_with('T1', 'body')

    def test_retries_then_succeeds(self, sleeps):
        bot = make_bot()
        bot.phorge.comment = MagicMock(side_effect=[PhorgeError('a', retry=True), PhorgeError('b', retry=True), None])
        self.post(bot)
        assert bot.phorge.comment.call_count == 3
        assert sleeps == [2, 4]

    @pytest.mark.usefixtures('sleeps')
    def test_gives_up_after_the_retry_limit(self):
        bot = make_bot(retries=2)
        bot.phorge.comment = MagicMock(side_effect=PhorgeError('down', retry=True))
        self.post(bot)
        assert bot.phorge.comment.call_count == 2

    def test_does_not_retry_permanent_errors(self, sleeps):
        bot = make_bot()
        bot.phorge.comment = MagicMock(side_effect=PhorgeError('no such task'))
        self.post(bot)
        assert bot.phorge.comment.call_count == 1
        assert sleeps == []

    def test_dry_run_never_calls_phorge(self):
        bot = make_bot(dry_run=True)
        bot.phorge.comment = MagicMock()
        self.post(bot)
        bot.phorge.comment.assert_not_called()

    @pytest.mark.usefixtures('sleeps')
    def test_poster_drains_the_queue_in_order(self):
        posted = []

        async def scenario():
            bot = make_bot()
            bot.phorge.comment = lambda task, body: posted.append((task, body))
            worker = asyncio.create_task(bot.poster())
            bot.queue.put_nowait(('T1', 'one'))
            bot.queue.put_nowait(('T2', 'two'))
            await bot.queue.join()
            worker.cancel()

        asyncio.run(scenario())
        assert posted == [('T1', 'one'), ('T2', 'two')]


async def start_irc_server(respond, stop):
    sent = []

    async def handle(reader, writer):
        while True:
            raw = await reader.readline()
            if not raw:
                break
            line = raw.decode().rstrip('\r\n')
            sent.append(line)
            for out in respond(line):
                writer.write(f'{out}\r\n'.encode())
            await writer.drain()
            if stop(line):
                break
        writer.close()

    server = await asyncio.start_server(handle, '127.0.0.1', 0)
    return server, server.sockets[0].getsockname()[1], sent


def sasl_server_script(line):
    if line == 'CAP REQ :sasl':
        return [':srv CAP * ACK :sasl']
    if line == 'AUTHENTICATE PLAIN':
        return ['AUTHENTICATE +']
    if line.startswith('AUTHENTICATE '):
        return [':srv 903 salbot :SASL successful']
    if line == 'CAP END':
        return [
            ':srv 001 salbot :Welcome',
            'PING :abc',
            ':srv NOTICE salbot :\x01VERSION\x01',
        ]
    if line == f'JOIN {CHANNEL}':
        return [f':{LSBOT} PRIVMSG {CHANNEL} :!log [a@h] hi (T5)']
    return []


class TestSession:
    @staticmethod
    def run(bot, respond, stop, port_key='port'):
        async def scenario():
            server, port, sent = await start_irc_server(respond, stop)
            bot.irc_cfg[port_key] = port
            try:
                outcome = None
                try:
                    await asyncio.wait_for(bot.session(), 10)
                except (ConnectionError, asyncio.TimeoutError) as error:
                    outcome = error
                return outcome, sent
            finally:
                server.close()
                for waiting in bot.pending.values():
                    for pending in waiting:
                        pending.timer.cancel()

        return asyncio.run(scenario())

    def test_sasl_login_join_and_read_entries(self):
        bot = make_bot()
        outcome, sent = self.run(bot, sasl_server_script, lambda line: line.startswith('PONG'))
        assert isinstance(outcome, ConnectionError)
        assert sent[0] == 'CAP REQ :sasl'
        assert 'NICK salbot' in sent
        assert any(line.startswith('USER salbot 0 * :') for line in sent)
        auth = [line for line in sent if line.startswith('AUTHENTICATE ') and line != 'AUTHENTICATE PLAIN']
        assert base64.b64decode(auth[0].split(' ', 1)[1]) == b'salbot\x00salbot\x00secret'
        assert f'JOIN {CHANNEL}' in sent
        assert 'PONG :abc' in sent

    def test_channel_entry_reaches_the_pending_list(self):
        bot = make_bot()
        outcome, _ = self.run(bot, sasl_server_script, lambda line: line == f'JOIN {CHANNEL}')
        assert isinstance(outcome, ConnectionError)
        assert sum(len(w) for w in bot.pending.values()) == 1

    def test_sasl_failure(self):
        def respond(line):
            if line == 'CAP REQ :sasl':
                return [':srv CAP * ACK :sasl']
            if line == 'AUTHENTICATE PLAIN':
                return ['AUTHENTICATE +']
            if line.startswith('AUTHENTICATE '):
                return [':srv 904 salbot :SASL authentication failed']
            return []

        outcome, _ = self.run(make_bot(), respond, MagicMock(return_value=False))
        assert isinstance(outcome, ConnectionError)
        assert 'SASL failed (904)' in str(outcome)

    def test_sasl_refused_by_server_continues_without_it(self):
        def respond(line):
            if line == 'CAP REQ :sasl':
                return [':srv CAP * NAK :sasl']
            if line == 'CAP END':
                return [':srv 001 salbot :Welcome']
            return []

        outcome, sent = self.run(make_bot(), respond, lambda line: line.startswith('JOIN'))
        assert isinstance(outcome, ConnectionError)
        assert 'CAP END' in sent
        assert f'JOIN {CHANNEL}' in sent

    def test_nickserv_identify_when_sasl_is_off(self):
        def respond(line):
            return [':srv 001 salbot :Welcome'] if line.startswith('USER') else []

        bot = make_bot(irc={'sasl': False})
        outcome, sent = self.run(bot, respond, lambda line: line.startswith('JOIN'))
        assert isinstance(outcome, ConnectionError)
        assert 'CAP REQ :sasl' not in sent
        assert 'PRIVMSG NickServ :IDENTIFY salbot secret' in sent

    def test_nick_collision_appends_an_underscore(self):
        def respond(line):
            if line == 'NICK salbot':
                return [':srv 433 * salbot :Nickname is already in use']
            if line == 'NICK salbot_':
                return [':srv 001 salbot_ :Welcome']
            return []

        bot = make_bot(irc={'password': '', 'sasl': False})
        outcome, sent = self.run(bot, respond, lambda line: line.startswith('JOIN'))
        assert isinstance(outcome, ConnectionError)
        assert 'NICK salbot_' in sent
        assert bot.nick == 'salbot_'

    def test_server_password_is_sent_first(self):
        bot = make_bot(irc={'password': '', 'server_password': 'hunter2'})
        outcome, sent = self.run(bot, MagicMock(return_value=[]), lambda line: line.startswith('USER'))
        assert isinstance(outcome, ConnectionError)
        assert sent[0] == 'PASS hunter2'

    def test_error_from_the_server(self):
        def respond(line):
            return ['ERROR :Closing Link: banned'] if line.startswith('USER') else []

        outcome, _ = self.run(make_bot(irc={'password': ''}), respond, MagicMock(return_value=False))
        assert isinstance(outcome, ConnectionError)
        assert 'Closing Link: banned' in str(outcome)

    def test_silent_server_gets_pinged_then_times_out(self):
        bot = make_bot(irc={'password': '', 'ping_interval': 0.1})
        outcome, sent = self.run(bot, MagicMock(return_value=[]), MagicMock(return_value=False))
        assert isinstance(outcome, asyncio.TimeoutError)
        assert 'PING :keepalive' in sent

    def test_pending_entries_are_dropped_from_the_list_on_reconnect(self):
        async def scenario():
            bot = make_bot(irc={'password': ''})
            bot.handle_message(LSBOT, CHANNEL, '!log [a@b] old (T1)')
            timer = next(iter(bot.pending.values()))[0].timer
            server, port, _ = await start_irc_server(MagicMock(return_value=[]), MagicMock(return_value=True))
            bot.irc_cfg['port'] = port
            with contextlib.suppress(ConnectionError):
                await asyncio.wait_for(bot.session(), 10)
            server.close()
            timer.cancel()
            return bot

        assert asyncio.run(scenario()).pending == {}

    def test_connects_through_a_proxy(self, proxy_of):
        proxy = proxy_of('socks5')

        def respond(line):
            return [':srv 001 salbot :Welcome'] if line.startswith('USER') else []

        bot = make_bot(irc={
            'password': '',
            'server': 'irc.example.test',
            'proxy': f'socks5://127.0.0.1:{proxy.port}',
        })
        outcome, sent = self.run(bot, respond, lambda line: line.startswith('JOIN'))
        assert isinstance(outcome, ConnectionError)
        assert f'JOIN {CHANNEL}' in sent
        assert proxy.requests == [('irc.example.test', bot.irc_cfg['port'])]


class Stop(BaseException):
    pass


class TestRun:
    def test_backoff_and_reset(self, monkeypatch):
        delays = []
        outcomes = [OSError('down'), True, ConnectionError('closed'), Stop()]

        async def fake_sleep(delay):
            delays.append(delay)

        async def fake_session():
            outcome = outcomes.pop(0)
            if isinstance(outcome, BaseException):
                raise outcome
            return outcome

        async def scenario():
            bot = make_bot()
            bot.session = fake_session
            await bot.run()

        monkeypatch.setattr(salbot.asyncio, 'sleep', fake_sleep)
        with pytest.raises(Stop):
            asyncio.run(scenario())
        assert delays == [5, 5, 10]

    def test_delay_is_capped(self, monkeypatch):
        delays = []
        outcomes = [OSError()] * 6 + [Stop()]

        async def fake_sleep(delay):
            delays.append(delay)

        async def fake_session():
            raise outcomes.pop(0)

        async def scenario():
            bot = make_bot()
            bot.session = fake_session
            await bot.run()

        monkeypatch.setattr(salbot.asyncio, 'sleep', fake_sleep)
        with pytest.raises(Stop):
            asyncio.run(scenario())
        assert delays == [5, 10, 20, 40, 40, 40]


class TestLoadConfig:
    @staticmethod
    def write(tmp_path, config):
        path = tmp_path / 'config.json'
        path.write_text(json.dumps(config))
        return str(path)

    def test_valid(self, tmp_path):
        assert load_config(self.write(tmp_path, BASE_CONFIG))['irc']['nick'] == 'salbot'

    @pytest.mark.parametrize(('section', 'key'), [('irc', 'server'), ('irc', 'nick'), ('irc', 'channels'), ('phorge', 'url')])
    def test_missing_required_key(self, tmp_path, section, key):
        config = copy.deepcopy(BASE_CONFIG)
        del config[section][key]
        with pytest.raises(SystemExit, match=f'Missing {section}.{key}'):
            load_config(self.write(tmp_path, config))

    def test_missing_section(self, tmp_path):
        with pytest.raises(SystemExit, match='Missing irc.server'):
            load_config(self.write(tmp_path, {'phorge': {'url': 'https://p.example'}}))

    def test_token_required_unless_in_environment(self, tmp_path, monkeypatch):
        config = copy.deepcopy(BASE_CONFIG)
        del config['phorge']['api_token']
        path = self.write(tmp_path, config)
        monkeypatch.delenv('PHORGE_API_TOKEN', raising=False)
        with pytest.raises(SystemExit, match='api_token'):
            load_config(path)
        monkeypatch.setenv('PHORGE_API_TOKEN', 'from-env')
        assert load_config(path)['phorge']['url'] == 'https://phorge.example.org'

    @pytest.mark.parametrize('section', ['irc', 'phorge'])
    def test_bad_proxy(self, tmp_path, section):
        config = copy.deepcopy(BASE_CONFIG)
        config[section]['proxy'] = 'gopher://proxy.example:70'
        with pytest.raises(SystemExit, match=f'Bad {section}.proxy'):
            load_config(self.write(tmp_path, config))

    def test_empty_proxy_means_direct(self, tmp_path):
        config = copy.deepcopy(BASE_CONFIG)
        config['irc']['proxy'] = ''
        config['phorge']['proxy'] = ''
        load_config(self.write(tmp_path, config))
        assert make_bot(irc={'proxy': ''}).proxy is None

    def test_backslashes_in_secrets_survive(self, tmp_path):
        config = copy.deepcopy(BASE_CONFIG)
        config['irc']['password'] = 'abc\\Ndef'
        assert load_config(self.write(tmp_path, config))['irc']['password'] == 'abc\\Ndef'


class TestMain:
    def test_wires_config_logging_and_bot(self, tmp_path, monkeypatch):
        path = tmp_path / 'config.json'
        path.write_text(json.dumps(dict(BASE_CONFIG, log_level='warning', log_file='/tmp/salbot.log')))
        logging_calls = []
        ran = []

        class FakeBot:
            def __init__(self, config):
                ran.append(config)

            async def run(self):
                ran.append('run')

        monkeypatch.setattr(sys, 'argv', ['salbot.py', '-c', str(path)])
        monkeypatch.setattr(salbot.logging, 'basicConfig', lambda **kwargs: logging_calls.append(kwargs))
        monkeypatch.setattr(salbot, 'Bot', FakeBot)
        salbot.main()
        assert ran[1] == 'run'
        assert logging_calls[0]['level'] == salbot.logging.WARNING
        assert logging_calls[0]['filename'] == '/tmp/salbot.log'

    def test_verbose_flag_and_ctrl_c(self, tmp_path, monkeypatch):
        path = tmp_path / 'config.json'
        path.write_text(json.dumps(BASE_CONFIG))
        logging_calls = []

        class FakeBot:
            def __init__(self, config):
                self.config = config

            async def run(self):
                raise KeyboardInterrupt

        monkeypatch.setattr(sys, 'argv', ['salbot.py', '--config', str(path), '-v'])
        monkeypatch.setattr(salbot.logging, 'basicConfig', lambda **kwargs: logging_calls.append(kwargs))
        monkeypatch.setattr(salbot, 'Bot', FakeBot)
        salbot.main()
        assert logging_calls[0]['level'] == salbot.logging.DEBUG
        assert logging_calls[0]['filename'] is None


def load_adminlog(monkeypatch):
    class FakePage:
        redirect = False
        revision = 1

        def __init__(self):
            self.body = ''
            self.saves = []

        def text(self):
            return self.body

        def save(self, text, summary, bot=True):
            self.body = text
            self.saves.append((summary, bot))

    class FakeSite:
        pages = {}

        def __init__(self, *args, **kwargs):
            self.Pages = self.pages
            self.queries = [(args, kwargs)]

        def api(self, *args, **kwargs):
            self.queries.append((args, kwargs))
            return {'query': {'pages': {'1': {'canonicalurl': SAL_URL}}}}

    FakeSite.pages = type('Pages', (dict,), {'__missing__': lambda self, key: self.setdefault(key, FakePage())})()
    module = types.ModuleType('mwclient')
    module.Site = FakeSite
    monkeypatch.setitem(sys.modules, 'mwclient', module)
    spec = importlib.util.spec_from_file_location('adminlog_under_test', ADMINLOG)
    adminlog = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(adminlog)
    return adminlog, FakeSite.pages


class TestLogbotContract:
    CONFIG = types.SimpleNamespace(
        enable_identica=False,
        enable_twitter=False,
        enable_projects=False,
        wiki_category='',
        wiki_page='Tech:Server_admin_log',
        wiki_header_depth=2,
        wiki_connection='meta.example.org',
        wiki_path='/w/',
        wiki_consumer_token='',
        wiki_consumer_secret='',
        wiki_access_token='',
        wiki_access_secret='',
    )

    def test_reply_link_matches_the_fingerprint_salbot_computes(self, monkeypatch):
        adminlog, pages = load_adminlog(monkeypatch)
        line = '!log [universalomega@mw151] did a thing (T1)'
        url = adminlog.log(self.CONFIG, line.split(' ', 1)[1], '', 'universalomega')
        match = LOGGED_REPLY.match(f'Logged the message at {url}')
        assert match
        assert match.group('fp') == fingerprint(line)
        body = pages['Tech:Server_admin_log'].body
        assert f'id="{url.split("#", 1)[1]}"' in body

    def test_repeated_line_gets_a_collision_suffix_that_still_pairs(self, monkeypatch):
        adminlog, _ = load_adminlog(monkeypatch)
        line = '!log [universalomega@mw151] same (T1)'
        urls = [adminlog.log(self.CONFIG, line.split(' ', 1)[1], '', 'universalomega') for _ in range(2)]
        fragments = [url.split('#', 1)[1] for url in urls]
        assert fragments[0] != fragments[1]
        for url in urls:
            assert LOGGED_REPLY.match(f'Logged the message at {url}').group('fp') == fingerprint(line)
