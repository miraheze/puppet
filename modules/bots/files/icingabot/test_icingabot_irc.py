import base64
import contextlib
import copy
import http.client
import http.server
import io
import json
import re
import shutil
import socket
import ssl
import subprocess
import threading
import time

import pytest
from test_icingabot import BASE_CONFIG

import icingabot
from icingabot import (
    GrafanaHook,
    IrcLink,
    IrcRelay,
    Proxy,
    clean_text,
    format_notification,
    grafana_messages,
    invalid_values,
    load_config,
    missing_keys,
    open_socket,
    parse_irc,
    supervise,
    truncate,
)


IRC_CONFIG = BASE_CONFIG['irc']
ICINGA_CONFIG = BASE_CONFIG['icinga']


def relay_config(**changes):
    config = copy.deepcopy(BASE_CONFIG)
    config['irc'].update(changes)
    return config


def notification(host='mw1', service='mw1 Disk', state=2, kind='PROBLEM', output='DISK CRITICAL', users=('icingaadmin',), **extra):
    event = {
        'type': 'Notification',
        'notification_type': kind,
        'host': host,
        'users': list(users),
        'check_result': {'state': float(state), 'output': output},
    }
    if service:
        event['service'] = service
    event.update(extra)
    return event


class TestFormatting:
    def test_a_service_problem(self):
        assert format_notification(notification()) == 'PROBLEM - mw1 Disk on mw1 is CRITICAL: DISK CRITICAL'

    @pytest.mark.parametrize(('state', 'name'), [(0, 'OK'), (1, 'WARNING'), (2, 'CRITICAL'), (3, 'UNKNOWN'), (9, 'UNKNOWN')])
    def test_service_states(self, state, name):
        assert f'is {name}:' in format_notification(notification(state=state))

    def test_a_host_problem(self):
        event = notification(service=None, state=1, output='PING CRITICAL')
        assert format_notification(event) == 'PROBLEM - Host mw1 is DOWN: PING CRITICAL'

    def test_a_host_recovery(self):
        event = notification(service=None, state=0, kind='RECOVERY', output='PING OK')
        assert format_notification(event) == 'RECOVERY - Host mw1 is UP: PING OK'

    def test_author_and_comment_follow_the_output(self):
        event = notification(kind='ACKNOWLEDGEMENT', author='someone', text='looking into it')
        assert format_notification(event).endswith('DISK CRITICAL someone looking into it')

    def test_no_check_result_is_unknown(self):
        event = {'type': 'Notification', 'host': 'mw1', 'service': 'Disk', 'notification_type': 'CUSTOM'}
        assert format_notification(event) == 'CUSTOM - Disk on mw1 is UNKNOWN:'

    def test_no_host_is_dropped(self):
        assert format_notification({'type': 'Notification', 'service': 'Disk'}) is None

    def test_line_breaks_cannot_start_a_second_irc_command(self):
        event = notification(output='fine\r\nQUIT :bye\nPRIVMSG #x :hi', text='a\x00b\x03c')
        line = format_notification(event)
        assert not re.search(r'[\x00-\x1f\x7f]', line)
        assert 'QUIT :bye' in line

    def test_control_characters_in_names_are_removed(self):
        assert format_notification(notification(host='mw\r\n1'))[:26] == 'PROBLEM - mw1 Disk on mw 1'

    def test_long_output_is_cut_to_fit_one_irc_line(self):
        line = format_notification(notification(output='x' * 1000))
        assert len(line.encode()) <= 400
        assert line.endswith('...')

    def test_cutting_never_splits_a_character(self):
        text = truncate('é' * 300)
        assert len(text.encode()) <= 400
        text.encode('utf-8').decode('utf-8')

    def test_short_text_is_untouched(self):
        assert truncate('hello') == 'hello'

    def test_clean_text_collapses_whitespace(self):
        assert clean_text(' a \t b\n\nc ') == 'a b c'


class TestParseIrc:
    @pytest.mark.parametrize(('line', 'expected'), [
        ('PING :abc', (None, 'PING', ['abc'])),
        (':srv 001 nick :Welcome there', ('srv', '001', ['nick', 'Welcome there'])),
        (':n!u@h PRIVMSG #c :hi all', ('n!u@h', 'PRIVMSG', ['#c', 'hi all'])),
        (':srv CAP * ACK :sasl', ('srv', 'CAP', ['*', 'ACK', 'sasl'])),
        ('ping :x', (None, 'PING', ['x'])),
        ('', (None, '', [])),
    ])
    def test_lines(self, line, expected):
        assert parse_irc(line) == expected


class TestProxy:
    @pytest.mark.parametrize(('url', 'kind', 'port'), [
        ('socks5://bastion.example.org', 'socks5', 1080),
        ('socks5h://bastion.example.org:9050', 'socks5', 9050),
        ('http://bastion.example.org', 'http', 8080),
        ('http://bastion.example.org:3128', 'http', 3128),
    ])
    def test_accepted_urls(self, url, kind, port):
        proxy = Proxy(url)
        assert (proxy.kind, proxy.port) == (kind, port)
        assert str(proxy) == f'{kind}://bastion.example.org:{port}'

    @pytest.mark.parametrize('url', ['ftp://bastion.example.org', 'bastion.example.org:8080', 'http://', ''])
    def test_rejected_urls(self, url):
        with pytest.raises(ValueError, match='Unsupported proxy scheme|no host'):
            Proxy(url)

    def test_credentials_are_decoded(self):
        proxy = Proxy('socks5://user%40x:p%3Aw@bastion.example.org')
        assert (proxy.username, proxy.password) == ('user@x', 'p:w')


class Listener:
    def __init__(self, handler):
        self.sock = socket.socket()
        self.sock.bind(('127.0.0.1', 0))
        self.sock.listen(5)
        self.port = self.sock.getsockname()[1]
        self.handler = handler
        self.connections = []
        threading.Thread(target=self.accept, daemon=True).start()

    def accept(self):
        while True:
            try:
                conn, _ = self.sock.accept()
            except OSError:
                return
            self.connections.append(conn)
            threading.Thread(target=self.guard, args=(conn,), daemon=True).start()

    def guard(self, conn):
        with conn, contextlib.suppress(OSError):
            self.handler(conn)

    def close(self):
        self.sock.close()
        for conn in self.connections:
            with contextlib.suppress(OSError):
                conn.shutdown(socket.SHUT_RDWR)
            conn.close()


class FakeIrc:
    def __init__(self, sasl=True, ssl_context=None, nick_in_use=False, sasl_reply='903', error=None):
        self.sasl = sasl
        self.ssl_context = ssl_context
        self.nick_in_use = nick_in_use
        self.sasl_reply = sasl_reply
        self.error = error
        self.lines = []
        self.listener = Listener(self.serve)
        self.port = self.listener.port

    def serve(self, conn):
        if self.ssl_context:
            conn = self.ssl_context.wrap_socket(conn, server_side=True)

        def send(line):
            conn.sendall(f'{line}\r\n'.encode())

        buffer = b''
        while True:
            chunk = conn.recv(4096)
            if not chunk:
                return
            buffer += chunk
            while b'\r\n' in buffer:
                raw, _, buffer = buffer.partition(b'\r\n')
                line = raw.decode()
                self.lines.append(line)
                self.react(line, send)

    def react(self, line, send):
        command = line.split(' ')[0]
        if line == 'CAP REQ :sasl':
            send(':irc CAP * ACK :sasl')
        elif line == 'AUTHENTICATE PLAIN':
            send('AUTHENTICATE +')
        elif command == 'AUTHENTICATE':
            send(f':irc {self.sasl_reply} nick :SASL result')
        elif command == 'NICK' and self.nick_in_use:
            send(':irc 433 * icinga-miraheze :Nickname is already in use')
        elif command == 'USER' and self.error:
            send(f'ERROR :{self.error}')
        elif (command == 'USER' and not self.sasl) or line == 'CAP END':
            send(':irc 001 nick :Welcome')
        elif command == 'JOIN':
            channel = line.split(' ')[1]
            send(f':nick!u@h JOIN {channel}')
            send(f':irc 366 nick {channel} :End of /NAMES list.')
        elif command == 'PING':
            send(f":irc PONG irc :{line.split(':', 1)[1]}")

    def wait_for(self, check, timeout=5):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if check(list(self.lines)):
                return True
            time.sleep(0.02)
        return False

    def messages(self, lines=None):
        return [line for line in (self.lines if lines is None else lines) if line.startswith('PRIVMSG')]

    def close(self):
        self.listener.close()


class Running:
    def __init__(self, relay):
        self.error = None
        self.link = IrcLink(relay)
        self.thread = threading.Thread(target=self.go, daemon=True)
        self.thread.start()

    def go(self):
        try:
            self.link.run()
        except OSError as error:
            self.error = error

    def wait(self, timeout=5):
        self.thread.join(timeout)
        assert not self.thread.is_alive(), 'the link is still running'
        return self.error


@pytest.fixture(autouse=True)
def _quick_polling(monkeypatch):
    monkeypatch.setattr(icingabot, 'POLL_SECONDS', 0.05)


@pytest.fixture()
def irc_server():
    servers = []

    def make(**kwargs):
        server = FakeIrc(**kwargs)
        servers.append(server)
        return server

    yield make
    for server in servers:
        server.close()


def make_relay(fake, tmp_path, **changes):
    changes.setdefault('port', fake.port)
    changes.setdefault('heartbeat_file', str(tmp_path / 'irc_alive'))
    return IrcRelay(relay_config(**changes))


class TestIrcLink:
    def test_registers_with_sasl_joins_and_posts(self, irc_server, tmp_path):
        server = irc_server()
        relay = make_relay(server, tmp_path)
        relay.outbox.append('PROBLEM - mw1 Disk on mw1 is CRITICAL: DISK CRITICAL')
        running = Running(relay)
        assert server.wait_for(lambda lines: any(line.startswith('PRIVMSG') for line in lines))
        server.close()
        assert 'already' not in str(running.wait())
        blob = base64.b64decode(next(line for line in server.lines if line.startswith('AUTHENTICATE ') and line != 'AUTHENTICATE PLAIN').split(' ')[1])
        assert blob == b'mirahezebots\x00mirahezebots\x00irc-secret'
        assert server.lines[:3] == ['CAP REQ :sasl', 'NICK icinga-miraheze', 'USER mirahezebots 0 * :Icinga to IRC bot']
        assert server.lines.index('CAP END') < server.lines.index('JOIN #miraheze-tech-ops')
        assert server.messages() == ['PRIVMSG #miraheze-tech-ops :PROBLEM - mw1 Disk on mw1 is CRITICAL: DISK CRITICAL']

    def test_does_not_post_before_the_channel_is_joined(self, irc_server, tmp_path):
        server = irc_server()
        relay = make_relay(server, tmp_path)
        relay.outbox.append('hello')
        Running(relay)
        assert server.wait_for(lambda lines: bool(server.messages(lines)))
        assert server.lines.index('JOIN #miraheze-tech-ops') < server.lines.index('PRIVMSG #miraheze-tech-ops :hello')

    def test_messages_added_later_are_posted_in_order(self, irc_server, tmp_path):
        server = irc_server()
        relay = make_relay(server, tmp_path)
        Running(relay)
        assert server.wait_for(lambda lines: 'JOIN #miraheze-tech-ops' in lines)
        time.sleep(0.2)
        relay.outbox.extend(['one', 'two', 'three'])
        assert server.wait_for(lambda lines: len([line for line in lines if line.startswith('PRIVMSG')]) == 3)
        assert [line.split(':', 1)[1] for line in server.messages()] == ['one', 'two', 'three']

    def test_without_a_password_it_skips_sasl(self, irc_server, tmp_path):
        server = irc_server(sasl=False)
        relay = make_relay(server, tmp_path, password='')
        relay.outbox.append('hello')
        Running(relay)
        assert server.wait_for(lambda lines: bool(server.messages(lines)))
        assert not any(line.startswith(('CAP', 'AUTHENTICATE')) for line in server.lines)

    def test_sasl_can_be_turned_off(self, irc_server, tmp_path):
        server = irc_server(sasl=False)
        relay = make_relay(server, tmp_path, sasl=False)
        Running(relay)
        assert server.wait_for(lambda lines: 'PRIVMSG NickServ :IDENTIFY mirahezebots irc-secret' in lines)

    def test_a_nick_in_use_is_not_taken_over_with_another_name(self, irc_server, tmp_path):
        server = irc_server(nick_in_use=True)
        running = Running(make_relay(server, tmp_path))
        assert 'icinga-miraheze is already in use' in str(running.wait())
        assert [line for line in server.lines if line.startswith('NICK')] == ['NICK icinga-miraheze']

    def test_failed_sasl_stops_the_connection(self, irc_server, tmp_path):
        server = irc_server(sasl_reply='904')
        running = Running(make_relay(server, tmp_path))
        assert 'SASL failed (904)' in str(running.wait())
        assert not any(line.startswith('JOIN') for line in server.lines)

    def test_a_server_error_stops_the_connection(self, irc_server, tmp_path):
        server = irc_server(error='Closing link: banned')
        running = Running(make_relay(server, tmp_path))
        assert 'Closing link: banned' in str(running.wait())

    def test_the_password_is_never_logged(self, irc_server, tmp_path, caplog):
        server = irc_server()
        relay = make_relay(server, tmp_path)
        relay.outbox.append('hello')
        with caplog.at_level('DEBUG', logger='icingabot'):
            Running(relay)
            assert server.wait_for(lambda lines: bool(server.messages(lines)))
        assert 'irc-secret' not in caplog.text
        assert base64.b64encode(b'mirahezebots\x00mirahezebots\x00irc-secret').decode() not in caplog.text

    def test_posts_to_every_channel(self, irc_server, tmp_path):
        server = irc_server()
        relay = make_relay(server, tmp_path, channels=['#a', '#b'])
        relay.outbox.append('hello')
        Running(relay)
        assert server.wait_for(lambda lines: len([line for line in lines if line.startswith('PRIVMSG')]) == 2)
        assert server.messages() == ['PRIVMSG #a :hello', 'PRIVMSG #b :hello']

    def test_answers_ping(self, irc_server, tmp_path):
        server = irc_server()
        relay = make_relay(server, tmp_path)
        Running(relay)
        assert server.wait_for(lambda lines: 'JOIN #miraheze-tech-ops' in lines)
        server.listener.connections[0].sendall(b'PING :token\r\n')
        assert server.wait_for(lambda lines: 'PONG :token' in lines)

    def test_a_quiet_connection_is_pinged_then_dropped(self, irc_server, tmp_path):
        server = irc_server()
        server.react = lambda line, send: FakeIrc.react(server, line, send) if not line.startswith('PING') else None
        running = Running(make_relay(server, tmp_path, ping_interval=0.2))
        assert 'ping timeout' in str(running.wait())
        assert 'PING :keepalive' in server.lines

    def test_the_connection_closing_is_an_error(self, irc_server, tmp_path):
        server = irc_server()
        running = Running(make_relay(server, tmp_path))
        assert server.wait_for(lambda lines: 'JOIN #miraheze-tech-ops' in lines)
        server.close()
        assert 'closed the connection' in str(running.wait())

    def test_a_kick_means_reconnecting(self, irc_server, tmp_path):
        server = irc_server()
        running = Running(make_relay(server, tmp_path))
        assert server.wait_for(lambda lines: 'JOIN #miraheze-tech-ops' in lines)
        server.listener.connections[0].sendall(b':op!u@h KICK #miraheze-tech-ops icinga-miraheze :bye\r\n')
        assert 'kicked from #miraheze-tech-ops' in str(running.wait())

    def test_a_channel_it_cannot_join_is_an_error(self, irc_server, tmp_path):
        server = irc_server()
        original = server.react

        def react(line, send):
            if line.startswith('JOIN'):
                send(':irc 474 nick #miraheze-tech-ops :Cannot join channel (+b)')
            else:
                original(line, send)

        server.react = react
        running = Running(make_relay(server, tmp_path))
        assert 'cannot join #miraheze-tech-ops (474)' in str(running.wait())

    def test_a_message_is_kept_when_sending_fails(self):
        relay = IrcRelay(relay_config())
        link = IrcLink(relay)

        class Broken:
            @staticmethod
            def sendall(data):
                raise BrokenPipeError(len(data))

        link.sock = Broken()
        relay.outbox.append('keep me')
        with pytest.raises(BrokenPipeError):
            link.post()
        assert list(relay.outbox) == ['keep me']

    def test_registration_that_never_finishes_times_out(self, irc_server, tmp_path, monkeypatch):
        server = irc_server()
        server.react = Calls()
        monkeypatch.setattr(icingabot, 'REGISTER_TIMEOUT', 0.3)
        assert 'registration timed out' in str(Running(make_relay(server, tmp_path)).wait())

    def test_an_endless_line_is_refused(self, irc_server, tmp_path):
        server = irc_server()
        server.react = Calls()
        running = Running(make_relay(server, tmp_path))
        assert server.wait_for(lambda lines: any(line.startswith('USER') for line in lines))
        server.listener.connections[0].sendall(b'x' * 9000)
        assert 'too long' in str(running.wait())


class TestHeartbeat:
    def test_written_while_joined_and_the_stream_is_healthy(self, irc_server, tmp_path):
        server = irc_server()
        Running(make_relay(server, tmp_path))
        beat = tmp_path / 'irc_alive'
        end = time.monotonic() + 5
        while not beat.exists() and time.monotonic() < end:
            time.sleep(0.02)
        assert beat.read_text().strip().isdigit()

    def test_not_written_when_the_icinga_stream_is_stale(self, irc_server, tmp_path):
        server = irc_server()
        relay = make_relay(server, tmp_path)
        relay.stream_seen = time.monotonic() - 3600
        Running(relay)
        assert server.wait_for(lambda lines: 'JOIN #miraheze-tech-ops' in lines)
        time.sleep(0.4)
        assert not (tmp_path / 'irc_alive').exists()

    def test_not_written_before_the_channel_is_joined(self, irc_server, tmp_path):
        server = irc_server()
        original = server.react
        server.react = lambda line, send: None if line.startswith('JOIN') else original(line, send)
        Running(make_relay(server, tmp_path))
        assert server.wait_for(lambda lines: 'JOIN #miraheze-tech-ops' in lines)
        time.sleep(0.4)
        assert not (tmp_path / 'irc_alive').exists()

    @pytest.mark.parametrize(('age', 'healthy'), [(0, True), (100, True), (179, True), (181, False)])
    def test_the_stream_counts_as_healthy_for_three_timeouts(self, monkeypatch, age, healthy):
        relay = IrcRelay(relay_config())
        relay.icinga = None
        relay.stream_timeout = 60
        relay.stream_seen = 1000.0
        monkeypatch.setattr(icingabot.time, 'monotonic', lambda: 1000.0 + age)
        assert relay.healthy() is healthy


class HttpConnectProxy:
    def __init__(self, auth=None, refuse=False):
        self.auth = auth
        self.refuse = refuse
        self.requests = []
        self.listener = Listener(self.serve)
        self.port = self.listener.port

    def serve(self, conn):
        head = b''
        while not head.endswith(b'\r\n\r\n'):
            chunk = conn.recv(1)
            if not chunk:
                return
            head += chunk
        text = head.decode()
        self.requests.append(text)
        if self.refuse:
            conn.sendall(b'HTTP/1.1 403 Forbidden\r\n\r\n')
            return
        host, port = text.split(' ')[1].rsplit(':', 1)
        upstream = socket.create_connection((host if host != 'localhost' else '127.0.0.1', int(port)))
        conn.sendall(b'HTTP/1.1 200 Connection established\r\n\r\n')
        pipe(conn, upstream)

    def close(self):
        self.listener.close()


class SocksProxy:
    def __init__(self, credentials=None):
        self.credentials = credentials
        self.targets = []
        self.listener = Listener(self.serve)
        self.port = self.listener.port

    def serve(self, conn):
        greeting = icingabot.read_exact(conn, 2)
        methods = icingabot.read_exact(conn, greeting[1])
        if self.credentials:
            assert 2 in methods
            conn.sendall(b'\x05\x02')
            icingabot.read_exact(conn, 1)
            user = icingabot.read_exact(conn, icingabot.read_exact(conn, 1)[0])
            password = icingabot.read_exact(conn, icingabot.read_exact(conn, 1)[0])
            ok = (user.decode(), password.decode()) == self.credentials
            conn.sendall(b'\x01' + (b'\x00' if ok else b'\x01'))
            if not ok:
                return
        else:
            conn.sendall(b'\x05\x00')
        request = icingabot.read_exact(conn, 4)
        if request[3] == 3:
            host = icingabot.read_exact(conn, icingabot.read_exact(conn, 1)[0]).decode()
        else:
            host = socket.inet_ntoa(icingabot.read_exact(conn, 4))
        port = int.from_bytes(icingabot.read_exact(conn, 2), 'big')
        self.targets.append((request[3], host, port))
        upstream = socket.create_connection(('127.0.0.1', port))
        conn.sendall(b'\x05\x00\x00\x01' + b'\x00' * 6)
        pipe(conn, upstream)

    def close(self):
        self.listener.close()


def pipe(left, right):
    def forward(source, sink):
        with contextlib.suppress(OSError):
            while True:
                data = source.recv(4096)
                if not data:
                    break
                sink.sendall(data)
        for sock in (source, sink):
            with contextlib.suppress(OSError):
                sock.shutdown(socket.SHUT_RDWR)

    thread = threading.Thread(target=forward, args=(right, left), daemon=True)
    thread.start()
    forward(left, right)
    thread.join(1)


class TestThroughAProxy:
    def test_http_connect(self, irc_server, tmp_path):
        server = irc_server()
        proxy = HttpConnectProxy()
        try:
            relay = make_relay(server, tmp_path, server='localhost', proxy=f'http://127.0.0.1:{proxy.port}')
            relay.outbox.append('through the proxy')
            Running(relay)
            assert server.wait_for(lambda lines: bool(server.messages(lines)))
        finally:
            proxy.close()
        assert proxy.requests[0].startswith(f'CONNECT localhost:{server.port} HTTP/1.1\r\n')
        assert server.messages() == ['PRIVMSG #miraheze-tech-ops :through the proxy']

    def test_http_connect_sends_credentials(self, irc_server, tmp_path):
        server = irc_server()
        proxy = HttpConnectProxy()
        try:
            relay = make_relay(server, tmp_path, proxy=f'http://user:p%40ss@127.0.0.1:{proxy.port}')
            Running(relay)
            assert server.wait_for(lambda lines: 'JOIN #miraheze-tech-ops' in lines)
        finally:
            proxy.close()
        token = base64.b64encode(b'user:p@ss').decode()
        assert f'Proxy-Authorization: Basic {token}' in proxy.requests[0]

    def test_a_refusing_proxy_is_a_connection_error(self, irc_server, tmp_path):
        server = irc_server()
        proxy = HttpConnectProxy(refuse=True)
        try:
            running = Running(make_relay(server, tmp_path, proxy=f'http://127.0.0.1:{proxy.port}'))
            assert 'Proxy refused CONNECT: HTTP/1.1 403 Forbidden' in str(running.wait())
        finally:
            proxy.close()
        assert server.lines == []

    def test_socks5_leaves_name_resolution_to_the_proxy(self, irc_server, tmp_path):
        server = irc_server()
        proxy = SocksProxy()
        try:
            relay = make_relay(server, tmp_path, server='localhost', proxy=f'socks5h://127.0.0.1:{proxy.port}')
            relay.outbox.append('via socks')
            Running(relay)
            assert server.wait_for(lambda lines: bool(server.messages(lines)))
        finally:
            proxy.close()
        assert proxy.targets == [(3, 'localhost', server.port)]

    def test_socks5_with_a_password(self, irc_server, tmp_path):
        server = irc_server()
        proxy = SocksProxy(credentials=('user', 'secret'))
        try:
            Running(make_relay(server, tmp_path, proxy=f'socks5://user:secret@127.0.0.1:{proxy.port}'))
            assert server.wait_for(lambda lines: 'JOIN #miraheze-tech-ops' in lines)
        finally:
            proxy.close()
        assert proxy.targets == [(1, '127.0.0.1', server.port)]

    def test_socks5_with_the_wrong_password(self, irc_server, tmp_path):
        server = irc_server()
        proxy = SocksProxy(credentials=('user', 'secret'))
        try:
            running = Running(make_relay(server, tmp_path, proxy=f'socks5://user:wrong@127.0.0.1:{proxy.port}'))
            assert 'rejected the credentials' in str(running.wait())
        finally:
            proxy.close()

    def test_no_proxy_connects_directly(self, irc_server):
        server = irc_server()
        open_socket('127.0.0.1', server.port, 5).close()

    def test_an_unreachable_proxy_is_an_oserror(self, irc_server, tmp_path):
        server = irc_server()
        running = Running(make_relay(server, tmp_path, proxy='http://127.0.0.1:9'))
        assert running.wait() is not None
        assert server.lines == []


@pytest.mark.skipif(shutil.which('openssl') is None, reason='needs the openssl command')
class TestTls:
    @staticmethod
    def certificate(tmp_path):
        key, cert = tmp_path / 'key.pem', tmp_path / 'cert.pem'
        subprocess.run(
            [
                'openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
                '-keyout', str(key), '-out', str(cert), '-subj', '/CN=localhost',
                '-addext', 'subjectAltName=DNS:localhost',
            ],
            check=True,
            capture_output=True,
        )
        return key, cert

    def test_posts_over_tls_and_verifies_the_server(self, irc_server, tmp_path, monkeypatch):
        key, cert = self.certificate(tmp_path)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(str(cert), str(key))
        server = irc_server(ssl_context=context)
        real = ssl.create_default_context
        monkeypatch.setattr(icingabot.ssl, 'create_default_context', lambda: real(cafile=str(cert)))
        relay = make_relay(server, tmp_path, ssl=True, server='localhost')
        relay.outbox.append('secure hello')
        Running(relay)
        assert server.wait_for(lambda lines: bool(server.messages(lines)))
        assert server.messages() == ['PRIVMSG #miraheze-tech-ops :secure hello']

    def test_an_untrusted_certificate_is_refused(self, irc_server, tmp_path):
        key, cert = self.certificate(tmp_path)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(str(cert), str(key))
        server = irc_server(ssl_context=context)
        running = Running(make_relay(server, tmp_path, ssl=True, server='localhost'))
        assert 'CERTIFICATE_VERIFY_FAILED' in str(running.wait())
        assert server.lines == []


class FakeEvents:
    def __init__(self, *runs):
        self.runs = list(runs)
        self.types = []

    def events(self, types=('StateChange',)):
        self.types.append(list(types))
        run = self.runs.pop(0)
        if isinstance(run, Exception):
            raise run
        yield from run


class Stop(Exception):
    pass


class Calls:
    def __init__(self):
        self.calls = []

    def __call__(self, *args, **kwargs):
        self.calls.append((args, kwargs))


class TestRelay:
    def test_only_notifications_for_the_wanted_users_are_relayed(self):
        relay = IrcRelay(relay_config())
        assert relay.wanted(notification(users=['icingaadmin', 'other']))
        assert not relay.wanted(notification(users=['someone']))
        assert not relay.wanted(notification(users=[]))
        assert not relay.wanted(dict(notification(), users=None))
        assert not relay.wanted(dict(notification(), type='StateChange'))

    def test_an_empty_user_list_relays_everything(self):
        relay = IrcRelay(relay_config(notify_users=[]))
        assert relay.wanted(notification(users=['someone']))
        assert relay.wanted(notification(users=[]))
        assert not relay.wanted(dict(notification(), type='StateChange'))

    def test_handle_queues_the_formatted_line(self):
        relay = IrcRelay(relay_config())
        relay.handle(notification())
        relay.handle(notification(users=['someone']))
        assert list(relay.outbox) == ['PROBLEM - mw1 Disk on mw1 is CRITICAL: DISK CRITICAL']

    def test_a_full_outbox_drops_the_oldest(self, caplog):
        relay = IrcRelay(relay_config())
        for number in range(5):
            relay.handle(notification(output=f'n{number}'))
        assert [line.rsplit(' ', 1)[1] for line in relay.outbox] == ['n2', 'n3', 'n4']
        assert 'dropping the oldest' in caplog.text

    def test_the_relay_uses_its_own_queue_name(self):
        assert IrcRelay(relay_config()).icinga.queue == 'icingabot-irc'

    def test_pump_asks_only_for_notifications(self, monkeypatch):
        relay = IrcRelay(relay_config())
        relay.icinga = FakeEvents([notification()], Stop())
        monkeypatch.setattr(icingabot.time, 'sleep', Calls())
        with pytest.raises(Stop):
            relay.pump()
        assert relay.icinga.types == [['Notification'], ['Notification']]
        assert len(relay.outbox) == 1

    def test_pump_keeps_going_after_icinga_goes_away(self, monkeypatch):
        relay = IrcRelay(relay_config())
        relay.icinga = FakeEvents(ConnectionRefusedError('refused'), ValueError('garbage'), [notification()], Stop())
        sleeps = []
        monkeypatch.setattr(icingabot.time, 'sleep', sleeps.append)
        with pytest.raises(Stop):
            relay.pump()
        assert len(relay.outbox) == 1
        assert sleeps[:2] == [1, 2]

    def test_the_retry_delay_is_capped(self, monkeypatch):
        relay = IrcRelay(relay_config())
        relay.icinga = FakeEvents(*[OSError('down')] * 6, Stop())
        sleeps = []
        monkeypatch.setattr(icingabot.time, 'sleep', sleeps.append)
        with pytest.raises(Stop):
            relay.pump()
        assert sleeps == [1, 2, 4, 4, 4, 4]

    def test_one_bad_event_does_not_stop_the_stream(self, monkeypatch):
        relay = IrcRelay(relay_config())
        relay.icinga = FakeEvents(['not a dict', notification()], Stop())
        monkeypatch.setattr(icingabot.time, 'sleep', Calls())
        with pytest.raises(Stop):
            relay.pump()
        assert len(relay.outbox) == 1

    def test_pump_refreshes_the_health_clock_when_the_stream_ends_idle(self, monkeypatch):
        relay = IrcRelay(relay_config())
        relay.icinga = FakeEvents([], Stop())
        relay.stream_seen = 0.0
        monkeypatch.setattr(icingabot.time, 'sleep', Calls())
        with pytest.raises(Stop):
            relay.pump()
        assert relay.stream_seen > 0.0

    def test_run_reconnects_after_a_failure_and_backs_off(self, monkeypatch):
        relay = IrcRelay(relay_config())
        outcomes = [ConnectionError('first'), ConnectionError('second'), ConnectionError('third'), Stop()]

        class Link:
            joined = False

            def __init__(self, config):
                self.config = config

            def run(self):
                raise outcomes.pop(0)

        monkeypatch.setattr(icingabot, 'IrcLink', Link)
        sleeps = []
        monkeypatch.setattr(icingabot.time, 'sleep', sleeps.append)
        with pytest.raises(Stop):
            relay.run()
        assert sleeps == [1, 2, 4]

    def test_run_starts_the_backoff_over_after_a_good_session(self, monkeypatch):
        relay = IrcRelay(relay_config())
        outcomes = [(False, ConnectionError('a')), (False, ConnectionError('b')), (True, ConnectionError('c')), (False, Stop())]

        class Link:
            def __init__(self, relay):
                self.relay = relay
                self.joined = False

            def run(self):
                self.joined, error = outcomes.pop(0)
                raise error

        monkeypatch.setattr(icingabot, 'IrcLink', Link)
        sleeps = []
        monkeypatch.setattr(icingabot.time, 'sleep', sleeps.append)
        with pytest.raises(Stop):
            relay.run()
        assert sleeps == [1, 2, 1]


class TestConfig:
    @pytest.mark.parametrize('key', sorted(icingabot.REQUIRED['irc']))
    def test_every_irc_setting_is_required(self, key):
        config = relay_config()
        del config['irc'][key]
        assert missing_keys(config) == [f'irc.{key}']

    @pytest.mark.parametrize('key', sorted(icingabot.REQUIRED['grafana']))
    def test_every_grafana_setting_is_required(self, key):
        config = copy.deepcopy(BASE_CONFIG)
        del config['grafana'][key]
        assert missing_keys(config) == [f'grafana.{key}']

    @pytest.mark.parametrize(('key', 'value'), [
        ('server', ''),
        ('port', 0),
        ('port', 70000),
        ('port', '6697'),
        ('port', True),
        ('ssl', 'true'),
        ('sasl', 1),
        ('nick', 'bad nick'),
        ('nick', ''),
        ('username', 'a\r\nb'),
        ('realname', 'bot\r\nQUIT'),
        ('realname', None),
        ('password', 'pw\nJOIN #x'),
        ('password', None),
        ('channels', []),
        ('channels', 'miraheze'),
        ('channels', ['no-hash']),
        ('channels', ['#a b']),
        ('channels', ['#a,#b']),
        ('notify_users', 'icingaadmin'),
        ('notify_users', [1]),
        ('ping_interval', 0),
        ('reconnect_min', 0),
        ('reconnect_max', 0),
        ('heartbeat_interval', -1),
        ('message_interval', -1),
        ('message_interval', None),
        ('queue_size', 0),
        ('queue_size', 1.5),
        ('queue', ''),
        ('heartbeat_file', ''),
        ('proxy', 'ftp://bastion.example.org'),
        ('proxy', 5),
    ])
    def test_bad_irc_values_are_caught(self, key, value):
        problems = invalid_values(relay_config(**{key: value}))
        assert problems
        assert all(problem.startswith('irc.') for problem in problems)

    @pytest.mark.parametrize(('key', 'value'), [
        ('message_interval', 0),
        ('message_interval', 0.5),
        ('notify_users', []),
        ('proxy', None),
        ('proxy', ''),
        ('proxy', 'socks5h://bastion.example.org:1080'),
        ('channels', ['#a', '&b']),
        ('ssl', False),
    ])
    def test_good_irc_values_are_accepted(self, key, value):
        assert invalid_values(relay_config(**{key: value})) == []

    def test_the_backoff_must_not_run_backwards(self):
        assert invalid_values(relay_config(reconnect_min=10, reconnect_max=5)) == [
            'irc.reconnect_max must not be lower than irc.reconnect_min',
        ]

    @pytest.mark.parametrize(('key', 'value'), [
        ('host', ''),
        ('host', None),
        ('port', 0),
        ('port', '5100'),
        ('max_lines', 0),
        ('max_lines', 1.5),
        ('max_body', 0),
        ('max_body', True),
    ])
    def test_bad_grafana_values_are_caught(self, key, value):
        config = copy.deepcopy(BASE_CONFIG)
        config['grafana'][key] = value
        problems = invalid_values(config)
        assert problems
        assert all(problem.startswith('grafana.') for problem in problems)

    def test_load_config_refuses_a_config_without_the_new_sections(self, tmp_path):
        config = copy.deepcopy(BASE_CONFIG)
        del config['grafana']
        path = tmp_path / 'config.json'
        path.write_text(json.dumps(config))
        with pytest.raises(SystemExit, match='Missing in config: grafana'):
            load_config(str(path))


def payload(message, **extra):
    return {'title': 'ignored', 'message': message, **extra}


class TestGrafanaFormatting:
    def test_one_line_is_one_message(self):
        assert grafana_messages(payload('[Grafana] FIRING: Load is high'), 5) == ['[Grafana] FIRING: Load is high']

    def test_each_line_of_the_message_is_its_own_irc_message(self):
        assert grafana_messages(payload('one\ntwo\r\nthree'), 5) == ['one', 'two', 'three']

    def test_empty_lines_are_dropped(self):
        assert grafana_messages(payload('\n\none\n  \n\ntwo\n'), 5) == ['one', 'two']

    def test_an_empty_message_queues_nothing(self):
        assert grafana_messages(payload(''), 5) == []

    def test_the_title_is_not_used(self):
        assert grafana_messages(payload('body', title='Title'), 5) == ['body']

    def test_too_many_lines_become_one_summary_line(self):
        messages = grafana_messages(payload('\n'.join(f'line {i}' for i in range(7))), 3)
        assert messages == ['line 0', 'line 1', 'line 2', '[Grafana] 4 more lines not shown']

    def test_exactly_the_limit_has_no_summary(self):
        assert len(grafana_messages(payload('a\nb\nc'), 3)) == 3

    def test_a_long_line_is_cut(self):
        line, = grafana_messages(payload('y' * 1000), 5)
        assert len(line.encode()) <= 400
        assert line.endswith('...')

    def test_control_characters_cannot_start_a_second_irc_command(self):
        for line in grafana_messages(payload('ok\x00\x01 QUIT :bye\x7f\tx\nPRIVMSG #a :b'), 5):
            assert not re.search(r'[\x00-\x1f\x7f]', line)

    def test_the_message_is_required(self):
        with pytest.raises(KeyError):
            grafana_messages({'title': 'x'}, 3)

    @pytest.mark.parametrize('message', [None, 1, ['a'], {'a': 'b'}])
    def test_the_message_must_be_a_string(self, message):
        with pytest.raises(TypeError):
            grafana_messages(payload(message), 3)


class Headers(dict):
    def get(self, key, default=None):
        return super().get(key, default)


def make_hook(**changes):
    config = copy.deepcopy(BASE_CONFIG)
    config['grafana'].update(changes)
    relay = IrcRelay(config)
    return GrafanaHook(config, relay), relay


def post(hook, body, path='/', length=None, **headers):
    raw = body if isinstance(body, bytes) else json.dumps(body).encode()
    sent = Headers(headers)
    if length != 'missing':
        sent['Content-Length'] = str(len(raw) if length is None else length)
    return hook.receive(path, sent, io.BytesIO(raw))


class TestGrafanaReceive:
    def test_a_good_request_queues_the_messages(self):
        hook, relay = make_hook()
        assert post(hook, payload('first\nsecond')) == 204
        assert list(relay.outbox) == ['first', 'second']

    def test_no_authorization_is_needed_and_none_is_checked(self):
        hook, relay = make_hook()
        assert post(hook, payload('x'), Authorization='Bearer anything') == 204
        assert post(hook, payload('y')) == 204
        assert list(relay.outbox) == ['x', 'y']

    @pytest.mark.parametrize('path', ['/x', '/index', ''])
    def test_only_the_root_path_exists(self, path):
        hook, relay = make_hook()
        assert post(hook, payload('x'), path=path) == 404
        assert not relay.outbox

    def test_a_missing_length_is_refused(self):
        hook, _ = make_hook()
        assert post(hook, payload('x'), length='missing') == 411

    def test_a_garbled_length_is_refused(self):
        hook, _ = make_hook()
        assert post(hook, payload('x'), length='abc') == 411

    def test_a_negative_length_is_refused(self):
        hook, _ = make_hook()
        assert post(hook, payload('x'), length=-5) == 400

    def test_a_body_over_the_limit_is_refused_unread(self):
        hook, relay = make_hook(max_body=50)
        assert post(hook, payload('x' * 100)) == 413
        assert not relay.outbox

    @pytest.mark.parametrize('body', [
        b'not json', b'', b'\xff\xfe', b'[]', b'{}', b'null', b'{"title": "x"}',
        b'{"message": 1}', b'{"message": null}', b'{"message": ["a"]}',
    ])
    def test_bad_bodies_are_refused_and_queue_nothing(self, body):
        hook, relay = make_hook()
        assert post(hook, body) == 400
        assert not relay.outbox

    def test_the_line_count_is_capped(self):
        hook, relay = make_hook(max_lines=2)
        assert post(hook, payload('\n'.join('abcde'))) == 204
        assert list(relay.outbox) == ['a', 'b', '[Grafana] 3 more lines not shown']

    def test_a_short_body_is_a_timeout_not_a_crash(self):
        hook, _ = make_hook()

        class Dying:
            @staticmethod
            def read(count):
                raise TimeoutError(count)

        assert hook.receive('/', Headers({'Content-Length': '10'}), Dying()) == 408


def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


@pytest.fixture()
def listening():
    hooks = []

    def start(**changes):
        hook, relay = make_hook(host='127.0.0.1', port=free_port(), **changes)
        threading.Thread(target=hook.serve, daemon=True).start()
        end = time.monotonic() + 5
        while hook.server is None and time.monotonic() < end:
            time.sleep(0.01)
        assert hook.server is not None
        hooks.append(hook)
        return hook, relay

    yield start
    for hook in hooks:
        hook.server.shutdown()


def request(port, body, host='127.0.0.1', path='/', method='POST'):
    connection = http.client.HTTPConnection(host, port, timeout=5)
    headers = {'Content-Type': 'application/json'}
    try:
        connection.request(method, path, body=json.dumps(body), headers=headers)
        response = connection.getresponse()
        return response.status, response.read()
    finally:
        connection.close()


class TestGrafanaServer:
    def test_a_post_is_answered_and_queued(self, listening):
        hook, relay = listening()
        assert request(hook.cfg['port'], payload('hello')) == (204, b'')
        assert list(relay.outbox) == ['hello']

    def test_bad_json_gets_400(self, listening):
        hook, _ = listening()
        assert request(hook.cfg['port'], 'plain text')[0] == 400

    def test_other_paths_get_404(self, listening):
        hook, _ = listening()
        assert request(hook.cfg['port'], {}, path='/other')[0] == 404

    def test_get_is_not_supported(self, listening):
        hook, _ = listening()
        assert request(hook.cfg['port'], {}, method='GET')[0] == 501

    def test_many_requests_at_once(self, listening):
        hook, relay = listening(max_lines=1)
        relay.outbox = type(relay.outbox)(maxlen=100)
        results = []

        def go():
            results.append(request(hook.cfg['port'], payload('x'))[0])

        threads = [threading.Thread(target=go) for _ in range(20)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join(10)
        assert results == [204] * 20
        assert len(relay.outbox) == 20

    def test_the_server_is_ipv4_only(self):
        assert icingabot.HookServer.address_family == socket.AF_INET

    def test_binding_does_not_wait_on_a_reverse_lookup(self, listening, monkeypatch):
        def refuse(*args):
            raise AssertionError(args)

        monkeypatch.setattr(socket, 'getfqdn', refuse)
        hook, _ = listening()
        assert hook.server.server_name == '127.0.0.1'

    def test_a_busy_port_is_an_oserror_for_the_supervisor(self, listening):
        hook, _ = listening()
        other, _ = make_hook(host='127.0.0.1', port=hook.cfg['port'])
        with pytest.raises(OSError, match='in use'):
            other.serve()


def fake_loops(monkeypatch, started):
    class FakeRelay:
        def __init__(self, config):
            self.config = config

        def pump(self):
            started['irc-events'].set()

        def run(self):
            started['irc'].set()

    class FakeHook:
        def __init__(self, config, relay):
            self.config = config
            self.relay = relay

        def serve(self):
            started['grafana'].set()

    monkeypatch.setattr(icingabot, 'IrcRelay', FakeRelay)
    monkeypatch.setattr(icingabot, 'GrafanaHook', FakeHook)


class TestMain:
    @staticmethod
    def patch(monkeypatch, tmp_path, crashes=0):
        path = tmp_path / 'config.json'
        path.write_text(json.dumps(BASE_CONFIG))
        monkeypatch.setattr('sys.argv', ['icingabot.py', '-c', str(path)])
        monkeypatch.setattr(icingabot.logging, 'basicConfig', Calls())
        monkeypatch.setattr(icingabot.time, 'sleep', Calls())
        bots = []

        class FakeBot:
            def __init__(self, config):
                self.config = config
                bots.append(self)

            def run(self):
                if len(bots) <= crashes:
                    raise RuntimeError('phorge exploded')

        monkeypatch.setattr(icingabot, 'Bot', FakeBot)
        started = {name: threading.Event() for name in ('irc-events', 'irc', 'grafana')}
        fake_loops(monkeypatch, started)
        return started, bots

    def test_every_loop_starts(self, tmp_path, monkeypatch):
        started, bots = self.patch(monkeypatch, tmp_path)
        icingabot.main()
        assert len(bots) == 1
        for name, event in started.items():
            assert event.wait(5), name

    def test_a_phorge_crash_does_not_stop_irc_or_grafana(self, tmp_path, monkeypatch):
        started, bots = self.patch(monkeypatch, tmp_path, crashes=2)
        icingabot.main()
        assert len(bots) == 3
        for name, event in started.items():
            assert event.wait(5), name

    def test_an_irc_crash_does_not_stop_phorge_or_grafana(self, tmp_path, monkeypatch):
        calls = []

        class Relay:
            def __init__(self, config):
                self.config = config

            def run(self):
                calls.append('irc')
                if len(calls) < 3:
                    raise RuntimeError('irc exploded')

            def pump(self):
                return None

        started, bots = self.patch(monkeypatch, tmp_path)
        monkeypatch.setattr(icingabot, 'IrcRelay', Relay)
        icingabot.main()
        end = time.monotonic() + 5
        while len(calls) < 3 and time.monotonic() < end:
            time.sleep(0.01)
        assert calls == ['irc', 'irc', 'irc']
        assert len(bots) == 1
        assert started['grafana'].wait(5)

    def test_a_grafana_crash_does_not_stop_the_others(self, tmp_path, monkeypatch):
        calls = []

        class Hook:
            def __init__(self, config, relay):
                self.config = config
                self.relay = relay

            def serve(self):
                calls.append('grafana')
                if len(calls) < 3:
                    raise OSError('address already in use')

        started, bots = self.patch(monkeypatch, tmp_path)
        monkeypatch.setattr(icingabot, 'GrafanaHook', Hook)
        icingabot.main()
        end = time.monotonic() + 5
        while len(calls) < 3 and time.monotonic() < end:
            time.sleep(0.01)
        assert calls == ['grafana'] * 3
        assert len(bots) == 1
        assert started['irc'].wait(5)

    def test_the_grafana_listener_shares_the_irc_outbox(self, tmp_path, monkeypatch):
        seen = []

        class Hook:
            def __init__(self, config, relay):
                seen.append((config, relay))

            def serve(self):
                return None

        built = []

        class Relay:
            def __init__(self, config):
                built.append((config, self))

            def run(self):
                return None

            def pump(self):
                return None

        self.patch(monkeypatch, tmp_path)
        monkeypatch.setattr(icingabot, 'IrcRelay', Relay)
        monkeypatch.setattr(icingabot, 'GrafanaHook', Hook)
        icingabot.main()
        assert [relay for _, relay in seen] == [relay for _, relay in built]
        assert seen[0][0] is built[0][0]


class TestSupervise:
    def test_returns_when_the_job_finishes(self, monkeypatch):
        sleeps = []
        monkeypatch.setattr(icingabot.time, 'sleep', sleeps.append)
        supervise('job', lambda: None)
        assert sleeps == []

    def test_restarts_after_a_crash_with_a_growing_delay(self, monkeypatch, caplog):
        outcomes = [RuntimeError('a'), RuntimeError('b'), RuntimeError('c'), None]
        sleeps = []

        def job():
            outcome = outcomes.pop(0)
            if outcome:
                raise outcome

        monkeypatch.setattr(icingabot.time, 'sleep', sleeps.append)
        supervise('job', job)
        assert sleeps == [5, 10, 20]
        assert 'job crashed' in caplog.text

    def test_the_delay_stops_growing_at_the_cap(self, monkeypatch):
        outcomes = [RuntimeError('x')] * 9 + [None]
        sleeps = []

        def job():
            outcome = outcomes.pop(0)
            if outcome:
                raise outcome

        monkeypatch.setattr(icingabot.time, 'sleep', sleeps.append)
        supervise('job', job)
        assert max(sleeps) == 300

    def test_a_long_run_resets_the_delay(self, monkeypatch):
        clock = iter([0, 1, 100, 500, 501, 600])
        outcomes = [RuntimeError('a'), RuntimeError('b'), None]
        sleeps = []

        def job():
            outcome = outcomes.pop(0)
            if outcome:
                raise outcome

        monkeypatch.setattr(icingabot.time, 'monotonic', lambda: next(clock))
        monkeypatch.setattr(icingabot.time, 'sleep', sleeps.append)
        supervise('job', job)
        assert sleeps == [5, 5]

    def test_ctrl_c_is_not_swallowed(self, monkeypatch):
        def job():
            raise KeyboardInterrupt

        monkeypatch.setattr(icingabot.time, 'sleep', Calls())
        with pytest.raises(KeyboardInterrupt):
            supervise('job', job)


class StreamServer(http.server.BaseHTTPRequestHandler):
    bodies = []
    logged = []

    def do_POST(self):
        length = int(self.headers['Content-Length'])
        type(self).bodies.append(json.loads(self.rfile.read(length)))
        self.send_response(200)
        self.end_headers()

    def log_message(self, *args):
        type(self).logged.append(args)


class TestIcingaQueue:
    def test_events_can_ask_for_notifications(self):
        server = http.server.HTTPServer(('127.0.0.1', 0), StreamServer)
        threading.Thread(target=server.handle_request, daemon=True).start()
        StreamServer.bodies = []
        icinga = icingabot.Icinga(dict(ICINGA_CONFIG, url=f'http://127.0.0.1:{server.server_port}'), 'icingabot-irc')
        assert list(icinga.events(['Notification'])) == []
        server.server_close()
        assert StreamServer.bodies == [{'queue': 'icingabot-irc', 'types': ['Notification']}]

    def test_an_explicit_queue_wins_and_the_config_one_is_the_default(self):
        assert icingabot.Icinga(dict(ICINGA_CONFIG, queue='from-config')).queue == 'from-config'
        assert icingabot.Icinga(dict(ICINGA_CONFIG, queue='from-config'), 'explicit').queue == 'explicit'
