# This is the VCL file for Varnish, adjusted for Miraheze's needs.
# It was mostly written by Southparkfan, with some stuff by Wikimedia.

# Credits go to Southparkfan and the contributors of Wikimedia's Varnish configuration.
# See their Puppet repo (https://github.com/wikimedia/puppet)
# for the LICENSE.

# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.1 format.
vcl 4.1;

import directors;
import std;
import vsthrottle;

probe mwhealth {
	.request = "GET /wiki/Main_Page HTTP/1.1"
		"Host: login.miraheze.org"
		"User-Agent: Varnish healthcheck"
		"Connection: close";
	# Check each 10s
	.interval = 10s;
	# May not take longer than 8s to load. Ideally this should be lowered, but sometimes latency to the NL servers could suck.
	.timeout = 30s;
	# At least 4 out of 5 checks must be successful
	# to mark the backend as healthy
	.window = 5;
	.threshold = 4;
	.expected_response = 200;
}

# MEDIAWIKI
backend mw101 {
	.host = "127.0.0.1";
	.port = "8094";
	.probe = mwhealth;
}

backend mw102 {
	.host = "127.0.0.1";
	.port = "8095";
	.probe = mwhealth;
}

backend mw111 {
	.host = "127.0.0.1";
	.port = "8096";
	.probe = mwhealth;
}

backend mw112 {
	.host = "127.0.0.1";
	.port = "8097";
	.probe = mwhealth;
}

backend mw121 {
	.host = "127.0.0.1";
	.port = "8098";
	.probe = mwhealth;
}

backend mw122 {
	.host = "127.0.0.1";
	.port = "8099";
	.probe = mwhealth;
}

# to be used for acme/letsencrypt only
backend mwtask111 {
	.host = "127.0.0.1";
	.port = "8100";
}

# test mediawiki backend with out health check
# to be used only by our miraheze debug plugin

backend mw101_test {
	.host = "127.0.0.1";
	.port = "8094";
}

backend mw102_test {
	.host = "127.0.0.1";
	.port = "8095";
}

backend mw111_test {
	.host = "127.0.0.1";
	.port = "8096";
}

backend mw112_test {
	.host = "127.0.0.1";
	.port = "8097";
}

backend mw121_test {
	.host = "127.0.0.1";
	.port = "8098";
}

backend mw122_test {
	.host = "127.0.0.1";
	.port = "8099";
}

backend test101 {
	.host = "127.0.0.1";
	.port = "8101";
}

# end test backend
# misc services

backend mon111 {
	.host = "127.0.0.1";
	.port = "8300";
}

backend phab121 {
	.host = "127.0.0.1";
	.port = "8301";
}

backend mail121 {
	.host = "127.0.0.1";
	.port = "8302";
}

sub vcl_init {
	new mediawiki = directors.random();
	mediawiki.add_backend(mw101, 100);
	mediawiki.add_backend(mw102, 100);
	mediawiki.add_backend(mw111, 100);
	mediawiki.add_backend(mw112, 100);
	mediawiki.add_backend(mw121, 100);
	mediawiki.add_backend(mw122, 100);
}


acl purge {
	"localhost";
	# mw101
	"2a10:6740::6:107";
	# mw102
	"2a10:6740::6:108";
	# mw111
	"2a10:6740::6:206";
	# mw112
	"2a10:6740::6:207";
	# mw121
	"2a10:6740::6:309";
	# mw122
	"2a10:6740::6:310";
	# mwtask111
	"2a10:6740::6:208";
	# test101
	"2a10:6740::6:109";
	# mon111
	"2a10:6740::6:205";
	# phab121
	"2a10:6740::6:311";
	# mail121
	"2a10:6740::6:307";
}

sub mw_stash_cookie {
	if (req.restarts == 0) {
		unset req.http.Cookie;
	}
}

sub mw_evaluate_cookie {
	if (req.http.Cookie ~ "([sS]ession|Token|mf_useformat|stopMobileRedirect)=" 
		&& req.url !~ "^/w/load\.php"
		# FIXME: Can this just be req.http.Host !~ "static.miraheze.org"?
		&& req.url !~ "^/.*wiki/(thumb/)?[0-9a-f]/[0-9a-f]{1,2}/.*\.(gif|jpe?g|png|css|js|json|woff|woff2|svg|eot|ttf|ico)$"
		&& req.url !~ "^/w/(skins|resources|extensions)/.*\.(gif|jpe?g|png|css|js|json|woff|woff2|svg|eot|ttf|ico)(\?[0-9a-z]+\=?)?$"
		&& req.url !~ "^/(wiki/?)?$"
	) {
		# To prevent issues, we do not want vcl_backend_fetch to add ?useformat=mobile
		# when the user directly contacts the backend. The backend will directly listen to the cookies
		# the user sets anyway, the hack in vcl_backend_fetch is only for users that are not logged in.
		set req.http.X-Use-Mobile = "0";
		return (pass);
	} else {
		# These resources can be cached regardless of cookie value, remove cookie
		# to avoid passing requests to the backend.
		call mw_stash_cookie;
	}
}

sub mw_identify_device {
	# Used in vcl_backend_fetch and vcl_hash
	set req.http.X-Device = "desktop";
	
	# If the User-Agent matches the regex (this is the official regex used in MobileFrontend for automatic device detection), 
	# and the cookie does NOT explicitly state the user does not want the mobile version, we
	# set X-Device to phone-tablet. This will make vcl_backend_fetch add ?useformat=mobile to the URL sent to the backend.
	if (req.http.User-Agent ~ "(?i)(mobi|240x240|240x320|320x320|alcatel|android|audiovox|bada|benq|blackberry|cdm-|compal-|docomo|ericsson|hiptop|htc[-_]|huawei|ipod|kddi-|kindle|meego|midp|mitsu|mmp\/|mot-|motor|ngm_|nintendo|opera.m|palm|panasonic|philips|phone|playstation|portalmmm|sagem-|samsung|sanyo|sec-|semc-browser|sendo|sharp|silk|softbank|symbian|teleca|up.browser|vodafone|webos)" && req.http.Cookie !~ "(stopMobileRedirect=true|mf_useformat=desktop)") {
		set req.http.X-Device = "phone-tablet";

		# In vcl_fetch we'll decide in which situations we should actually do something with this.
		set req.http.X-Use-Mobile = "1";
	}
}

sub mw_rate_limit {
	if (req.http.User-Agent ~ "http://mj12bot.com/") {
		if (vsthrottle.is_denied(req.http.User-Agent, 1, 10s)) {
			return (synth(429, "Bot Rate Limit Exceeded - Contact sre[at]miraheze[dot]org"));
		}
	}
	# Allow higher limits for static.mh.o, we can handle more of those requests
	if (req.http.Host == "static.miraheze.org") {
		if (vsthrottle.is_denied("static:" + req.http.X-Real-IP, 500, 1s)) {
			return (synth(429, "Varnish Rate Limit Exceeded"));
		}
	} else {
		# Do not limit /w/load.php, /w/resources, /favicon.ico, etc
		# T6283: remove rate limit for IABot (temporarily?)
		if (
			(req.url ~ "^/wiki" || req.url ~ "^/w/(api|index)\.php")
			&& (req.http.X-Real-IP != "185.15.56.22" && req.http.User-Agent !~ "^IABot/2")
		) {
			# Stopgap for Googlebot sending suspicious requests with inpval parameter
			if (
				req.http.User-Agent ~ "(?i)Googlebot"
				&& req.url ~ "inpval"
			) {
				return (synth(403, "Forbidden"));
			}

			if (req.url ~ "^/w/index\.php\?title=\S+\:MathShowImage&hash=[0-9a-z]+&mode=mathml") {
				# The Math extension at Special:MathShowImage may cause lots of requests, which should not fail
				if (vsthrottle.is_denied("math:" + req.http.X-Real-IP, 120, 10s)) {
					return (synth(429, "Varnish Rate Limit Exceeded"));
				}
			} else {
				# Fallback
				if (vsthrottle.is_denied("mwrtl:" + req.http.X-Real-IP, 12, 2s)) {
					return (synth(429, "Varnish Rate Limit Exceeded"));
				}
			}
		}
	}
}

sub vcl_synth {
	if (resp.status == 752) {
		set resp.http.Location = resp.reason;
		set resp.status = 302;
		return (deliver);
	}

	if (resp.reason == "T217669") {
		set resp.reason = "OK";
		set resp.http.Access-Control-Allow-Origin = "*";
		return (deliver);
	}

	// Handle CORS preflight requests
	if (
		req.http.Host == "static.miraheze.org" &&
		resp.reason == "CORS Preflight"
	) {
		set resp.reason = "OK";
		set resp.http.Connection = "keep-alive";
		set resp.http.Content-Length = "0";

		// allow Range requests, and avoid other CORS errors when debugging with X-Miraheze-Debug
		set resp.http.Access-Control-Allow-Origin = "*";
		set resp.http.Access-Control-Allow-Headers = "Range,X-Miraheze-Debug";
		set resp.http.Access-Control-Allow-Methods = "GET, HEAD, OPTIONS";
		set resp.http.Access-Control-Max-Age = "86400";
	}
}

sub recv_purge {
	if (req.method == "PURGE") {
		if (!client.ip ~ purge) {
			return (synth(405, "Denied."));
		} else {
			return (purge);
		}
	}
}

sub mw_vcl_recv {
	call mw_rate_limit;
	call mw_identify_device;

	// HACK for phabricator.wikimedia.org/T217669
	if (req.url ~ "/w(iki)?/undefined/api.php") {
		set req.url = regsuball(req.url, "/w(iki)?/undefined/api.php", "/w/api.php");
		set req.backend_hint = mediawiki.backend();

		return (synth(200, "T217669"));
	}

	if (
		req.url ~ "^/\.well-known" ||
		req.http.Host == "sslrequest.miraheze.org" ||
		req.http.X-Miraheze-Debug == "mwtask111.miraheze.org"
	) {
		set req.backend_hint = mwtask111;
		return (pass);
	} else if (req.http.X-Miraheze-Debug == "mw101.miraheze.org") {
		set req.backend_hint = mw101_test;
		return (pass);
	} else if (req.http.X-Miraheze-Debug == "mw102.miraheze.org") {
		set req.backend_hint = mw102_test;
		return (pass);
	} else if (req.http.X-Miraheze-Debug == "mw111.miraheze.org") {
		set req.backend_hint = mw111_test;
		return (pass);
	} else if (req.http.X-Miraheze-Debug == "mw112.miraheze.org") {
		set req.backend_hint = mw112_test;
		return (pass);
	} else if (req.http.X-Miraheze-Debug == "mw121.miraheze.org") {
		set req.backend_hint = mw121_test;
		return (pass);
	} else if (req.http.X-Miraheze-Debug == "mw122.miraheze.org") {
		set req.backend_hint = mw122_test;
		return (pass);
	} else if (req.http.X-Miraheze-Debug == "test101.miraheze.org") {
		set req.backend_hint = test101;
		return (pass);
	} else {
		set req.backend_hint = mediawiki.backend();
	}

	if (req.http.Host == "static.miraheze.org") {
		// CORS preflight requests
		if (req.method == "OPTIONS" && req.http.Origin) {
			return (synth(200, "CORS Preflight"));
		}
	}

	# We never want to cache non-GET/HEAD requests.
	if (req.method != "GET" && req.method != "HEAD") {
		# Zero reason to append ?useformat=true here.
		set req.http.X-Use-Mobile = "0";
		return (pass);
	}

	if (req.http.If-Modified-Since && req.http.Cookie ~ "LoggedOut") {
		unset req.http.If-Modified-Since;
	}

	# Hosted on local domain and redirects to static.miraheze.org
	if (req.url ~ "^/sitemaps") {
		return (pass);
	}

	# Don't cache dumps, and such
	if (req.http.Host == "static.miraheze.org" && (req.url !~ "^/.*wiki" || req.url ~ "^/(.+)wiki/sitemaps" || req.url ~ "^/.*wiki/dumps")) {
		return (pass);
	}

	# We can rewrite those to one domain name to increase cache hits!
	if (req.url ~ "^/w/(skins|resources|extensions)/" ) {
		set req.http.Host = "meta.miraheze.org";
	}

	# api & rest.php are not safe cached
	if (req.url ~ "^/w/(api|rest).php/.*" ) {
		return (pass);
	}

	if (req.http.Authorization ~ "OAuth") {
		return (pass);
	}

	if (req.url ~ "^/healthcheck$") {
		set req.http.Host = "login.miraheze.org";
		set req.url = "/wiki/Main_Page";
		return (pass);
	}

	call mw_evaluate_cookie;
}

sub vcl_recv {
	call recv_purge;

	unset req.http.Proxy; # https://httpoxy.org/; CVE-2016-5385

	# Normalize Accept-Encoding for better cache hit ratio
	if (req.http.Accept-Encoding) {
		if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
			# No point in compressing these
			unset req.http.Accept-Encoding;
		} elsif (req.http.Accept-Encoding ~ "gzip") {
			set req.http.Accept-Encoding = "gzip";
		} elsif (req.http.Accept-Encoding ~ "deflate") {
			set req.http.Accept-Encoding = "deflate";
		} else {
			# We don't understand this
			unset req.http.Accept-Encoding;
		}
	}

	if (req.http.Host == "matomo.miraheze.org") {
		set req.backend_hint = mon111;

		# Yes, we only care about this file
		if (req.url ~ "^/piwik.js" || req.url ~ "^/matomo.js") {
			return (hash);
		} else {
			return (pass);
		}
	}

	if (req.http.Host == "icinga.miraheze.org" || req.http.Host == "grafana.miraheze.org") {
		set req.backend_hint = mon111;

		# Do not cache these services
		return (pass);
	}

	if (req.http.Host == "phabricator.miraheze.org" || req.http.Host == "phab.miraheze.wiki" ||
            req.http.Host == "blog.miraheze.org") {
		set req.backend_hint = phab121;

		# Do not cache these services
		return (pass);
	}

	if (req.http.Host == "webmail.miraheze.org") {
		set req.backend_hint = mail121;

		# Do not cache these services
		return (pass);
	}

	# MediaWiki specific
	call mw_vcl_recv;

	return (hash);
}

sub vcl_hash {
	# FIXME: try if we can make this ^/wiki/ only?
	if (req.url ~ "^/wiki/" || req.url ~ "^/w/load.php") {
		hash_data(req.http.X-Device);
	}
}

sub vcl_backend_fetch {
	if ((bereq.url ~ "^/wiki/[^$]" || bereq.url ~ "^/w/index.php(.*)title=[^$]") && bereq.http.X-Device == "phone-tablet" && bereq.http.X-Use-Mobile == "1") {
		if (bereq.url ~ "\?") {
			set bereq.url = bereq.url + "&useformat=mobile";
		} else {
			set bereq.url = bereq.url + "?useformat=mobile";
		}
	}
}

sub vcl_backend_response {
	if (beresp.ttl <= 0s) {
		set beresp.ttl = 1800s;
		set beresp.uncacheable = true;
	}

	if (beresp.status >= 400) {
		set beresp.uncacheable = true;
	}

	if (beresp.http.Set-Cookie) {
		set beresp.uncacheable = true;
	}

	# Cache 301 redirects for 12h (/, /wiki, /wiki/ redirects only)
	if (beresp.status == 301 && bereq.url ~ "^/?(wiki/?)?$" && !beresp.http.Cache-Control ~ "no-cache") {
		set beresp.ttl = 43200s;
	}

	return (deliver);
}

sub vcl_deliver {
	# We set Access-Control-Allow-Origin to * for all files hosted on
	# static.miraheze.org. We also set this header for some images hosted
	# on the same site as the wiki (private).
	if (
		req.http.Host == "static.miraheze.org" ||
		req.url ~ "(?i)\.(gif|jpg|jpeg|pdf|png|css|js|json|woff|woff2|svg|eot|ttf|otf|ico|sfnt|stl|STL)$"
	) {
		set resp.http.Access-Control-Allow-Origin = "*";
	}

	if (req.url ~ "^/wiki/" || req.url ~ "^/w/index\.php") {
		// ...but exempt CentralNotice banner special pages
		if (req.url !~ "^/(wiki/|w/index\.php\?title=)Special:Banner") {
			set resp.http.Cache-Control = "private, s-maxage=0, max-age=0, must-revalidate";
		}
	}

	if (req.url ~ "^/w/load\.php" ) {
		set resp.http.Age = 0;
	}

	if (req.url ~ "^(/w/(api|index|rest)\.php*|/wiki/Special(\:|%3A)(?!WikiForum)).+$") {
		set resp.http.X-Robots-Tag = "noindex";
	}

	if (obj.hits > 0) {
		set resp.http.X-Cache = "<%= scope.lookupvar('::hostname') %> HIT (" + obj.hits + ")";
	} else {
		set resp.http.X-Cache = "<%= scope.lookupvar('::hostname') %> MISS (0)";
	}

	// *** HTTPS deliver code - disable Google ad targeting (FLoC)
	// See https://github.com/wicg/floc#opting-out-of-computation
	set resp.http.Permissions-Policy = "interest-cohort=()";

	set resp.http.Content-Security-Policy = "<%- @csp_whitelist.each_pair do |type, value| -%> <%= type %> <%= value.join(' ') %>; <%- end -%>";

	return (deliver);
}

sub vcl_backend_error {
	set beresp.http.Content-Type = "text/html; charset=utf-8";

	synthetic( {"<!DOCTYPE html>
	<html lang="en">
		<head>
			<meta charset="utf-8">
			<meta name="viewport" content="width=device-width, initial-scale=1.0">
			<meta name="description" content="Backend Fetch Failed">
			<title>"} + beresp.status + " " + beresp.reason + {"</title>
			<!-- Bootstrap core CSS -->
			<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@4.6.0/dist/css/bootstrap.min.css">
			<style>
				/* Error Page Inline Styles */
				body {
					padding-top: 20px;
				}
				/* Layout */
				.jumbotron {
					font-size: 21px;
					font-weight: 200;
					line-height: 2.1428571435;
					color: inherit;
					padding: 10px 0px;
				}
				/* Everything but the jumbotron gets side spacing for mobile-first views */
				.masthead, .body-content {
					padding-left: 15px;
					padding-right: 15px;
				}
				/* Main marketing message and sign up button */
				.jumbotron {
					text-align: center;
					background-color: transparent;
				}
				.jumbotron .btn {
					font-size: 21px;
					padding: 14px 24px;
				}
				/* Colors */
				.green {color:#5cb85c;}
				.orange {color:#f0ad4e;}
				.red {color:#d9534f;}
			</style>
			<script>
				function loadDomain() {
					var display = document.getElementById("display-domain");
					display.innerHTML = document.domain;
				}
			</script>
		</head>
		<div class="container">
			<!-- Jumbotron -->
			<div class="jumbotron">
				<h1><img src="https://upload.wikimedia.org/wikipedia/commons/b/b7/Miraheze-Logo.svg" alt="Miraheze Logo"> "} + beresp.status + " " + beresp.reason + {"</h1>
				<p class="lead">Our servers are having issues at the moment.</p>
				<a href="javascript:document.location.reload(true);" class="btn btn-lg btn-outline-success" role="button">Try this page again</a>
			</div>
		</div>
		<div class="container">
			<div class="body-content">
				<div class="row">
					<div class="col-md-6">
						<h2>What can I do?</h2>
						<p class="lead">If you're a wiki visitor or owner</p>
						<p>Try again in a few minutes. If the problem persists, please report this on <a href="https://phabricator.miraheze.org">phabricator.</a> We apologize for the inconvenience. Our sysadmins should be attempting to solve the issue ASAP!</p>
					</div>
					<div class="col-md-6">
						<a class="twitter-timeline" data-width="500" data-height="350" text-align: center href="https://twitter.com/miraheze?ref_src=twsrc%5Etfw">Tweets by miraheze</a> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
					</div>
				</div>
			</div>
		</div>

		<div class="footer">
			<div class="text-center">
				<p class="lead">When reporting this, please be sure to provide the information below.</p>

				Error "} + beresp.status + " " + beresp.reason + {", forwarded for "} + bereq.http.X-Forwarded-For + {" <br />
				(Varnish XID "} + bereq.xid + {") via "} + server.identity + {" at "} + now + {".
				<br /><br />
			</div>
		</div>
	</html>
	"} );

	return (deliver);
}
