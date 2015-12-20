# This is an example VCL file for Varnish.
#
# It does not do anything by default, delegating control to the
# builtin VCL. The builtin VCL is called when there is no explicit
# return statement.
#
# See the VCL chapters in the Users Guide at https://www.varnish-cache.org/docs/
# and http://varnish-cache.org/trac/wiki/VCLExamples for more examples.

# Credits go to the contributors of Wikimedia's Varnish configuration.
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
}

sub stash_cookie {
	if (req.restarts == 0) {
		set req.http.X-Orig-cookie = req.http.Cookie;
		unset req.http.Cookie;
	}
}

sub restore_cookie {
	# FIXME: bereq not set?
	#if (bereq.http.X-Orig-Cookie) {
		#set bereq.http.Cookie = bereq.http.X-Orig-Cookie;
		#unset bereq.http.X-Orig-Cookie;
	#}
}

sub evaluate_cookie {
	if (req.http.Cookie ~ "([sS]ession|Token)=" && req.url !~ "^/w/load\.php") {
		set req.hash_ignore_busy = true;
	} else {
		call stash_cookie;
	}
}

sub identify_device {
	# Varnish will serve the right version (desktop or mobile) based on the content of
	# this header.
	set req.http.X-Device = "desktop";

        if (req.http.User-Agent ~ "(iP(hone|od|ad)|Android|BlackBerry|HTC|mobi|mobile)") {
                set req.http.X-Device = "phone-tablet";
        }

	# If we have a mobile user that wants to have the desktop version, we should not
	# restrict that.
        if (req.http.X-Device == "phone-tablet" && req.http.Cookie ~ "mf_useformat=desktop") {
                set req.http.X-Device = "desktop";
        }
}

sub pass_authorization {
	if (req.http.Authorization ~ "^OAuth ") {
		set req.hash_ignore_busy = true;
		return (pass);
	}
}

sub filter_headers {
	if (req.restarts == 0) {
		unset req.http.X-Orig-Cookie;
	}
}

sub recv_purge {
	if (req.method == "PURGE") {
		if (!client.ip ~ purge) {
			return (synth(405, "Denied."));
		}

		return (purge);
	}
}

sub vcl_recv {
	call filter_headers;
	call recv_purge;
	call identify_device;

	if (req.url ~ "^/wiki/Special:CentralAuthLogin/") {
		set req.hash_ignore_busy = true;
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

sub vcl_pass {
	call restore_cookie;
}

sub vcl_miss {
	call restore_cookie;
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
