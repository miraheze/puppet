# This is the VCL file for Varnish, adjusted for Miraheze's needs.
# It was originally written by Southparkfan in 2015, but rewritten in 2022 by John.
# Some material used is inspired by the Wikimedia Foundation's configuration files.
# Their material and license is available at https://github.com/wikimedia/puppet

# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.1 format.
vcl 4.1;

# Import some modules used
import directors;
import std;
import vsthrottle;

# MediaWiki configuration
probe mwhealth {
	.request = "GET /check HTTP/1.1"
		"Host: health.miraheze.org"
		"User-Agent: Varnish healthcheck"
		"Connection: close";
	# Check each <%= @interval_check %>
	.interval = <%= @interval_check %>;
	# <%= @interval_timeout %> should be our upper limit for responding to a fair light web request
	.timeout = <%= @interval_timeout %>;
	# At least 4 out of 5 checks must be successful
	# to mark the backend as healthy
	.window = 5;
	.threshold = 4;
	.expected_response = 204;
}

<%- @backends.each_pair do | name, property | -%>
backend <%= name %> {
	.host = "127.0.0.1";
	.port = "<%= property['port'] %>";
<%- if property['probe'] -%>
	.probe = <%= property['probe'] %>;
<%- end -%>
}
<%- end -%>

# Initialise vcl
sub vcl_init {
	new mediawiki = directors.random();
<%- @backends.each_pair do | name, property | -%>
<%- if property['pool'] -%>
	mediawiki.add_backend(<%= name %>, 1);
<%- end -%>
<%- end -%>
}

# Purge ACL
acl purge {
	"localhost";
	# IPv6
	"2a10:6740::6/64";
	# IPv4
	"31.24.105.128/28";
}

# Cookie handling logic
sub evaluate_cookie {
	# Replace all session/token values with a non-unique global value for caching purposes.
	if (req.restarts == 0) {
		unset req.http.X-Orig-Cookie;
		if (req.http.Cookie) {
			set req.http.X-Orig-Cookie = req.http.Cookie;
			if (req.http.Cookie ~ "([Ss]ession|Token)=") {
				set req.http.Cookie = "Token=1";
			} else {
				unset req.http.Cookie;
			}
		}
	}
}

# Mobile detection logic
sub mobile_detection {
	# If the User-Agent matches the regex (this is the official regex used in MobileFrontend for automatic device detection), 
	# and the cookie does NOT explicitly state the user does not want the mobile version, we
	# set X-Device to phone-tablet. This will make vcl_backend_fetch add ?useformat=mobile to the URL sent to the backend.
	if (req.http.User-Agent ~ "(?i)(mobi|240x240|240x320|320x320|alcatel|android|audiovox|bada|benq|blackberry|cdm-|compal-|docomo|ericsson|hiptop|htc[-_]|huawei|ipod|kddi-|kindle|meego|midp|mitsu|mmp\/|mot-|motor|ngm_|nintendo|opera.m|palm|panasonic|philips|phone|playstation|portalmmm|sagem-|samsung|sanyo|sec-|semc-browser|sendo|sharp|silk|softbank|symbian|teleca|up.browser|vodafone|webos)" && req.http.Cookie !~ "(stopMobileRedirect=true|mf_useformat=desktop)") {
		set req.http.X-Device = "phone-tablet";

		# In vcl_backend_fetch we'll decide in which situations we should actually do something with this.
		set req.http.X-Use-Mobile = "1";
	} else {
		set req.http.X-Device = "desktop";
	}
}

# Rate limiting logic
sub rate_limit {
	# Allow higher limits for static.miraheze.org, we can handle more of those requests
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

# Artificial error handling/redirects within Varnish
sub vcl_synth {
	if (resp.status == 752) {
		set resp.http.Location = resp.reason;
		set resp.status = 302;
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

# Purge Handling
sub recv_purge {
	if (req.method == "PURGE") {
		if (!client.ip ~ purge) {
			return (synth(405, "Denied."));
		} else {
			return (purge);
		}
	}
}

# Main MediaWiki Request Handling
sub mw_request {
	call rate_limit;
	call mobile_detection;
	
	# Assigning a backend
<%- @backends.each_pair do | name, property | -%>
	if (req.http.X-Miraheze-Debug == "<%= name %>.miraheze.org") {
		set req.backend_hint = <%= name %>;
		return (pass);
	}
<%- end -%>

	set req.backend_hint = mediawiki.backend();

	# Rewrite hostname to static.miraheze.org for caching
	if (req.url ~ "^/static/") {
		set req.http.Host = "static.miraheze.org";
	}

	# Numerous static.miraheze.org specific code
	if (req.http.Host == "static.miraheze.org") {
		# We can do this because static.miraheze.org should not be capable of serving such requests anyway
		# This could also increase cache hit rates as Cookies will be stripped entirely
		unset req.http.Cookie;
		unset req.http.Authorization;

		# Normalise thumb URLs to prevent capitalisation or odd casing duplicating numerous resources
		# set req.url = regsub(req.url, "^(.+/)[^/]+$", "\1") + std.tolower(regsub(req.url, "^.+/([^/]+)$", "\1"));

		# CORS Prelight
		if (req.method == "OPTIONS" && req.http.Origin) {
			return (synth(200, "CORS Preflight"));
		}
	}

	# Don't cache a non-GET or HEAD request
	if (req.method != "GET" && req.method != "HEAD") {
		# Zero reason to append ?useformat=true here
		set req.http.X-Use-Mobile = "0";
		return (pass);
	}

	# If a user is logged out, do not give them a cached page of them logged in
	if (req.http.If-Modified-Since && req.http.Cookie ~ "LoggedOut") {
		unset req.http.If-Modified-Since;
	}

	# Don't cache certain things on static
	if (
		req.http.Host == "static.miraheze.org" &&
		(
			req.url !~ "^/.*wiki" || # If it isn't a wiki folder, don't cache it
			req.url ~ "^/(.+)wiki/sitemaps" || # Do not cache sitemaps
			req.url ~ "^/.*wiki/dumps" # Do not cache wiki dumps
		)
	) {
		return (pass);
	}

	# We can rewrite those to one domain name to increase cache hits
	if (req.url ~ "^/w/(skins|resources|extensions)/" ) {
		set req.http.Host = "meta.miraheze.org";
	}

	# api & rest.php are not safe when cached
	if (req.url ~ "^/w/(api|rest).php/.*" ) {
		return (pass);
	}

	# A requet via OAuth should not be cached or use a cached response elsewhere
	if (req.http.Authorization ~ "OAuth") {
		return (pass);
	}

	call evaluate_cookie;
}

# Initial sub route executed on a Varnish request, the heart of everything
sub vcl_recv {
	call recv_purge; # Check purge

	unset req.http.Proxy; # https://httpoxy.org/

	# Health checks, do not send request any further, if we're up, we can handle it
	if (req.http.Host == "health.miraheze.org" && req.url == "/check") {
		return (synth(200));
	}

	# Normalise Accept-Encoding for better cache hit ratio
	if (req.http.Accept-Encoding) {
		if (
			req.http.Host == "static.miraheze.org"
			&& req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|mp4|ogg)$"
		) {
			# No point in compressing these
			unset req.http.Accept-Encoding;
		} elseif (req.http.Accept-Encoding ~ "gzip") {
			set req.http.Accept-Encoding = "gzip";
		} elseif (req.http.Accept-Encoding ~ "deflate") {
			set req.http.Accept-Encoding = "deflate";
		} else {
			# We don't understand this
			unset req.http.Accept-Encoding;
		}
	}

	if (
		req.url ~ "^/\.well-known" ||
		req.http.Host == "ssl.miraheze.org" ||
		req.http.Host == "acme.miraheze.org"
	) {
		set req.backend_hint = puppet141;
		return (pass);
	}

        if (req.http.Host ~ "^(.*\.)?betaheze\.org") {
                set req.backend_hint = test131;
                return (pass);
        }

	# Only cache js files from Matomo
	if (req.http.Host == "matomo.miraheze.org") {
		set req.backend_hint = matomo131;

		# Yes, we only care about this file
		if (req.url ~ "^/piwik.js" || req.url ~ "^/matomo.js") {
			return (hash);
		} else {
			return (pass);
		}
	}

	# Do not cache requests from this domain
	if (req.http.Host == "icinga.miraheze.org" || req.http.Host == "grafana.miraheze.org") {
		set req.backend_hint = mon141;

		return (pass);
	}

	# Do not cache requests from this domain
	if (req.http.Host == "phabricator.miraheze.org" || req.http.Host == "phab.miraheze.wiki" ||
            req.http.Host == "blog.miraheze.org") {
		set req.backend_hint = phab121;
		return (pass);
	}

	# Do not cache requests from this domain
	if (req.http.Host == "webmail.miraheze.org") {
		set req.backend_hint = mail121;
		return (pass);
	}

	# Do not cache requests from this domain
	if (req.http.Host == "reports.miraheze.org") {
		set req.backend_hint = reports121;
		return (pass);
	}

	# MediaWiki specific
	call mw_request;

	return (hash);
}

# Defines the uniqueness of a request
sub vcl_hash {
	# FIXME: try if we can make this ^/wiki/ only?
	if (req.url ~ "^/wiki/" || req.url ~ "^/w/load.php") {
		hash_data(req.http.X-Device);
	}
}

# Initiate a backend fetch
sub vcl_backend_fetch {
	# Modify the end of the URL if mobile device
	if ((bereq.url ~ "^/wiki/[^$]" || bereq.url ~ "^/w/index.php(.*)title=[^$]") && bereq.http.X-Device == "phone-tablet" && bereq.http.X-Use-Mobile == "1") {
		if (bereq.url ~ "\?") {
			set bereq.url = bereq.url + "&useformat=mobile";
		} else {
			set bereq.url = bereq.url + "?useformat=mobile";
		}
	}
	
	# Restore original cookies
	if (bereq.http.X-Orig-Cookie) {
		set bereq.http.Cookie = bereq.http.X-Orig-Cookie;
		unset bereq.http.X-Orig-Cookie;
	}
}

# Backend response, defines cacheability
sub vcl_backend_response {
	/* Don't cache private, no-cache, no-store objects. */
	if (beresp.http.Cache-Control ~ "(?i:private|no-cache|no-store)") {
		set beresp.ttl = 0s;
		// translated to hit-for-pass below
	}

	# Cookie magic as we did before
	if (bereq.http.Cookie ~ "([Ss]ession|Token)=") {
		set bereq.http.Cookie = "Token=1";
	} else {
		unset bereq.http.Cookie;
	}

	# Distribute caching re-calls where possible
	if (beresp.ttl >= 60s) {
		set beresp.ttl = beresp.ttl * std.random( 0.95, 1.00 );
	}

	# Do not cache a backend response if HTTP code is above 400, except a 404, then limit TTL
	if (beresp.status >= 400 && beresp.status != 404) {
		set beresp.uncacheable = true;
	} elseif (beresp.status == 404 && beresp.ttl > 10m) {
		set beresp.ttl = 10m;
	}

	# If we have a cookie, we can't cache it, unless we can?
	# We can cache when cookies are stripped, and no other cookies are present
	if (
		bereq.http.Cookie == "Token=1"
		&& beresp.http.Vary ~ "(?i)(^|,)\s*Cookie\s*(,|$)"
	) {
		# We can cache when:
		# * Wiki is public; and
		# * action=raw
		if (
			beresp.http.X-Wiki-Visibility == "Public"
			&& bereq.url ~ "(&|\?)action=raw"
		) {
			unset bereq.http.Cookie;
			unset beresp.http.Set-Cookie;
		} else {
			return(pass(607s));
		}
	} elseif (beresp.http.Set-Cookie) {
		set beresp.uncacheable = true; # We do this just to be safe - but we should probably log this to eliminate it?
	}

	# Cache 301 redirects for 12h (/, /wiki, /wiki/ redirects only)
	if (beresp.status == 301 && bereq.url ~ "^/?(wiki/?)?$" && !beresp.http.Cache-Control ~ "no-cache") {
		set beresp.ttl = 43200s;
	}

	# Cache non-modified robots.txt for 12 hours, otherwise 5 minutes
	if (bereq.url == "/robots.txt") {
		if (beresp.http.X-Miraheze-Robots == "Custom") {
			set beresp.ttl = 300s;
		} else {
			set beresp.ttl = 43200s;
		}
	}

	// Compress compressible things if the backend didn't already, but
	// avoid explicitly-defined CL < 860 bytes.  We've seen varnish do
	// gzipping on CL:0 302 responses, resulting in output that has CE:gzip
	// and CL:20 and sends a pointless gzip header.
	// Very small content may actually inflate from gzipping, and
	// sub-one-packet content isn't saving a lot of latency for the gzip
	// costs (to the server and the client, who must also decompress it).
	// The magic 860 number comes from Akamai, Google recommends anywhere
	// from 150-1000.  See also:
	// https://webmasters.stackexchange.com/questions/31750/what-is-recommended-minimum-object-size-for-gzip-performance-benefits
	if (beresp.http.content-type ~ "json|text|html|script|xml|icon|ms-fontobject|ms-opentype|x-font|sla"
		&& (!beresp.http.Content-Length || std.integer(beresp.http.Content-Length, 0) >= 860)) {
			set beresp.do_gzip = true;
	}
	// SVGs served by MediaWiki are part of the interface. That makes them
	// very hot objects, as a result the compression time overhead is a
	// non-issue. Several of them tend to be requested at the same time,
	// as the browser finds out about them when parsing stylesheets that
	// contain multiple. This means that the "less than 1 packet" rationale
	// for not compressing very small objects doesn't apply either. Lastly,
	// since they're XML, they contain a fair amount of repetitive content
	// even when small, which means that gzipped SVGs tend to be
	// consistantly smaller than their uncompressed version, even when tiny.
	// For all these reasons, it makes sense to have a lower threshold for
	// SVG. Applying it to XML in general is a more unknown tradeoff, as it
	// would affect small API responses that are more likely to be cold
	// objects due to low traffic to specific API URLs.
	if (beresp.http.content-type ~ "svg" && (!beresp.http.Content-Length || std.integer(beresp.http.Content-Length, 0) >= 150)) {
		set beresp.do_gzip = true;
	}

	// set a 601s hit-for-pass object based on response conditions in vcl_backend_response:
	//    Calculated TTL <= 0 + Status < 500:
	//    These are generally uncacheable responses.  The 5xx exception
	//    avoids us accidentally replacing a good stale/grace object with
	//    an hfp (and then repeatedly passing on potentially-cacheable
	//    content) due to an isolated 5xx response.
	if (beresp.ttl <= 0s && beresp.status < 500) {
		set beresp.grace = 31s;
		set beresp.keep = 0s;
		return(pass(601s));
	}

	// hit-for-pass objects >= 8388608 size and if domain == static.miraheze.org or
	// hit-for-pass objects >= 67108864 size and if domain != static.miraheze.org.
	// Do cache if Content-Length is missing.
	if (std.integer(beresp.http.Content-Length, 0) >= 8388608 && bereq.http.Host == "static.miraheze.org" ||
		std.integer(beresp.http.Content-Length, 0) >= 67108864 && bereq.http.Host != "static.miraheze.org"
	) {
		// HFP
		return(pass(beresp.ttl));
	}

	return (deliver);
}

# Last sub route activated, clean up of HTTP headers etc.
sub vcl_deliver {
	# We set Access-Control-Allow-Origin to * for all files hosted on
	# static.miraheze.org. We also set this header for some images hosted
	# on the same site as the wiki (private).
	if (
		(
	 	 	 req.http.Host == "static.miraheze.org" &&
			 req.url ~ "(?i)\.(gif|jpg|jpeg|pdf|png|css|js|json|woff|woff2|svg|eot|ttf|otf|ico|sfnt|stl|STL)$"
		) ||
	 	req.url ~ "^(?i)\/w\/img_auth\.php\/(.*)\.(gif|jpg|jpeg|pdf|png|css|js|json|woff|woff2|svg|eot|ttf|otf|ico|sfnt|stl|STL)$"
	) {
		set resp.http.Access-Control-Allow-Origin = "*";
	}

	if (req.url ~ "^/wiki/" || req.url ~ "^/w/index\.php") {
		// ...but exempt CentralNotice banner special pages
		if (req.url !~ "^/(wiki/|w/index\.php\?title=)Special:Banner") {
			set resp.http.Cache-Control = "private, s-maxage=0, max-age=0, must-revalidate";
		}
	}

	# Client side caching for load.php
	if (req.url ~ "^/w/load\.php" ) {
		set resp.http.Age = 0;
	}

	# Do not index certain URLs
	if (req.url ~ "^(/w/(api|index|rest)\.php*|/wiki/Special(\:|%3A)(?!WikiForum)).+$") {
		set resp.http.X-Robots-Tag = "noindex";
	}

	# Disable Google ad targeting (FLoC)
	set resp.http.Permissions-Policy = "interest-cohort=()";

	# Content Security Policy
	set resp.http.Content-Security-Policy = "<%- @csp.each_pair do |type, value| -%> <%= type %> <%= value.join(' ') %>; <%- end -%>";

	# For a 500 error, do not set cookies
	if (resp.status >= 500 && resp.http.Set-Cookie) {
		unset resp.http.Set-Cookie;
	}

	# Set X-Cache from request
	set resp.http.X-Cache = req.http.X-Cache;

	# Identify uncacheable content
	if (obj.uncacheable) {
		set resp.http.X-Cache = resp.http.X-Cache + " UNCACHEABLE";
	}

	return (deliver);
}

# Hit code, default logic is appended
sub vcl_hit {
	# Add X-Cache header
	set req.http.X-Cache = "<%= scope.lookupvar( '::hostname' ) %> HIT (" + obj.hits + ")";

	# Is the request graced?
	if (obj.ttl <= 0s && obj.grace > 0s) {
		set req.http.X-Cache = req.http.X-Cache + " GRACE";
	}
}

# Miss code, default logic is appended
sub vcl_miss {
	# Add X-Cache header
	set req.http.X-Cache = "<%= scope.lookupvar( '::hostname' ) %> MISS";
}

# Pass code, default logic is appended
sub vcl_pass {
	# Add X-Cache header
	set req.http.X-Cache = "<%= scope.lookupvar( '::hostname' ) %> PASS";
}

# Synthetic code, default logic is appended
sub vcl_synth {
	# Add X-Cache header
	set req.http.X-Cache = "<%= scope.lookupvar( '::hostname' ) %> SYNTH";
}

# Backend response when an error occurs
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
						<p>Try again in a few minutes. If the problem persists, please report this on <a href="https://phabricator.miraheze.org">Phabricator</a>. If Phabricator is also down, you may join our <a href="https://discord.gg/TVAJTE4CUn">Discord server</a> or IRC (<a href="https://web.libera.chat/?channel=#miraheze-sre">#miraheze-sre</a>) for additional updates. We apologise for the inconvenience. Our system administrators should be attempting to resolve the issue ASAP!</p>
					</div>
					<div class="col-md-6">
						<a class="twitter-timeline" data-width="500" data-height="350" text-align: center href="https://twitter.com/miraheze?ref_src=twsrc%5Etfw">Tweets by Miraheze</a> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
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
