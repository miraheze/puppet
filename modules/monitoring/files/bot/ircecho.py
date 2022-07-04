#!/usr/bin/python3 -u
# vim: set tabstop=4 shiftwidth=4 softtabstop=4 expandtab textwidth=80 smarttab
#
# stdin -> IRC echo bot, with optional file input support.
#
# Written by Kate Turner <kate.turner@gmail.com>, source is in the public
# domain.
# Modified by Ryan Lane <rlane@wikimedia.org> for watching and taking input
# for files.  Changes are also public domain.
# Modified by Ryan Anderson <ryan@michonline.com> to handle disconnections more
# gracefully. Changes in the public domain.

import argparse
import logging
import random
import re
import string
import sys
import threading

import ib3_auth

import irc.client  # for exceptions.
from irc.bot import SingleServerIRCBot

import pyinotify

logging.basicConfig()
logger = logging.getLogger()


def beautify_message(m):
    """Clean up formatting of alert messages."""
    m = m.strip()                           # Strip trailing whitespace
    m = re.sub(r'(\w+): \1:\b', r'\1', m)   # Dedupe severity
    m = re.sub(r' {2,}', ' ', m)            # Collapse whitespace
    m = m.replace(': -', ':')               # Combine separators
    return m.strip(':-')                       # Strip trailing separators


class EchoNotifier(threading.Thread):
    def __init__(self, notifier):
        threading.Thread.__init__(self)
        self.notifier = notifier
        self.daemon = True

    def run(self):
        self.notifier.loop()


class EchoReader():
    """Essentially an initalization class"""

    def __init__(self, infile='', associatedchannel=''):
        self.infile = infile
        self.associatedchannel = associatedchannel
        self.uniques = {
            ';': 'UNIQ_' + self.get_unique_string() + '_QINU',
            ':': 'UNIQ_' + self.get_unique_string() + '_QINU',
            ',': 'UNIQ_' + self.get_unique_string() + '_QINU',
        }

        if self.infile:
            print('Using infile')
            self.notifiers = []
            self.associations = {}
            self.files = {}
            infiles = self.escape(self.infile)
            for filechan in infiles.split(';'):
                temparr = filechan.split(':')
                filename = self.unescape(temparr[0])
                try:
                    print('Opening: ' + filename)
                    with open(filename) as f:
                        f.seek(0, 2)
                        self.files[filename] = f
                except IOError:
                    print('Failed to open file: ' + filename)
                    self.files[filename] = None
                    pass
                wm = pyinotify.WatchManager()
                mask = pyinotify.IN_MODIFY | pyinotify.IN_CREATE
                wm.watch_transient_file(filename, mask, EventHandler)
                notifier = EchoNotifier(pyinotify.Notifier(wm))
                self.notifiers.append(notifier)
                # Does this file have channel associations?
                if len(temparr) > 1:
                    chans = self.unescape(temparr[1])
                    self.associations[filename] = chans
            for notifier in self.notifiers:
                print('Starting notifier loop')
                notifier.start()
        else:
            while True:
                try:
                    s = input()
                    # this throws an exception if not connected.
                    s = beautify_message(s)
                    self.bot.connection.privmsg(
                        self.chans, s.replace('\n', ''))
                except EOFError:
                    # Once the input is finished, the bot should exit
                    break
                except Exception:
                    pass

    def get_unique_string(self):
        unique = ''
        for i in range(15):
            unique = unique + random.choice(string.ascii_letters)
        return unique

    def escape(self, string):
        escaped_string = re.sub(r'\\\;', self.uniques[';'], string)
        escaped_string = re.sub(r'\\\:', self.uniques[':'], escaped_string)
        return re.sub(r'\\\,', self.uniques[','], escaped_string)

    def unescape(self, string):
        unescaped_string = re.sub(self.uniques[';'], ';', string)
        unescaped_string = re.sub(self.uniques[':'], ':', unescaped_string)
        return re.sub(self.uniques[','], ',', unescaped_string)

    def readfile(self, filename):
        if self.files[filename]:
            return self.files[filename].read()
        else:
            return None

    def getchannels(self, filename):
        if filename in self.associations:
            return self.associations[filename]
        else:
            return bot.chans


class EchoBot(ib3_auth.SASL, SingleServerIRCBot):
    def __init__(self, chans, nickname, nickname_pass, server, port=6667, ssl=False, ipv6=True, ident_passwd=None):  # noqa: U100
        print(f'Connecting to IRC server {server}...')

        self.chans = chans
        self.nickname = nickname
        kwargs = {}
        if ssl:
            import ssl
            ssl_factory = irc.connection.Factory(
                ipv6=True, wrapper=ssl.wrap_socket)
            kwargs['connect_factory'] = ssl_factory

        SingleServerIRCBot.__init__(
            self, [(server, port)], nickname_pass, 'IRC echo bot', **kwargs)
        if ident_passwd is not None:
            ib3_auth.SASL.__init__(self, [(server, port)], nickname_pass, 'IRC echo bot', ident_passwd,
                                   **kwargs)

    def on_nicknameinuse(self, c, e):  # noqa: U100
        c.nick(c.get_nickname() + '_')

    def on_welcome(self, c, e):  # noqa: U100
        print('Connected')

        c.nick(self.nickname)

        for chan in [self.chans]:
            c.join(chan)


class EventHandler(pyinotify.ProcessEvent):
    def process_IN_MODIFY(self, event):
        s = reader.readfile(event.pathname)
        s = beautify_message(s)
        if s:
            chans = reader.getchannels(event.pathname)
            try:
                s = s.replace('\n', '')
                # python irc library enforces a 512 maximum byte limit per
                # message per RFC 2812. While this is overly strict, let's try
                # to conform. Split the message into multiple messages.
                # Unfortunately the library enforces this limit at the protocol
                # level meaning we have to account for the entire IRC command,
                # the format of which is:
                #     :source PRIVMSG <target> :Message
                # which is not easy to calculate as the channel is of variable
                # size. Using #wikimedia-operations means this is 40 bytes, so
                # set a 450 max message size and hope is enough.
                # We anyway catch and silently drop the message later on if that
                # turns out to not be true
                outputs = [s[0 + i:450 + i] for i in range(0, len(s), 450)]
                for out in outputs:
                    bot.connection.privmsg(chans, out)
            except (irc.client.ServerNotConnectedError, irc.client.MessageTooLong,
                    UnicodeDecodeError) as e:
                print(f'Error writing: {e}'
                      'Dropping this message: "{s}"')

    def process_IN_CREATE(self, event):
        try:
            print('Reopening file: ' + event.pathname)
            reader.files[event.pathname] = open(event.pathname)
        except IOError:
            print('Failed to reopen file: ' + event.pathname)
            pass


# construct the argument parse and parse the arguments
ap = argparse.ArgumentParser(conflict_handler='resolve')
ap.add_argument('--ident_passwd_file', required=False,
                help='path to file that contains the irc password.')
ap.add_argument('--infile', required=True,
                help='maps location of irc log to the irc channel.')
ap.add_argument('--channel', required=True,
                help='a list of irc channels for the bot to join.')
ap.add_argument('--nickname', required=True,
                help='nickname of the irc bot.')
ap.add_argument('--nickname-pass', required=True,
                help='Password for nickname.')
ap.add_argument('--server', required=True,
                help='irc server to connect to, eg freenode and also including the port.')
args = vars(ap.parse_args())

chans = args['channel']
nickname = args['nickname']
nickname_pass = args['nickname_pass']
server = args['server'].split(':')[0]
try:
    ssl = args['server'].split(':')[1].startswith('+')
    port = int(args['server'].split(':')[1].strip('+'))
except IndexError:
    ssl = False
    port = 6667
global bot
if args['ident_passwd_file']:
    with open(args['ident_passwd_file']) as f:
        bot = EchoBot(chans, nickname, nickname_pass,
                      server, port, ssl, f.read().strip())
else:
    bot = EchoBot(chans, nickname, nickname_pass, server, port, ssl)
global reader
reader = EchoReader(args['infile'])
try:
    bot.start()
except Exception:
    logger.exception('Caught exception, exiting')
    sys.exit(1)
