#!/usr/bin/python3

import adminlog
import argparse
import imp
import irc.client  # for exceptions.
import irc.bot as ircbot
import json
import logging
import os
import re
from socket import gethostname
import sys
import time
import urllib


LOG_FORMAT = "%(asctime)-15s %(levelname)s: %(message)s"


class logbot(ircbot.SingleServerIRCBot):
    def __init__(self, name, config):
        self.config = config
        self.name = name
        sasl_password = config.nick_username + ':' + config.nick_password
        server = [config.network, config.port, sasl_password]
        ircbot.SingleServerIRCBot.__init__(self, [server], config.nick,
                                           config.nick)

    def connect(self, *args, **kwargs):
        if self.config.ssl:
            import ssl
            ssl_factory = irc.connection.Factory(ipv6=True, wrapper=ssl.wrap_socket)
            self.connection.connect(*args, connect_factory=ssl_factory, **kwargs)
        else:
            self.connection.connect(*args, **kwargs)

    def get_version(self):
        return ('Miraheze Log Bot -- '
                'https://meta.miraheze.org/wiki/Tech:Server_admin_log')

    def get_cloak(self, source):
        if re.search("/", source) and re.search("@", source):
            return source.split("@")[1]

    def ask_encode(self, query):
        matches = {'[': '-5B', ']': '-5D',
                   ' ': '-20', '|': '/',
                   '=': '%3D', '?': '-3F',
                   '\n': '%0A', '\r': '%0D'}
        for match, replace in matches.iteritems():
            query = query.replace(match, replace)
        return query

    def get_query(self, query):
        if not query:
            return {}
        query = self.ask_encode(query)
        url = "%s://%s%s%s", (self.config.wiki_connection[0],
                              self.config.wiki_connection[1],
                              self.config.wiki_query_path, query)
        return self.get_json_from_url(url)

    def get_json_from_url(self, url):
        if not url:
            return {}
        f = urllib.urlopen(url)
        results = f.read()
        return json.loads(results)

    def find_user(self, author, cloak, user_json):
        for result in user_json['items']:
            username = result["label"]
            usernick = result["irc_nick"][0]
            usercloak = result["irc_cloak"][0]
            if author == usernick or cloak == usercloak:
                return username
        return ''

    def is_stale(self, cache_filename):
        if os.path.exists(cache_filename):
            stat = os.stat(cache_filename)
            now = time.time()
            mtime = stat.st_mtime
            return not (mtime > now - 300)
        else:
            return True

    def on_welcome(self, con, event):
        for target in self.config.targets:
            con.join(target)

    def get_projects(self, event, force_reload=False):
        projects = []
        try:
            cache_filename = '%s/%s-projects_json.cache' %\
                             (self.config.cachedir, self.name)
        except AttributeError:
            cache_filename = '/var/lib/adminbot/%s-project.cache' %\
                             self.name
        cache_stale = self.is_stale(cache_filename)
        if not cache_stale and not force_reload:
            project_cache_file = open(cache_filename,
                                      'r')
            project_cache = project_cache_file.read()
            project_cache_file.close()
            projects = project_cache.split(',')
        else:
            project_cache_file = open(cache_filename, 'w+')
            ldapSupportLib = ldapsupportlib.LDAPSupportLib()
            base = ldapSupportLib.getBase()
            ds = ldapSupportLib.connect()
            try:
                projectdata = ds.search_s(self.config.project_rdn
                                          + "," + base,
                                          ldap.SCOPE_SUBTREE,
                                          "(objectclass=groupofnames)")
                if not projectdata:
                    self.connection.privmsg(event.target,
                                            "Can't contact LDAP"
                                            " for project list.")
                for obj in projectdata:
                    projects.append(obj[1]["cn"][0])

                if self.config.service_group_rdn:
                    sgdata = ds.search_s(self.config.service_group_rdn
                                         + "," + base, ldap.SCOPE_SUBTREE,
                                         "(objectclass=groupofnames)")
                    if not sgdata:
                        self.connection.privmsg(event.target,
                                                "Can't contact LDAP"
                                                " for service group list.")
                    for obj in sgdata:
                        projects.append(obj[1]["cn"][0])

                project_cache_file.write(','.join(projects))
            except Exception:
                self.connection.privmsg(event.target,
                                        "Error reading project"
                                        " list from LDAP.")
        return projects

    def on_pubmsg(self, con, event):
        if event.target not in self.config.targets:
            return
        author, rest = event.source.split('!')
        cloak = self.get_cloak(event.source)
        line = event.arguments[0]
        if rest == self.config.relay_host:
            import re
            parsed = re.search(r'<(?P<discord>[ a-z0-9._]*)> (?P<message>.*)', line)
            if parsed.group('discord') is not None and parsed.group('message') is not None:
                discord = parsed.group('discord').split()[0]
                discord_author = "@" + discord
                line = parsed.group('message')
        if author in self.config.author_map:
            author = self.config.author_map[author]
        if discord_author in self.config.author_map:
            discord_author = self.config.author_map[discord_author]
        if (line.startswith(self.config.nick)
                or line.startswith("!%s" % self.config.nick)
                or line.lower() == "!log help"):
            logging.debug("'%s' got '%s'; displaying help message." %
                          (self.name, line))
            try:
                self.connection.privmsg(event.target,
                                        "I am a logbot running on %s." %
                                        gethostname())
                self.connection.privmsg(event.target,
                                        "Messages are logged to %s." %
                                        self.config.log_url)
                self.connection.privmsg(event.target,
                                        "To log a message, type !log <msg>.")
            except Exception:
                self.connection.privmsg(event.target,
                                        "To log a message, type !log <msg>.")
        elif line.lower().startswith("!log "):
            logging.debug("'%s' got '%s'; Attempting to log." %
                          (self.name, line))
            if self.config.check_users:
                try:
                    cache_filename = '%s/%s-users_json.cache' %\
                                     (self.config.cachedir, self.name)
                except AttributeError:
                    cache_filename = '/var/lib/adminbot/%s-users_json.cache' %\
                                     self.name

                cache_stale = self.is_stale(cache_filename)
                if cache_stale:
                    user_json = ''
                    user_json_cache_file = open(cache_filename, 'w+')
                    if self.config.user_query:
                        user_json = self.get_query(self.config.user_query)
                    elif self.config.user_url:
                        user_json = self.get_json_from_url(
                            self.config.user_url)
                    user_json_cache_file.write(json.dumps(user_json))
                else:
                    user_json_cache_file = open(cache_filename, 'r')
                    user_json = user_json_cache_file.read()
                    if user_json:
                        user_json = json.loads(user_json)
                    user_json_cache_file.close()
                username = self.find_user(author, cloak, user_json)
                if username:
                    author = "[[" + username + "]]"
                else:
                    if self.config.required_users_mode == "warn":
                        self.connection.privmsg(event.target,
                                                "Not a trusted nick or cloak."
                                                " This is just a warning,"
                                                " for now."
                                                " Please add your nick"
                                                " or cloak added"
                                                " to the trust list"
                                                " or your user page.")
                    if self.config.required_users_mode == "error":
                        self.connection.privmsg(event.target,
                                                "Not a trusted nick"
                                                " or cloak. Not logging."
                                                " Please add your nick"
                                                " or cloak added"
                                                " to the trust list"
                                                " or your user page.")
                        return
            if self.config.enable_projects:
                arr = line.split(" ", 2)

                if len(arr) < 2:
                    self.connection.privmsg(event.target,
                                            "Project not found, O.o. Try !log"
                                            " <project> <message> next time.")
                    return
                if len(arr) < 3:
                    self.connection.privmsg(event.target,
                                            "Message missing. Nothing logged.")
                    return

                project = arr[1]
                projects = self.get_projects(event)

                if project not in projects:
                    self.connection.privmsg(event.target,
                                            project
                                            + " is not a valid project.")
                return
                message = arr[2]
            else:
                arr = line.split(" ", 1)
                if len(arr) < 2:
                    self.connection.privmsg(event.target,
                                            "Message missing. Nothing logged.")
                    return
                project = ""
                message = arr[1]
            try:
                pageurl = adminlog.log(self.config, message, project, discord_author or author)
                if author in self.config.title_map:
                    title = self.config.title_map[author]
                else:
                    self.connection.privmsg(
                        event.target,
                        "Logged the message at {url}".format(url=pageurl)
                    )
            except Exception as e:
                logging.exception('Failed to log message: %r' % e)
                try:
                    self.connection.privmsg(
                        event.target(),
                        "An exception was raised while trying to log "
                        "your message, {author}".format(author=title)
                    )
                except Exception:
                    pass


parser = argparse.ArgumentParser(description='IRC log bot.',
                                 epilog='When run without args it will'
                                        ' enumerate bot configs'
                                        ' in /etc/adminbot.')
parser.add_argument('--config', dest='confarg', type=str,
                    help='config file that describes a single logbot')
parser.add_argument('--listprojects', dest='listprojects', action='store_true',
                    help='For unit testing, list available projects')
args = parser.parse_args()

bots = []
enable_projects = False
if args.confarg is not None:
    # Use the one config the user requested.
    confdir = os.path.dirname(args.confarg)
    fname = os.path.basename(args.confarg)
    split = os.path.splitext(fname)
    module = split[0]
    conf = imp.load_source(module, confdir + "/" + fname)

    # discard if this isn't actually a bot config file
    if 'targets' not in conf.__dict__:
        logging.error("%s does not appear to be a valid bot config." %
                      args.confarg)
        exit(1)

    if ('enable_projects' in conf.__dict__) and conf.enable_projects:
        enable_projects = True

    bots.append(logbot(module, conf))
    logging.basicConfig(stream=sys.stderr, level=logging.DEBUG,
                        format=LOG_FORMAT)
else:
    # Enumerate bot configs in /etc/adminbot;
    # Create a logbot object for each.
    sys.path.append('/etc/adminbot')
    confdir = '/etc/adminbot'
    configfiles = os.listdir(confdir)
    for fname in configfiles:
        split = os.path.splitext(fname)
        if split[1] == ".py":
            module = split[0]
            conf = imp.load_source(module, confdir + "/" + fname)

            # discard if this isn't actually a bot config file
            if 'targets' not in conf.__dict__:
                continue

            bots.append(logbot(module, conf))

            if ('enable_projects' in conf.__dict__) and conf.enable_projects:
                enable_projects = True
    logging.basicConfig(filename="/var/log/adminbot.log", level=logging.DEBUG,
                        format=LOG_FORMAT)

if not bots:
    logging.error("No config files found, so nothing to do.")
    sys.exit(1)

if enable_projects:
    import os
    import ldap

    sys.path.append('/usr/local/sbin/')
    import ldapsupportlib

if args.listprojects:
    for bot in bots:
        logging.debug("For bot %s" % bot.name)
        for proj in bot.get_projects(None, True):
            logging.debug("   %s" % proj)
    exit(0)

for bot in bots:
    logging.debug("'%s' starting" % bot.name)
    bot._connect()

while True:
    for bot in bots:
        try:
            bot.ircobj.process_once(timeout=0.1)
        except Exception:
            logging.exception('Died in main event loop')
