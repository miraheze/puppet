import datetime
import importlib
import re
import sys
import types
from pathlib import Path

import pytest

LOGBOT_DIR = str(Path(__file__).resolve().parent)
URL = 'https://wiki.example.org/wiki/Page'


class Wiki:
    def __init__(self):
        self.pages = {}
        self.options = {}

    def sections(self, body):
        parts = [[]]
        for line in body.split('\n'):
            if re.match(r'^==.*==\s*$', line):
                parts.append([line])
            else:
                parts[-1].append(line)
        return ['\n'.join(lines).rstrip() for lines in parts]


@pytest.fixture
def env(monkeypatch):
    wiki = Wiki()

    class MwClientError(RuntimeError):
        pass

    class APIError(MwClientError):
        def __init__(self, code, info=''):
            super().__init__(code, info)
            self.code = code

    class EditError(MwClientError):
        pass

    class ProtectedPageError(EditError):
        pass

    class FakePage:
        def __init__(self, site, name, info=None):
            self.name = name
            self.exists = 'missing' not in (info or {})
            self.revision = 1
            self.last_rev_time = None
            self.edit_time = None

        def edit(self, text, summary='', bot=True, section=None, **kwargs):
            if kwargs.get('createonly') and self.name in wiki.pages:
                raise APIError('articleexists')
            if section is None:
                wiki.pages[self.name] = text
            else:
                parts = wiki.sections(wiki.pages[self.name])
                parts[section] = text.rstrip()
                wiki.pages[self.name] = '\n\n'.join(parts)
            wiki.options[self.name] = kwargs

        save = edit

    class FakeSite:
        def __init__(self, *args, **kwargs):
            pass

        def require(self, *args, **kwargs):
            return False

        def api(self, *args, **kwargs):
            return {'query': {'pages': {'1': {'canonicalurl': URL}}}}

        def get(self, action, **kwargs):
            title = kwargs['titles']
            if title not in wiki.pages:
                return {'query': {'pages': {'-1': {'title': title, 'missing': '', 'canonicalurl': URL}}}}
            body = wiki.pages[title]
            section = kwargs.get('rvsection')
            if section is not None:
                parts = wiki.sections(body)
                if section >= len(parts):
                    raise APIError('rvnosuchsection')
                body = parts[section]
            rev = {'timestamp': '2026-01-01T00:00:00Z', '*': body}
            return {'query': {'pages': {'1': {'title': title, 'canonicalurl': URL, 'revisions': [rev]}}}}

    errors = types.ModuleType('mwclient.errors')
    errors.MwClientError = MwClientError
    errors.APIError = APIError
    errors.EditError = EditError
    errors.ProtectedPageError = ProtectedPageError
    errors.MaximumRetriesExceeded = type('MaximumRetriesExceeded', (MwClientError,), {})
    errors.InvalidResponse = type('InvalidResponse', (MwClientError,), {})
    page_module = types.ModuleType('mwclient.page')
    page_module.Page = FakePage
    util = types.ModuleType('mwclient.util')
    util.parse_timestamp = lambda value: value
    module = types.ModuleType('mwclient')
    module.Site = FakeSite
    module.errors = errors
    module.page = page_module
    module.util = util
    for name, mod in (('mwclient', module), ('mwclient.errors', errors),
                      ('mwclient.page', page_module), ('mwclient.util', util)):
        monkeypatch.setitem(sys.modules, name, mod)
    monkeypatch.syspath_prepend(LOGBOT_DIR)
    monkeypatch.delitem(sys.modules, 'adminlog', raising=False)
    adminlog = importlib.import_module('adminlog')
    monkeypatch.setattr(adminlog.time, 'sleep', lambda delay: None)
    return adminlog, wiki, FakePage, FakeSite


def make_config(**extra):
    values = dict(
        enable_identica=False, enable_twitter=False, enable_projects=False,
        wiki_category='', wiki_page='Tech:Server_admin_log', wiki_header_depth=2,
        wiki_connection='meta.example.org', wiki_path='/w/', wiki_consumer_token='',
        wiki_consumer_secret='', wiki_access_token='', wiki_access_secret='',
    )
    values.update(extra)
    return types.SimpleNamespace(**values)


def test_first_entry_creates_the_page_with_createonly(env):
    adminlog, wiki, _, _ = env
    url = adminlog.log(make_config(), 'first', '', 'someone')
    body = wiki.pages['Tech:Server_admin_log']
    assert wiki.options['Tech:Server_admin_log'] == {'createonly': '1'}
    assert body.startswith('== ')
    assert url.split('#', 1)[1] in body


def test_monthly_pages_split_by_month_and_carry_the_intro(env):
    adminlog, wiki, _, _ = env
    config = make_config(wiki_monthly=True, wiki_page_intro='{{Server admin log/nav}}')
    for month in (10, 11):
        now = datetime.datetime(2026, month, 5, 12, 0, tzinfo=datetime.UTC)
        adminlog.write_entry(config, 'entry %d' % month, '', 'someone', now, {})
    assert set(wiki.pages) == {'Tech:Server_admin_log/2026-10', 'Tech:Server_admin_log/2026-11'}
    body = wiki.pages['Tech:Server_admin_log/2026-11']
    assert body.startswith('{{Server admin log/nav}}\n\n== 2026-11-05 ==')
    assert 'entry 10' not in body


def test_later_entries_of_the_day_keep_the_intro(env):
    adminlog, wiki, _, _ = env
    config = make_config(wiki_monthly=True, wiki_page_intro='{{Server admin log/nav}}')
    for text in ('first', 'second'):
        adminlog.log(config, text, '', 'someone')
    body = next(iter(wiki.pages.values()))
    assert body.startswith('{{Server admin log/nav}}')
    assert body.index('second') < body.index('first')


def test_creation_race_is_retried_as_a_normal_edit(env, monkeypatch):
    adminlog, wiki, page_class, _ = env
    original = page_class.edit
    raced = []

    def racing(self, text, *args, **kwargs):
        if not raced:
            raced.append(1)
            wiki.pages[self.name] = '== 2000-01-01 ==\n* old'
        return original(self, text, *args, **kwargs)

    monkeypatch.setattr(page_class, 'edit', racing)
    monkeypatch.setattr(page_class, 'save', racing)
    url = adminlog.log(make_config(), 'after race', '', 'someone')
    body = wiki.pages['Tech:Server_admin_log']
    assert '* old' in body
    assert url.split('#', 1)[1] in body


@pytest.mark.parametrize('slots', [True, False])
def test_blank_existing_page_without_content_key(env, monkeypatch, slots):
    adminlog, wiki, _, site_class = env
    wiki.pages['Tech:Server_admin_log'] = ''
    original = site_class.get

    def blank(self, action, **kwargs):
        result = original(self, action, **kwargs)
        for page in result['query']['pages'].values():
            for rev in page.get('revisions', []):
                rev.pop('*', None)
                if slots:
                    rev['slots'] = {'main': {'contentmodel': 'wikitext'}}
        return result

    monkeypatch.setattr(site_class, 'get', blank)
    url = adminlog.log(make_config(), 'into blank', '', 'someone')
    body = wiki.pages['Tech:Server_admin_log']
    assert body.startswith('== ')
    assert url.split('#', 1)[1] in body
