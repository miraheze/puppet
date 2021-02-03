# This is the VCL file for Varnish, adjusted for Miraheze's needs.
# It was mostly written by Southparkfan, with some stuff by Wikimedia.

# Credits go to Southparkfan and the contributors of Wikimedia's Varnish configuration.
# See their Puppet repo (https://github.com/wikimedia/operations-puppet)
# for the LICENSE.

# If you have any questions about the Varnish setup,
# please contact Southparkfan <southparkfan [at] miraheze [dot] org>.

# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.0 format.
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

backend mon1 {
	.host = "127.0.0.1";
	.port = "8201";
}

backend mw4 {
	.host = "127.0.0.1";
	.port = "8085";
	.probe = mwhealth;
}

backend mw5 {
	.host = "127.0.0.1";
	.port = "8086";
	.probe = mwhealth;
}

backend mw6 {
	.host = "127.0.0.1";
	.port = "8087";
	.probe = mwhealth;
}

backend mw7 {
	.host = "127.0.0.1";
	.port = "8088";
	.probe = mwhealth;
}

# to be used for acme/letsencrypt only
backend jobrunner1 {
	.host = "127.0.0.1";
	.port = "8089";
}

backend test2 {
	.host = "127.0.0.1";
	.port = "8091";
}

# test mediawiki backend with out health check
# to be used only by our miraheze debug plugin

backend mw4_test {
	.host = "127.0.0.1";
	.port = "8085";
}

backend mw5_test {
	.host = "127.0.0.1";
	.port = "8086";
}

backend mw6_test {
	.host = "127.0.0.1";
	.port = "8087";
}

backend mw7_test {
	.host = "127.0.0.1";
	.port = "8088";
}

# end test backend


sub vcl_init {
	new mediawiki = directors.round_robin();
	mediawiki.add_backend(mw4);
	mediawiki.add_backend(mw5);
	mediawiki.add_backend(mw6);
	mediawiki.add_backend(mw7);
}


acl purge {
	"localhost";
	"51.77.107.211"; # test2
	"2001:41d0:800:105a::3"; # test2
	"51.89.160.128"; # mw4
	"2001:41d0:800:1056::3"; # mw4
	"51.89.160.133"; # mw5
	"2001:41d0:800:1056::8"; # mw5
	"51.89.160.136"; # mw6
	"2001:41d0:800:105a::4"; # mw6
	"51.89.160.137"; # mw7
	"2001:41d0:800:105a::5"; # mw7
	"51.89.160.138"; # mon1
	"2001:41d0:800:105a::6"; # mon1
	"51.89.160.135"; # jobrunner1
	"2001:41d0:800:1056::10"; # jobrunner1
	"51.195.135.132"; # jobrunner2
	"2001:41d0:800:105a::13"; # jobrunner2
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
		&& req.url !~ "^/.*wiki/(thumb/)?[0-9a-f]/[0-9a-f]{1,2}/.*\.(png|jpe?g|svg)$"
		&& req.url !~ "^/w/resources/assets/.*\.png$"
		&& req.url !~ "^/(wiki/?)?$"
	) {
		# To prevent issues, we do not want vcl_backend_fetch to add ?useformat=mobile
		# when the user directly contacts the backend. The backend will directly listen to the cookies
		# the user sets anyway, the hack in vcl_backend_fetch is only for users that are not logged in.
		set req.http.X-Use-Mobile = "0";
		return (pass);
	} else {
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
	# Allow higher limits for static.mh.o, we can handle more of those requests
	if (req.http.Host == "static.miraheze.org" || req.http.Host == "static-new.miraheze.org") {
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

	# HACK for T217669
	if (req.url ~ "/wiki/undefined/api.php") {
		set req.url = regsuball(req.url, "/wiki/undefined/api.php", "/w/api.php");
	} else if (req.url ~ "/w/undefined/api.php") {
		set req.url = regsuball(req.url, "/w/undefined/api.php", "/w/api.php");
	}

	if (req.url ~ "^/\.well-known") {
		set req.backend_hint = jobrunner1;
		return (pass);
	} else if (req.http.X-Miraheze-Debug == "mw4.miraheze.org") {
		set req.backend_hint = mw4_test;
		return (pass);
	} else if (req.http.X-Miraheze-Debug == "mw5.miraheze.org") {
		set req.backend_hint = mw5_test;
		return (pass);
	} else if (req.http.X-Miraheze-Debug == "mw6.miraheze.org") {
		set req.backend_hint = mw6_test;
		return (pass);
	} else if (req.http.X-Miraheze-Debug == "mw7.miraheze.org") {
		set req.backend_hint = mw7_test;
		return (pass);
	} else if (req.http.X-Miraheze-Debug == "test2.miraheze.org") {
		set req.backend_hint = test2;
		return (pass);
	} else {
		set req.backend_hint = mediawiki.backend();
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

	# Don't cache dumps, and such
	if (req.http.Host == "static.miraheze.org" && (req.url !~ "^/.*wiki" || req.url ~ "^/(.+)wiki/sitemaps" || req.url ~ "^/.*wiki/dumps") ||
		req.http.Host == "static-new.miraheze.org" && (req.url !~ "^/.*wiki" || req.url ~ "^/(.+)wiki/sitemaps" || req.url ~ "^/.*wiki/dumps")) {
		return (pass);
	}

	if ( req.url ~ "^/sitemaps/(.+)wiki/sitemaps") {
		return (pass);
	}

	# We can rewrite those to one domain name to increase cache hits!
	if (req.url ~ "^/w/resources") {
		set req.http.Host = "meta.miraheze.org";
	}

	# Do not cache rest.php (Parsoid new entry point)
	if (req.url ~ "^/w/rest.php") {
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
	
	# Temporary solution to fix CookieWarning issue with ElectronPDF
	if (req.http.X-Real-IP == "51.89.160.132" || req.http.X-Real-IP == "2001:41d0:800:1056::7" ||
		req.http.X-Real-IP == "51.89.160.141" || req.http.X-Real-IP == "2001:41d0:800:105a::9") {
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
		set req.backend_hint = mon1;

		# Yes, we only care about this file
		if (req.url ~ "^/piwik.js" || req.url ~ "^/matomo.js") {
			return (hash);
		} else {
			return (pass);
		}
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
	if ((bereq.url ~ "^/wiki/[^$]" || bereq.url ~ "^/w/index.php\?title=[^$]") && bereq.http.X-Device == "phone-tablet" && bereq.http.X-Use-Mobile == "1") {
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
	if (req.url ~ "(?i)\.(gif|jpg|jpeg|pdf|png|css|js|json|woff|woff2|svg|eot|ttf|otf|ico|sfnt)$") {
		set resp.http.Access-Control-Allow-Origin = "*";
	}

	# HACK for T217669
	if (req.url ~ "/w/api.php") {
		set resp.http.Access-Control-Allow-Origin = "*";
	}

	if (req.url ~ "^/wiki/" || req.url ~ "^/w/index\.php") {
		if (req.url !~ "^/wiki/Special\:Banner") {
			set resp.http.Cache-Control = "private, s-maxage=0, maxage=0, must-revalidate";
		}
	}

	if (obj.hits > 0) {
		set resp.http.X-Cache = "<%= scope.lookupvar('::hostname') %> HIT (" + obj.hits + ")";
	} else {
		set resp.http.X-Cache = "<%= scope.lookupvar('::hostname') %> MISS (0)";
	}

	set resp.http.Content-Security-Policy = "default-src 'self' blob: data: <%- @csp_whitelist.each_pair do |config, value| -%> <%= value %> <%- end -%> 'unsafe-inline' 'unsafe-eval'; frame-ancestors 'self' <%- @frame_whitelist.each_pair do |config, value| -%> <%= value %> <%- end -%>";
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
			<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.0/css/bootstrap.min.css">
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
