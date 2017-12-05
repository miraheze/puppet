# This is the VCL file for Varnish, adjusted for Miraheze's needs.
# It was mostly written by Southparkfan, with some stuff by Wikimedia.

# Credits go to Southparkfan and the contributors of Wikimedia's Varnish configuration.
# See their Puppet repo (https://github.com/wikimedia/operations-puppet)
# for the LICENSE.

# If you have any questions about the Varnish setup,
# please contact Southparkfan <southparkfan [at] miraheze [dot] org>.

# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.0 format.
vcl 4.0;

import directors;
import std;

probe mwhealth {
	.request = "GET /wiki/Miraheze HTTP/1.1"
		"Host: meta.miraheze.org"
		"User-Agent: Varnish healthcheck"
		"Connection: close";
	# Check each 10s
	.interval = 10s;
	# May not take longer than 8s to load. Ideally this should be lowered, but sometimes latency to the NL servers could suck.
	.timeout = 8s;
	# At least 4 out of 5 checks must be successful
	# to mark the backend as healthy
	.window = 5;
	.threshold = 4;
	.expected_response = 200;
}

probe mwtest {
	.request = "GET / HTTP/1.1"
		"Host: meta.miraheze.org"
		"User-Agent: Varnish healthcheck"
	"Connection: close";
	.interval = 5s;
	.timeout = 3s;
	.window = 5;
	.threshold = 4;
	.expected_response = 301;
}

backend mw1 {
	.host = "127.0.0.1";
	.port = "8080";
	.probe = mwhealth;
}

backend mw2 {
	.host = "127.0.0.1";
	.port = "8081";
	.probe = mwhealth;
}

backend mw3 {
	.host = "127.0.0.1";
	.port = "8082";
	.probe = mwhealth;
}

backend mw2test {
	.host = "185.52.2.113";
	.port = "80";
	.probe = mwtest;
}

sub vcl_init {
	new mediawiki = directors.round_robin();
	mediawiki.add_backend(mw1);
	mediawiki.add_backend(mw2);
	mediawiki.add_backend(mw3);
}


acl purge {
	"localhost";
	"185.52.1.75";
	"185.52.2.113";
	"81.4.121.113";
}

sub stash_cookie {
	if (req.restarts == 0) {
		unset req.http.Cookie;
	}
}

sub evaluate_cookie {
	if (req.http.Cookie ~ "([sS]ession|Token)=" 
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
		call stash_cookie;
	}
}

sub identify_device {
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

sub url_rewrite {
        if (req.http.Host == "meta.miraheze.org"
                && req.url ~ "^/Stewards'_noticeboard"
        ) {
                return (synth(752, "/wiki/Stewards'_noticeboard"));
        }
        
	if (req.http.Host == "meta.miraheze.org"
		&& req.url ~ "^/Requests_for_adoption"
	) {
		return (synth(752, "/wiki/Requests_for_adoption"));
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

sub vcl_recv {
	call recv_purge;
	call identify_device;
	call url_rewrite;

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

	if (req.http.X-Miraheze-Debug == "1" || req.url ~ "^/\.well-known") {
		set req.backend_hint = mw1;
		return (pass);
	} elsif (req.http.X-Miraheze-Debug == "2"
		|| req.url ~ "^/mw2nostunneltest$") {
		set req.backend_hint = mw2test;
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
	if (req.http.Host == "static.miraheze.org" && req.url !~ "^/.*wiki") {
		return (pass);
	}

	# We can rewrite those to one domain name to increase cache hits!
	if (req.url ~ "^/w/resources") {
		set req.http.Host = "meta.miraheze.org";
	}
 
	if (req.http.Authorization ~ "OAuth") {
		return (pass);
	}

	call evaluate_cookie;
	
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
		set beresp.ttl = 120s;
		set beresp.uncacheable = true;
	}

	if (beresp.status >= 400) {
		set beresp.uncacheable = true;
	}

	# Cache 301 redirects for 12h (/, /wiki, /wiki/ redirects only)
	if (beresp.status == 301 && bereq.url ~ "^/?(wiki/?)?$" && !beresp.http.Cache-Control ~ "no-cache") {
		set beresp.ttl = 43200s;
	}

	return (deliver);
}

sub vcl_deliver {
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
}

sub vcl_backend_error {
	set beresp.http.Content-Type = "text/html; charset=utf-8";
	
	synthetic( {"<!DOCTYPE html>
	<html>
		<head>
			<title>Error "} + beresp.status + " " + beresp.reason + {"</title>
			<style type="text/css">
				html, body {
					height: 100%;
					margin: 0;
					padding: 0;
					font-family: sans-serif;
				}
				html {
					font-size: 100%;
				}
				body {
					background-color: hsl(0, 0%, 96%);
				}
				h1, h2 {
					margin-bottom: .6em !important;
				}
				h1 {
					font-size: 188%;
				}
				h1, h2, h3, h4, h5, h6 {
					color: hsl(0, 0%, 0%);
					background: none;
					font-weight: normal;
					margin: 0;
					overflow: hidden;
					padding-top: .5em;
					padding-bottom: .17em;
					border-bottom: 1px solid hsl(0, 0%, 67%);
				}
				p {
					margin: .4em 0 .5em 0;
				}
				a {
					text-decoration: none;
					color: #0645ad;
				}
			</style>
		</head>
		<body>
			<div style="text-align: center;">
				<h1>"} + beresp.status + " " + beresp.reason + {"</h1>
				<p>Our servers are having problems at the moment. Please try again in a few minutes. There may be additional information on our <a href="https://twitter.com/miraheze">Twitter</a> and <a href="https://www.facebook.com/miraheze">Facebook</a> pages.</p>
				<p>Please provide the details below if you report this error to the system administrators via https://phabricator.miraheze.org:</p>
				<p style="font-size: 14px; padding-top: 0.5em;">
					Error "} + beresp.status + " " + beresp.reason + {", forwarded for "} + bereq.http.X-Forwarded-For + {" (Varnish XID "} + bereq.xid + {") via "} + server.identity + {" at "} + now + {".
				</p>
              				<p>We apologize for this inconvenience. The system administrators should be investigating it, and this wiki should be back up soon. </p>
			</div>
			<div style="float: right; padding-right: 1em;">
              <a class="twitter-timeline" data-width="500" data-height="350" text-align: center href="https://twitter.com/miraheze?ref_src=twsrc%5Etfw">Tweets by miraheze</a> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
				<a href="https://meta.miraheze.org/wiki/Miraheze">
					<img src="https://static.miraheze.org/metawiki/7/7e/Powered_by_Miraheze.png" alt="Powered by Miraheze" />
				</a>
			</div>
		</body>
	</html>
	"} );

	return (deliver);
}
