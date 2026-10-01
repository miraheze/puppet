#!/usr/bin/python3

import sys
sys.path.insert(0, r'/etc/irclogbot/mwclient')

import mwclient  # noqa: E402
import datetime  # noqa: E402
import hashlib  # noqa: E402
import logging  # noqa: E402
import requests  # noqa: E402
import time  # noqa: E402
from mwclient.page import Page  # noqa: E402
from mwclient.util import parse_timestamp  # noqa: E402

sys.path.insert(0, r'/etc/irclogbot/mwclient')

months = ["January", "February", "March", "April", "May", "June", "July",
          "August", "September", "October", "November", "December"]


SITE_MAX_AGE = 3600
MAX_ATTEMPTS = 3
RETRY_DELAYS = (2, 5)
RETRY_BUDGET = 40
RETRIABLE_API_CODES = {'badtoken', 'ratelimited', 'readonly', 'maxlag'}
_sites = {}


def get_site(config):
    key = (str(config.wiki_connection), config.wiki_path)
    cached = _sites.get(key)
    if cached and time.monotonic() - cached[1] < SITE_MAX_AGE:
        return cached[0]

    connection_options = {'timeout': 10}
    proxy = getattr(config, 'proxy', None)
    if proxy:
        connection_options['proxies'] = {'http': proxy, 'https': proxy}

    site = mwclient.Site(config.wiki_connection,
                         path=config.wiki_path,
                         clients_useragent='WikiTide-LogBot/0.2 run by the WikiTide Technology team',
                         consumer_token=config.wiki_consumer_token,
                         consumer_secret=config.wiki_consumer_secret,
                         access_token=config.wiki_access_token,
                         access_secret=config.wiki_access_secret,
                         max_retries=2,
                         retry_timeout=2,
                         connection_options=connection_options
                        )
    _sites[key] = (site, time.monotonic())
    return site


def is_retriable(error):
    if isinstance(error, requests.exceptions.HTTPError):
        code = error.response.status_code if error.response is not None else 0
        return code >= 500 or code == 429
    if isinstance(error, requests.exceptions.RequestException):
        return True
    if isinstance(error, (mwclient.errors.MaximumRetriesExceeded, mwclient.errors.InvalidResponse)):
        return True
    if isinstance(error, mwclient.errors.ProtectedPageError):
        return False
    if isinstance(error, mwclient.errors.EditError):
        return True
    if isinstance(error, mwclient.errors.APIError):
        return error.code in RETRIABLE_API_CODES or error.code.startswith('internal_api_error')
    return False


def log(config, message, project, author):
    key = (str(config.wiki_connection), config.wiki_path)
    deadline = time.monotonic() + RETRY_BUDGET
    now = datetime.datetime.now(datetime.UTC)
    state = {}
    attempt = 0
    while True:
        attempt += 1
        try:
            return write_entry(config, message, project, author, now, state)
        except Exception as error:
            _sites.pop(key, None)
            delay = RETRY_DELAYS[min(attempt, len(RETRY_DELAYS)) - 1]
            if (attempt >= MAX_ATTEMPTS or not is_retriable(error)
                    or time.monotonic() + delay > deadline):
                raise
            logging.warning('Logging failed (attempt %d): %r. Retrying in %ds.' % (attempt, error, delay))
            time.sleep(delay)


def page_url(site, info, page):
    url = info.get('canonicalurl')
    if not url:
        revdata = site.api('query', prop='info', inprop='url', revids=page.revision)
        url = list(revdata['query']['pages'].values())[0]['canonicalurl']
    return url


def write_entry(config, message, project, author, now, state):
    if config.enable_identica:
        import statusnet

    if config.wiki_category:
        import re

    site = get_site(config)
    if config.enable_projects:
        project = project.capitalize()
        pagename = config.wiki_page % project
    else:
        pagename = config.wiki_page

    query = {}
    if site.require(1, 32, raise_error=False):
        query['rvslots'] = 'main'
    result = site.get('query', prop='info|revisions', titles=pagename,
                      inprop='protection|url', rvprop='content|timestamp',
                      redirects='', **query)
    info = dict(list(result['query']['pages'].values())[0])
    revisions = info.pop('revisions', [])
    page = Page(site, pagename, info=info)
    text = ''
    if revisions:
        rev = revisions[0]
        text = rev['slots']['main']['*'] if 'slots' in rev else rev['*']
        page.last_rev_time = parse_timestamp(rev['timestamp'])
    page.edit_time = time.gmtime()

    lines = text.split('\n')
    position = 0
    previous = state.get('entry_id')
    if previous and 'id="%s"' % previous in text:
        return page_url(site, info, page) + "#" + previous
    fingerprint = hashlib.sha1(message.encode("utf-8", "replace")).hexdigest()[:8]
    base_id = "sal-%s-%s" % (now.strftime("%Y%m%d%H%M%S"), fingerprint)
    entry_id = base_id
    counter = 1
    while 'id="%s"' % entry_id in text:
        counter += 1
        entry_id = "%s-%d" % (base_id, counter)
    logline = '* <span id="%s">%02d:%02d %s: %s</span>' % (
        entry_id, now.hour, now.minute, author, message)

    # Try extracting latest date header
    header = "=" * config.wiki_header_depth
    header_date = None
    for line in lines:
        position += 1
        if line.startswith(header):
            try:
                header_date = [int(x) for x in line.strip(" =").split("-")]
            except ValueError:
                header_date = None
            break
    if header_date != [now.year, now.month, now.day]:
        lines.insert(position - 1, "")
        lines.insert(position - 1, logline)
        lines.insert(position - 1, now.strftime("{0} %Y-%m-%d {0}".format(header)))
    else:
        lines.insert(position, logline)
    if config.wiki_category:
        if not re.search(r'\[\[Category:' + config.wiki_category + r'\]\]',
                         text):
            lines.append('<noinclude>[[Category:'
                         + config.wiki_category + ']]</noinclude>')

    state['entry_id'] = entry_id
    page.save(
        '\n'.join(lines),
        "%s (%s)" % (message, author),
        bot=getattr(config, 'wiki_bot', True)
    )

    micro_update = ("%s: %s" % (author, message))[:140]

    if config.enable_identica:
        snapi = statusnet.StatusNet({'user': config.identica_username,
                                     'passwd': config.identica_password,
                                     'api': 'https://identi.ca/api'})
        snapi.update(micro_update)

    if config.enable_twitter:
        import twitter
        twitter_api = twitter.Api(**config.twitter_api_params)
        twitter_api.PostUpdate(micro_update)

    return page_url(site, info, page) + "#" + entry_id
