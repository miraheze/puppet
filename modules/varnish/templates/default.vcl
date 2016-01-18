# Miraheze production Varnish 4.0 configuration
# Any changes (except spelling/obviously very small changes that do not break stuff) to Varnish configuration should be discussed 
# with the MediaWiki System Administrators and Miraheze's operations team, as they have a site-wide effect.

# Credits pertially go to the contributors of Wikimedia's Varnish configuration.
# See their Puppet Repo (https://github.com/wikimedia/operations-puppet)
# for the LICENSE.

# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.0 format.
vcl 4.0;

# Default backend definition. Set this to point to your content server.
backend default {
    .host = "127.0.0.1";
    .port = "8080";
}

acl purge {
	"localhost";
	"185.52.1.75";
	"185.52.2.113";
}

sub stash_cookie {
	if (req.restarts == 0) {
		set req.http.X-Orig-cookie = req.http.Cookie;
		unset req.http.Cookie;
	}
}

sub evaluate_cookie {
	# We return pass if all following criteria are met:
	# 1) There is a session/token cookie;
	# 2) The url does NOT begin with /w/load.php (we can easily cache that, at all);
	# 3) If the url is static.miraheze.org (so not a regular wiki), we should still serve cached images
	if (req.http.Cookie ~ "([sS]ession|Token)=" 
		&& req.url !~ "^/w/load\.php"
		&& (req.http.Host == "static.miraheze.org" && req.url !~ "\.(png|svg|jpe?g)$")) {
		return (pass);
	} else {
		call stash_cookie;
	}
}

sub identify_device {
	# Varnish will serve the right version (desktop or mobile) based on the content of
	# this header.
	set req.http.X-Device = "desktop";

	# If the User-Agent matches our regex, or the user explicitly sets the mf_useformat=true cookie to say
	# they want the mobile version, we request MediaWiki to return the mobile version
	if (req.http.User-Agent ~ "(iP(hone|od|ad)|Android|BlackBerry|HTC|mobi|mobile)" || req.http.Cookie ~ "mf_useformat=true") {
		set req.http.X-Device = "phone-tablet";
		# This forces to serve the mobile version, no matter what
		set req.http.X-WAP = "no";
	}

	# If we have a mobile user that wants to have the desktop version, we should not
	# restrict that.
	if (req.http.Cookie ~ "mf_useformat=desktop") {
                set req.http.X-Device = "desktop";
                # Despite MediaWiki should not return the mobile version, it might still do that because
                # the User-Agent matches MobileFrontend's autodetection regex.
                unset req.http.User-Agent;
        }
}

sub pass_authorization {
	if (req.http.Authorization ~ "^OAuth ") {
		return (pass);
	}
}

sub filter_headers {
	# No guys, don't fool us.
	unset req.http.X-Real-IP;
}

sub recv_purge {
	if (req.method == "PURGE") {
		if (!client.ip ~ purge) {
			return (synth(405, "Denied."));
		} else {
			# Purge all variants (Accept-Encoding, etc) of cache? Not sure if needed, 
			# but when I added it (in combination with this else statement) it fixed a large purging issue.
			ban("req.http.Host == " + req.http.Host + " && req.url ~ ^" + req.url + "$");
			return (purge);
		}
	}
}

sub vcl_recv {
	call filter_headers;
	call recv_purge;
	call identify_device;

	if (req.url ~ "^/wiki/Special:CentralAuthLogin/") {
		return (pass);
	}

	# We never want to cache non-GET/HEAD requests.
	if (req.method != "GET" && req.method != "HEAD") {
		return (pass);
	}

	if (req.http.If-Modified-Since && req.http.Cookie ~ "LoggedOut") {
		unset req.http.If-Modified-Since;
	}

	# Don't cache dumps
	if (req.http.Host == "static.miraheze.org" && req.url ~ "^/dumps") {
		return (pass);
	}

	call evaluate_cookie;
	call pass_authorization;

	return (hash);
}

sub vcl_hash {
        # FIXME: try if we can make this ^/wiki/ only?
        if (req.url ~ "^/wiki/" || req.url ~ "^/w/load.php") {
                hash_data(req.http.X-Device);
        }
}

sub vcl_backend_response {
	if (beresp.ttl <= 0s || bereq.http.X-Miraheze-Debug == "1") {
		set beresp.ttl = 120s;
		set beresp.uncacheable = true;
	}

        if (beresp.status >= 400) {
                set beresp.uncacheable = true;
        }

	# Trial: cache 301 redirects for 12h (/, /wiki, /wiki/ redirects only)
        if (beresp.status == 301 && bereq.url ~ "^/?(wiki/?)?$" && !beresp.http.Cache-Control ~ "no-cache") {
                set beresp.ttl = 43200s;
        }

	return (deliver);
}

sub vcl_deliver {
	if (req.url ~ "^/wiki/" || req.url ~ "^/w/index\.php" || req.url ~ "^/\?title=") {
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
