# SPDX-License-Identifier: Apache-2.0
# Portions Copyright (c) 2010 OpenStack, LLC.
# Everything else Copyright (c) 2011 Wikimedia Foundation, Inc.
# all of it licensed under the Apache Software License, included by reference.

# unit test is in test_rewrite.py. Tests are referenced by numbered comments.

import re
import urllib.parse

from swift.common import swob
from swift.common.utils import get_logger
from swift.common.wsgi import WSGIContext


class DumbRedirectHandler(urllib.request.HTTPRedirectHandler):

    def http_error_301(self, req, fp, code, msg, headers):
        return None

    def http_error_302(self, req, fp, code, msg, headers):
        return None


class _WikiTideRewriteContext(WSGIContext):
    """
    Rewrite Media Store URLs so that swift knows how to deal with them.
    """

    def __init__(self, rewrite, conf):
        WSGIContext.__init__(self, rewrite.app)
        self.app = rewrite.app
        self.logger = rewrite.logger

        self.account = conf['account'].strip()
        self.thumbhost = conf['thumbhost'].strip()
        self.user_agent = conf['user_agent'].strip()
        self.bind_port = conf['bind_port'].strip()

    def handle404(self, reqorig, url, container, obj):
        """
        Return a swob.Response which fetches the thumbnail from the thumb
        host and returns it. Note also that the thumb host might write it out
        to Swift so it won't 404 next time.
        """
        # go to the thumb media store for unknown files
        reqorig.host = self.thumbhost
        # upload doesn't like our User-agent.
        proxy_handler = urllib.request.ProxyHandler({'http': self.thumbhost})
        redirect_handler = DumbRedirectHandler()
        opener = urllib.request.build_opener(redirect_handler, proxy_handler)

        opener.addheaders = []
        if reqorig.headers.get('User-Agent') is not None:
            opener.addheaders.append(('User-Agent', reqorig.headers.get('User-Agent')))
        else:
            opener.addheaders.append(('User-Agent', self.user_agent))
        for header_to_pass in ['X-Forwarded-For', 'X-Forwarded-Proto',
                               'Accept', 'Accept-Encoding', 'X-Original-URI', 'X-Client-IP', 'X-Real-IP']:
            if reqorig.headers.get(header_to_pass) is not None:
                opener.addheaders.append((header_to_pass, reqorig.headers.get(header_to_pass)))

        # At least in theory, we shouldn't be handing out links to originals
        # that we don't have (or in the case of thumbs, can't generate).
        # However, someone may have a formerly valid link to a file, so we
        # should do them the favor of giving them a 404.
        try:
            # break apach the url, url-encode it, and put it back together
            urlobj = list(urllib.parse.urlsplit(reqorig.url))
            # encode the URL but don't encode %s and /s
            urlobj[2] = urllib.parse.quote(urlobj[2], '%/')
            encodedurl = urllib.parse.urlunsplit(urlobj)

            match = re.match(
                    r'^http://(?P<host>[^/]+)/(?P<proj>[^-/]+)/thumb/(?P<path>.+)',
                    encodedurl)
            if match:
                if match.group('proj').endswith('wikibeta'):
                    proj = match.group('proj').removesuffix("wikibeta")
                    hostname = '%s.mirabeta.org' % (proj)
                else:
                    proj = match.group('proj').removesuffix("wiki")
                    hostname = '%s.miraheze.org' % (proj)
                # ok, replace the URL with just the part starting with thumb/
                # take off the first two parts of the path.
                encodedurl = 'https://%s/w/thumb_handler.php/%s' % (
                    hostname, match.group('path'))
                # add in the X-Original-URI with the swift got (minus the hostname)
                opener.addheaders.append(
                    ('X-Original-URI', list(urllib.parse.urlsplit(reqorig.url))[2]))
            else:
                # ASSERT this code should never be hit since only thumbs
                # should call the 404 handler
                self.logger.warn("non-thumb in 404 handler! encodedurl = %s" % encodedurl)
                resp = swob.HTTPNotFound('Unexpected error')
                return resp

            # ok, call the encoded url
            upcopy = opener.open(encodedurl)
        except urllib.error.HTTPError as error:
            # Wrap the urllib2 HTTPError into a swob HTTPException
            status = error.code
            body = error.fp.read()
            headers = dict(list(error.hdrs.items()))
            if status not in swob.RESPONSE_REASONS:
                # Generic status description in case of unknown status reasons.
                status = "%s Error" % status
            # We're having itermittent issues with Transfer-Encoding,
            # remove it from the headers. This is added from urllib anyways.
            # See https://github.com/django/daphne/issues/371#issuecomment-862186611
            if headers.get('Transfer-Encoding') is not None :
                del headers['Transfer-Encoding']
            return swob.HTTPException(status=status, body=body, headers=headers)
        except urllib.error.URLError as error:
            msg = 'There was a problem while contacting the image scaler: %s' % \
                  error.reason
            return swob.HTTPServiceUnavailable(msg)

        # get the Content-Type.
        uinfo = upcopy.info()
        c_t = uinfo.get_content_type()

        resp = swob.Response(app_iter=upcopy, content_type=c_t)

        headers_whitelist = [
            'Content-Length',
            'Content-Disposition',
            'Last-Modified',
            'Accept-Ranges',
            'XKey',
            'Server',
            'Nginx-Request-Date',
            'Nginx-Response-Date'
        ]
        # add in the headers if we've got them
        for header in headers_whitelist:
            if uinfo.get(header) is not None:
                resp.headers[header] = uinfo.get(header)

        # also add CORS; see also our CORS middleware
        resp.headers['Access-Control-Allow-Origin'] = '*'

        return resp

    def handle_request(self, env, start_response):
        try:
            return self._handle_request(env, start_response)
        except UnicodeDecodeError:
            self.logger.exception('Failed to decode request %r', env)
            resp = swob.HTTPBadRequest('Failed to decode request')
            return resp(env, start_response)

    def _handle_request(self, env, start_response):
        # In python3, we have to care about bytes vs strings
        # req.path_info is url-encoded ASCII
        # req.path is the byte stream resulting from url-decoding path_info
        # turned into a string using the latin1 encoding (even though mw
        # uses utf-8); essentially req.path contains "mojibake" and if we
        # need to manipulate it, we have to re-decode-and-encode back into
        # utf-8.
        # Similarly, when setting path_info, we have to be sure to set
        # it to either a byte sequence of valid utf-8 codepoints, or a
        # latin1 encoding of the desired byte sequence.

        req = swob.Request(env)

        # If the client has sent us URL-encoded invalid utf-8, then say
        # 400 immediately and don't log a backtrace
        try:
            urllib.parse.unquote(req.path, errors="strict")
        except UnicodeDecodeError:
            resp = swob.HTTPBadRequest('Failed to decode request')
            return resp(env, start_response)

        # Double (or triple, etc.) slashes in the URL should be ignored;
        # collapse them.
        # mojibake-safe since 0x2F is / in all relevant encodings
        req.path_info = re.sub(r'/{2,}', '/', req.path_info)

        # Keep a copy of the original request so we can ask the scalers for it
        reqorig = swob.Request(req.environ.copy())

	# Containers have 1 component: container.
        #
        # Projects are the wiki db name.
        # Zones are thumb, temp, etc.
        #
        # These attributes are mapped to container names in the form of either:
        # (a) proj-lang-repo-zone (if not sharded)
        # (b) proj-lang-repo-zone.shard (if sharded)
        # (c) global-data-repo-zone (if not sharded)
        # (d) global-data-repo-zone.shard (if sharded)
        #
        # Rewrite wiki-global URLs of these forms:
        # (a) http://static.miraheze.org/<proj>/math/<relpath>
        #         => http://127.0.0.1:8080/v1/AUTH_<hash>/<container>/<proj>/math/<relpath>
        # (b) http://static.miraheze.org/<proj>/<relpath>
        #         => http://127.0.0.1:8080/v1/AUTH_<hash>/<container>/<proj>/<relpath>
        # (c) http://static.miraheze.org/<proj>/archive/<relpath>
        #         => http://127.0.0.1:8080/v1/AUTH_<hash>/<container>/<proj>/archive/<relpath>
        # (d) http://static.miraheze.org/<proj>/thumb/<relpath>
        #         => http://127.0.0.1:8080/v1/AUTH_<hash>/<container>/<proj>/thumb/<relpath>
        # (e) https://static.miraheze.org/<proj>/temp/<relpath>
        #         => http://127.0.0.1:8080/v1/AUTH_<hash>/<container>/<proj>/temp/<relpath>
        # (f) https://static.miraheze.org/<proj>/transcoded/<relpath>
        #         => http://127.0.0.1:8080/v1/AUTH_<hash>/<container>/<proj>/transcoded/<relpath>
        # (g) https://static.miraheze.org/<proj>/timeline/<relpath>
        #         => http://127.0.0.1:8080/v1/AUTH_<hash>/<container>/<proj>/timeline/<relpath>

        zone = ''

        # regular uploads
        match = re.match(
            (r'^/(?P<proj>[^/]+)/'
             r'((?P<zone>transcoded|thumb)/)?'
             r'(?P<path>((temp|archive)/)?[0-9a-f]/[0-9a-f]{2}/.+)$'),
            req.path)
        if match:
            proj = match.group('proj')
            repo = 'local'  # the upload repo name is "local"
            # Get the repo zone (if not provided that means "public")
            zone = (match.group('zone') if match.group('zone') else 'public')
            # Get the object path relative to the zone (and thus container)
            obj = match.group('path')  # e.g. "archive/a/ab/..."

        # timeline renderings
        if match is None:
            # /metawiki/timeline/a876297c277d80dfd826e1f23dbfea3f.png
            match = re.match(
                r'^/(?P<proj>[^/]+)/(?P<repo>timeline)/(?P<path>.+)$',
                req.path)
            if match:
                proj = match.group('proj')  # metawiki
                repo = match.group('repo')  # timeline
                zone = 'render'
                obj = match.group('path')  # a876297c277d80dfd826e1f23dbfea3f.png

        if match is None:
            match = re.match(
                r'^/(?P<proj>[^/]+)/(?P<repo>avatars)/(?P<path>.+)$',
                req.path)
            if match:
                proj = match.group('proj')  # metawiki
                repo = match.group('repo')  # avatars
                zone = ''
                obj = match.group('path')

        if match is None:
            match = re.match(
                r'^/(?P<proj>[^/]+)/(?P<repo>awards)/(?P<path>.+)$',
                req.path)
            if match:
                proj = match.group('proj')  # metawiki
                repo = match.group('repo')  # awards
                zone = ''
                obj = match.group('path')

        # math renderings
        if match is None:
            # /metawiki/math/c/9/f/c9f2055dadfb49853eff822a453d9ceb.png (legacy)
            match = re.match(
                (r'^/(?P<proj>[^/]+)/(?P<path>math/[0-9a-f]/[0-9a-f]/.+)$'),
                req.path)
            if match:
                proj = match.group('proj')
                repo = 'local'
                zone = 'public'
                obj = 'math/' + match.group('path')  # math/c/9/f/c9f2055dadfb49853eff822a453d9ceb.png

        # score renderings
        if match is None:
            # /metawiki/score/j/q/jqn99bwy8777srpv45hxjoiu24f0636/jqn99bwy.png
            # /metawiki/score/override-midi/8/i/8i9pzt87wtpy45lpz1rox8wusjkt7ki.ogg
            match = re.match(r'^/(?P<proj>[^/]+)/(?P<repo>score)/(?P<path>.+)$', req.path)
            if match:
                proj = match.group('proj')
                repo = match.group('repo')  # score
                zone = 'render'
                obj = match.group('path')  # j/q/jqn99bwy8777srpv45hxjoiu24f0636/jqn99bwy.png

        if match is None:
            match = re.match(r'^/(?P<proj>[^/]+)/(?P<repo>sitemaps)/(?P<path>.+)$', req.path)
            if match:
                proj = match.group('proj')
                repo = 'local'
                zone = 'public'
                obj = 'sitemaps/' + match.group('path') # sitemaps/sitemap-metawikibeta-NS_0-0.xml.gz

        if match is None:
            match = re.match(r'^/(?P<proj>[^/]+)/(?P<repo>dumps)/(?P<path>.+)$', req.path)
            if match:
                proj = match.group('proj')
                repo = 'dumps'
                zone = 'backup'
                obj = match.group('path')

        if match is None:
            match = re.match(r'^/monitoring/(?P<what>.+)$', req.path)
            if match:
                what = match.group('what')
                if what == 'frontend':
                    headers = {'Content-Type': 'application/octet-stream'}
                    resp = swob.Response(headers=headers, body="OK\n")
                elif what == 'backend':
                    req.host = '127.0.0.1:%s' % self.bind_port
                    req.path_info = "/v1/%s/monitoring/backend" % self.account

                    app_iter = self._app_call(env)
                    status = self._get_status_int()
                    headers = self._response_headers

                    resp = swob.Response(status=status, headers=headers, app_iter=app_iter)
                else:
                    resp = swob.HTTPNotFound('Monitoring type not found "%s"' % (req.path))
                return resp(env, start_response)

        if match is None:
            match = re.match(r'^/(?P<path>[^/]+)?$', req.path)
            # /index.html /favicon.ico /robots.txt etc.
            # serve from a default "root" container
            if match:
                path = match.group('path')
                if not path:
                    path = 'index.html'

                req.host = '127.0.0.1:%s' % self.bind_port
                req.path_info = "/v1/%s/root/%s" % (self.account, path)

                app_iter = self._app_call(env)
                status = self._get_status_int()
                headers = self._response_headers

                resp = swob.Response(status=status, headers=headers, app_iter=app_iter)
                return resp(env, start_response)

        # Internally rewrite the URL based on the regex it matched...
        if match:
            # Save a url with just the account name in it.
            req.path_info = "/v1/%s" % (self.account)
            port = self.bind_port
            req.host = '127.0.0.1:%s' % port
            url = req.url[:]
            # Create a path to our object's name.
            # Make the correct unicode string we want
            if zone:
                 container = "miraheze-%s-%s-%s" % (proj, repo, zone)
            else:
                 container = "miraheze-%s-%s" % (proj, repo)
            newpath = "/v1/%s/%s/%s" % (self.account, container,
                                        urllib.parse.unquote(obj,
                                                             errors='strict'))

            # Then encode to a byte sequence using utf-8
            req.path_info = newpath.encode('utf-8')
            # self.logger.warn("new path is %s" % req.path_info)

            # do_start_response just remembers what it got called with,
            # because our 404 handler will generate a different response.
            app_iter = self._app_call(env)
            status = self._get_status_int()
            headers = self._response_headers

            if status == 404:
                # only send thumbs to the 404 handler; just return a 404 for everything else.
                if repo == 'local' and zone == 'thumb':
                    resp = self.handle404(reqorig, url,  container, obj)
                    return resp(env, start_response)
                else:
                    resp = swob.HTTPNotFound('File not found: %s' % req.path)
                    return resp(env, start_response)
            else:
                # Return the response verbatim
                return swob.Response(status=status, headers=headers,
                                     app_iter=app_iter)(env, start_response)
        else:
            resp = swob.HTTPNotFound('Regexp failed to match URI: "%s"' % (req.path))
            return resp(env, start_response)


class WikiTideRewrite(object):

    def __init__(self, app, conf):
        self.app = app
        self.conf = conf
        self.logger = get_logger(conf)

    def __call__(self, env, start_response):
        # end-users should only do GET/HEAD
        if env['REQUEST_METHOD'] not in ('HEAD', 'GET'):
            return self.app(env, start_response)

        # do nothing on authenticated and authentication requests
        path = env['PATH_INFO']
        if path.startswith('/auth') or path.startswith('/v1/AUTH_'):
            return self.app(env, start_response)

        context = _WikiTideRewriteContext(self, self.conf)
        return context.handle_request(env, start_response)


def filter_factory(global_conf, **local_conf):
    conf = global_conf.copy()
    conf.update(local_conf)

    def wikitiderewrite_filter(app):
        return WikiTideRewrite(app, conf)

    return wikitiderewrite_filter

# vim: set expandtab tabstop=4 shiftwidth=4 autoindent:
