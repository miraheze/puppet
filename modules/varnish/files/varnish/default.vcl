# This is an example VCL file for Varnish.
#
# It does not do anything by default, delegating control to the
# builtin VCL. The builtin VCL is called when there is no explicit
# return statement.
#
# See the VCL chapters in the Users Guide at https://www.varnish-cache.org/docs/
# and http://varnish-cache.org/trac/wiki/VCLExamples for more examples.

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
	if (req.http.Cookie ~ "([sS]ession|Token)="
	&& req.url !~ "^/w/load\.php") {
		set req.hash_ignore_busy = true;
	} else {
		call stash_cookie;
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
		} elseif (req.http.Host ~ "static.miraheze.org") {
			set req.hash_ignore_busy = true;
			return (hash);
		} else {
			return (synth(204, "Domain not cached here."));
		}
	}
}

sub vcl_recv {
	call filter_headers;
	call recv_purge;

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

sub vcl_backend_response {
	if (beresp.ttl <= 0s || bereq.http.X-Miraheze-Debug == "1") {
		set beresp.ttl = 120s;
		set beresp.uncacheable = true;
	}

        if (beresp.status >= 400) {
                set beresp.uncacheable = true;
        }

	return (deliver);
}

sub vcl_deliver {
	if (req.url ~ "^/wiki/" || req.url ~ "^/w/index\.php" || req.url ~ "^/\?title=") {
		if (req.url !~ "^/wiki/Special\:Banner") {
			set resp.http.Cache-Control = "private, s-maxage=0, maxage=0, must-revalidate";
		}
	}
}
