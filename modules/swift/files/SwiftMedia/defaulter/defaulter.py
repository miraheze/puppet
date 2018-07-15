# Copyright 2015-2016 Tim Burke
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""
Middleware to set default headers for PUT requests.

End Users  / Application Developers
===================================

With this middleware enabled, users can set X-Default-Object-* headers on
accounts and containers to automatically set default headers for subsequent
object PUTs, or X-Default-Container-* headers on accounts to set defaults for
subsequent container PUTs. If a default is specified at multiple levels (for
example, an object default is specified both at the account and container),
the more-specific level's default is used. For example, in the sequence::

   POST /v1/acct
   X-Default-Object-X-Delete-After: 2592000

   POST /v1/acct/foo
   X-Default-Object-X-Delete-After: 86400

   PUT /v1/acct/foo/o1

   PUT /v1/acct/foo/o2
   X-Delete-After: 3600

   PUT /v1/acct/bar/o3

   PUT /v1/acct/baz/o4

   POST /v1/acct/baz/o4
   X-Remove-Delete-At: 1

   PUT /v1/other_acct/quux/o5

 * ``acct/foo/o1`` will get its ``X-Delete-After`` header from the container
   default, so it will be automatically be deleted after 24 hours.

 * ``acct/foo/o2`` had its ``X-Delete-After`` header explicitly set by the
   client, so it will be automatically be deleted after one hour.

 * ``acct/bar/o3`` will get its ``X-Delete-After`` header from the account
   default, so it will be deleted after 30 days.

 * ``acct/baz/04`` will initially be set to delete after 30 days as well.
   However, nothing prevents you from later changing or removing the defaulted
   header. After the subsequent ``POST``, the object will not be automatically
   deleted.

 * ``other_acct/quux/o5`` will not be automatically deleted, as neither its
   account nor its container specified a default expiration time.

.. note::

   You may not specify defaults for any X-*-Sysmeta-* or X-Backend-* headers.
   This is comparable to the behavior of the gatekeeper middleware.

Cluster Operators
=================

Requires Swift >= 1.12.0

Pipeline Placement
------------------

This middleware should be placed as far left as possible while still being
right of Swift's sane-WSGI-environment middlewares. Immediately right of
``cache`` should be reasonable.

Configuration Options
---------------------

use_formatting
   If true, expose {account}, {container}, and {object} formatting
   variables. This can be useful for things like setting::

      X-Default-Container-X-Versions-Location: .{container}_versions

   Default: False

default-account-*
default-container-*
default-object-*
   Used to set defaults across the entire cluster. These have lower precedence
   than account-level defaults.

Middleware Developers
=====================

This middleware adds two keys to the request environment:

swift.defaulter_headers
   This is a comma-delimited list of the headers for which this middleware has
   set default values. Note that other middlewares may have modified some or
   all of these after the defaults were set.

swift.defaulter_hook
   This is a callback that may be used to populate defaults for subrequests.
   It will only modify PUT requests. It accepts a swob.Request as an argument.
"""
from swift.common.request_helpers import get_sys_meta_prefix
from swift.common.swob import wsgify
from swift.common.utils import config_true_value
from swift.common.utils import register_swift_info
from swift.proxy.controllers.base import get_account_info
from swift.proxy.controllers.base import get_container_info


BLACKLIST = set('x-timestamp')
BLACKLIST_PREFIXES = (
    get_sys_meta_prefix('account'),
    get_sys_meta_prefix('container'),
    get_sys_meta_prefix('object'),
    'x-backend-',
)
CALLBACK_ENV_KEY = 'swift.defaulter_hook'
HEADERS_ENV_KEY = 'swift.defaulter_headers'


class DefaulterMiddleware(object):
    def __init__(self, app, config):
        self.app = app
        self.conf = config

    @wsgify
    def __call__(self, req):
        req.environ[CALLBACK_ENV_KEY] = self.defaulter_hook
        req.environ['swift.copy_hook'] = self.copy_hook(req.environ.get(
            'swift.copy_hook', lambda src_req, src_resp, sink_req: src_resp))

        try:
            vers, acct, cont, obj = req.split_path(2, 4, True)
        except ValueError:
            # /info request, or something similar
            return self.app

        handler = getattr(self, 'do_%s' % req.method.lower(), None)
        if not callable(handler):
            handler = self.get_response_and_translate

        if obj is not None:
            req_type = 'object'
        elif cont is not None:
            req_type = 'container'
        elif acct is not None:
            req_type = 'account'

        return handler(req, req_type)

    def client_to_sysmeta(self, req, req_type):
        subresources = {
            'account': ('container', 'object'),
            'container': ('object', ),
        }.get(req_type, ())

        header_formats = (
            ('x-remove-default-%s-', True),
            ('x-default-%s-', False),
        )
        for header_format, clear in header_formats:
            for header, value in req.headers.items():
                for subresource in subresources:
                    prefix = header_format % subresource
                    if header.lower().startswith(prefix):
                        header_to_default = header[len(prefix):].lower()
                        if header_to_default.startswith(BLACKLIST_PREFIXES):
                            continue
                        if header_to_default in BLACKLIST:
                            continue
                        sysmeta_header = '%sdefault-%s-%s' % (
                            get_sys_meta_prefix(req_type),
                            subresource,
                            header_to_default)
                        req.headers[sysmeta_header] = '' if clear else value

    def sysmeta_to_client(self, resp, req_type):
        prefix = get_sys_meta_prefix(req_type) + 'default-'
        for header, value in resp.headers.items():
            if header.lower().startswith(prefix):
                client_header = 'x-default-%s' % header[len(prefix):]
                resp.headers[client_header] = value

    def get_response_and_translate(self, req, req_type):
        resp = req.get_response(self.app)
        self.sysmeta_to_client(resp, req_type)
        return resp

    def do_post(self, req, req_type):
        if req_type == 'object':
            return self.get_response_and_translate(req, req_type)
        self.client_to_sysmeta(req, req_type)
        return self.get_response_and_translate(req, req_type)

    def defaulter_hook(self, req):
        '''Callback so middlewares that make subrequests can populate defaults.

        :param req: the swob.Request that should have its headers defaulted
        '''
        if HEADERS_ENV_KEY in req.environ:
            return  # We've already tried setting defaults; pass

        if req.method != 'PUT':
            return  # Only set defaults during PUTs

        try:
            pieces = req.split_path(2, 4, True)
        except ValueError:
            return  # /info, or something? but it's a put... what?
        if pieces.pop(0) != 'v1':
            return  # Swift3 request, maybe? Doesn't look like Swift API

        # OK, we're reasonably assured that we're working with an account,
        # container or object request for which we should populate defaults.

        format_args = {}
        for val, val_type in zip(pieces, ('account', 'container', 'object')):
            if val is not None:
                format_args[val_type] = val
                req_type = val_type

        defaulted = []
        for header, value in self.get_defaults(
                req, req_type, format_args).items():
            if header not in req.headers:
                defaulted.append(header)
                req.headers[header] = value
        req.environ[HEADERS_ENV_KEY] = ','.join(defaulted)

        # Go ahead and translate to sysmeta; it allows users to set things like
        #    X-Default-Container-X-Default-Object-X-Object-Meta-Color: blue
        # on their account (if they really want to) and it will Just Work.
        self.client_to_sysmeta(req, req_type)

    def copy_hook(self, inner_hook):
        def outer_hook(src_req, src_resp, sink_req):
            src_resp = inner_hook(src_req, src_resp, sink_req)
            if 'swift.post_as_copy' not in src_req.environ:
                self.defaulter_hook(sink_req)
            return src_resp
        return outer_hook

    def do_put(self, req, req_type):
        self.defaulter_hook(req)
        # Once we've set the defaults, we just follow the POST flow
        return self.do_post(req, req_type)

    def get_defaults(self, req, req_type, format_args):
        acct_sysmeta = get_account_info(req.environ, self.app)['sysmeta']
        if req_type == 'object':
            cont_sysmeta = get_container_info(req.environ, self.app)['sysmeta']
        else:
            cont_sysmeta = {}

        defaults = {}
        prefix = 'default-%s-' % req_type
        for src in (self.conf, acct_sysmeta, cont_sysmeta):
            for key, value in src.items():
                if not key.lower().startswith(prefix):
                    continue
                header_to_default = key[len(prefix):].lower()
                if header_to_default.startswith(BLACKLIST_PREFIXES):
                    continue
                if header_to_default in BLACKLIST:
                    continue
                if self.conf['use_formatting']:
                    try:
                        value = value.format(**format_args)
                    except KeyError:
                        # This user may not have specified the default;
                        # don't fail because of someone else
                        pass
                defaults[header_to_default] = value
        return defaults


def filter_factory(global_conf, **local_conf):
    conf = global_conf.copy()
    conf.update(local_conf)
    conf['use_formatting'] = config_true_value(conf.get(
        'use_formatting', False))
    defaulting_prefixes = tuple('default-%s-' % typ
                                for typ in ('account', 'container', 'object'))
    conf_to_register = {
        k: v for k, v in conf.items()
        if k == 'use_formatting' or k.startswith(defaulting_prefixes)}
    register_swift_info('defaulter', **conf_to_register)

    def filt(app):
        return DefaulterMiddleware(app, conf)
    return filt
