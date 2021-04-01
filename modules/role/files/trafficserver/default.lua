-- Global Lua script.
--
-- This file is managed by Puppet.
--

-- The JIT compiler is causing severe performance issues
jit.off(true, true)

function read_config()
    local configfile = ts.get_config_dir() .. "/lua/default.lua.conf"

    ts.debug("Reading " .. configfile)

    dofile(configfile)
    assert(lua_hostname, "lua_hostname not set by " .. configfile)

    ts.debug("read_config() returning " .. lua_hostname)

    return lua_hostname
end

local HOSTNAME = read_config()

function cache_status_to_string(status)
    if status == TS_LUA_CACHE_LOOKUP_MISS then
        return "miss"
    end

    if status == TS_LUA_CACHE_LOOKUP_HIT_FRESH then
        return "hit"
    end

    if status == TS_LUA_CACHE_LOOKUP_HIT_STALE then
        -- We have a cache hit on a stale object. A conditional request was
        -- performed against the origin, which replied with 304 - Not Modified. The
        -- object can be served from cache. Arguably this is not exactly a "hit",
        -- but it is more of a hit than a miss. Further, Varnish calls these "hit",
        -- so for consistency do the same here too.
        if ts.server_response.get_status() == 304 then
            return "hit"
        else
            return "miss"
        end
    end

    if status == TS_LUA_CACHE_LOOKUP_SKIPPED then
        return "pass"
    end

    return "int"
end

function disable_coalescing()
    ts.http.config_int_set(TS_LUA_CONFIG_HTTP_CACHE_MAX_OPEN_READ_RETRIES, -1)
    ts.http.config_int_set(TS_LUA_CONFIG_HTTP_CACHE_MAX_OPEN_WRITE_RETRIES, 1)
    -- We should also set proxy.config.cache.enable_read_while_writer to 0 but
    -- there seems to be no TS_LUA_CONFIG_ option for it.
end

function no_cache_lookup()
    ts.http.config_int_set(TS_LUA_CONFIG_HTTP_CACHE_HTTP, 0)
end

function do_global_read_request()
    if ts.client_request.header['Host'] == 'healthcheck.miraheze.org' and ts.client_request.get_uri() == '/ats-be' then
        ts.http.intercept(function()
            ts.say('HTTP/1.1 200 OK\r\n' ..
                   'Content-Length: 0\r\n' ..
                   'Cache-Control: no-cache\r\n\r\n')
        end)

        return 0
    end

    local cookie = ts.client_request.header['Cookie']

    if cookie then
        -- Equivalent to req.http.Cookie ~ "([sS]ession|Token)=" in VCL
        if string.match(cookie, '[sS]ession=') or string.find(cookie, 'Token=') then
            disable_coalescing()
        end
    end

    if ts.client_request.header['Authorization'] then
        disable_coalescing()
        no_cache_lookup()
    end

    -- This is to avoid some corner-cases and bugs as noted in T125938 , e.g.
    -- applayer gzip turning 500s into junk-response 503s, applayer gzipping
    -- CL:0 bodies into a 20 bytes gzip header, applayer compressing tiny
    -- outputs in general, etc.
    -- We have also observed Swift returning Content-Type: gzip with
    -- non-gzipped content, which confuses varnish-fe making it occasionally
    -- return 503.
    ts.client_request.header['Accept-Encoding'] = nil
end

function do_global_send_response()
    local cache_status = cache_status_to_string(ts.http.get_cache_lookup_status())
    ts.client_response.header['X-Cache-Int'] = HOSTNAME .. " " .. cache_status

    ts.client_response.header['X-ATS-Timestamp'] = os.time()

    if ts.client_response.header['Set-Cookie'] then
        -- At the frontend layer we do have measures in place to ensure that,
        -- regardless of what the origin says, Set-Cookie responses are never
        -- cached. To err on the side of caution and to match what Varnish
        -- backends used to do, override Cache-Control for Set-Cookie responses
        -- here too. T256395
        ts.client_response.header['Cache-Control'] = 'private, max-age=0, s-maxage=0'
    end

    return 0
end

function do_not_cache()
    ts.http.set_server_resp_no_store(1)
end


--- Add header to Vary
-- @param old_vary: the original value of the Vary response header as sent by
--                  the origin server
-- @param header_name: the header to insert into Vary if not already there
function add_vary(old_vary, header_name)
    if not old_vary or string.match(old_vary, "^%s*$") then
        return header_name
    end

    local pattern = header_name:lower():gsub('%-', '%%-')
    if string.match(old_vary:lower(), pattern) then
        return old_vary
    end

    return old_vary .. ',' ..header_name
end

function uncacheable_cookie(cookie, vary)
    if cookie and vary then
        vary = vary:lower()

        -- Vary:Cookie and Cookie ~ "([sS]ession|Token)="
        if string.find(vary, 'cookie') and (string.match(cookie, '[sS]ession=') or string.find(cookie, 'Token=')) then
            return true
        end
    end

    return false
end

function log_set_cookie_response()
    -- Log Set-Cookie responses that look cacheable
    local cache_control = ts.server_response.header['Cache-Control'] or "-"

    if string.find(cache_control, "private") or string.find(cache_control, "no%-cache") or string.find(cache_control, "no%-store") then
        -- Looks uncacheable
        return
    end
end

function do_global_read_response()
    -- Various fairly severe privacy/security/uptime risks exist if we allow
    -- possibly compromised or misconfigured internal apps to emit these headers
    -- through our CDN blindly.
    ts.server_response.header['Public-Key-Pins'] = nil
    ts.server_response.header['Public-Key-Pins-Report-Only'] = nil

    local response_status = ts.server_response.get_status()
    if response_status == 301 or response_status == 302 then
        ts.server_response.header['Vary'] = add_vary(ts.server_response.header['Vary'], 'X-Forwarded-Proto')
    end

    -- Temporary workaround for T255368, to be removed once
    -- https://github.com/apache/trafficserver/issues/6907 is fixed in our
    -- packages
    if response_status == 304 then
        ts.server_response.header['Transfer-Encoding'] = nil
    end

    -- Cap TTL of cacheable 404 responses to 10 minutes
    if response_status == 404 and ts.server_response.is_cacheable() and ts.server_response.get_maxage() > 600 then
        ts.server_response.header['Cache-Control'] = 's-maxage=600'
    end

    ----------------------------------------------------------
    -- Avoid caching responses that might get cached otherwise
    ----------------------------------------------------------
    local content_length = ts.server_response.header['Content-Length']
    local cookie = ts.client_request.header['Cookie']
    local vary = ts.server_response.header['Vary']

    if ts.server_response.header['Set-Cookie'] then
        log_set_cookie_response()
        do_not_cache()
    elseif uncacheable_cookie(cookie, vary) then
        ts.debug("Do not cache response with Vary: " .. vary .. ", request has Cookie: " .. cookie)
        do_not_cache()
    elseif content_length and tonumber(content_length) > 1024 * 16 * 16 * 16 * 16 * 16 then
        -- Do not cache files bigger than 1GB
        ts.debug("Do not cache response with CL:" .. ts.server_response.header['Content-Length'] ..", uri=" ..  ts.client_request.get_uri())
        do_not_cache()
    elseif response_status > 499 then
        -- Do not cache server errors under any circumstances
        do_not_cache()
    elseif ts.client_request.header['Authorization'] then
        do_not_cache()
    end

    return 0
end

function do_global_send_request()
    local ssl_reused = ts.client_request.get_ssl_reused()
    local ssl_protocol = ts.client_request.get_ssl_protocol()
    local ssl_cipher = ts.client_request.get_ssl_cipher()
    local ssl_curve = ts.client_request.get_ssl_curve()
    local client_stack = {ts.http.get_client_protocol_stack()}
    local http2 = 0
    local client_ip, client_port, client_family = ts.client_request.client_addr.get_addr()

    local x_tls_prot = 'h1'
    local x_tls_sess = 'new'
    local x_tls_vers = ssl_protocol
    local x_tls_keyx = ssl_curve
    local x_tls_auth = ssl_cipher
    local x_tls_ciph = x_tls_auth

    for k,v in pairs(client_stack) do
        if string.match(v, "h2") then
            http2 = 1
            x_tls_prot = 'h2'
            break
        end
    end

    if ssl_reused == 1 then
        x_tls_sess = 'reused'
    end

    x_tls_ciph = string.gsub(x_tls_ciph, "^DHE%-RSA%-", "")
    x_tls_ciph = string.gsub(x_tls_ciph, "^ECDHE%-ECDSA%-", "")
    x_tls_ciph = string.gsub(x_tls_ciph, "^ECDHE%-RSA%-", "")
    if x_tls_vers == "TLSv1.3" then
        -- Every TLSv1.3 cipher begins with TLS_
        x_tls_ciph = string.gsub(x_tls_ciph, "^TLS_", "")
        -- TLSv1.3 uses _ instead of - as a separator
        x_tls_ciph = string.gsub(x_tls_ciph, "_", "-")
    end

    -- Starting with TLSv1.3, CHACHA20-POLY1305 will be renamed into
    -- CHACHA20-POLY1305-SHA256. Do the renaming now in Lua to avoid stats
    -- skew later on
    x_tls_ciph = string.gsub(x_tls_ciph, "^CHACHA20%-POLY1305$", "CHACHA20-POLY1305-SHA256")

    if string.match(x_tls_auth, "^ECDHE%-RSA") then
        x_tls_auth = "RSA"
    elseif string.match(x_tls_auth, "^DHE%-RSA") then
        x_tls_auth = "RSA"
        x_tls_keyx = "DHE"
    else
        x_tls_auth = "ECDSA"
    end

    header_content = string.format("H2=%i; SSR=%i; SSL=%s; C=%s; EC=%s;",
                                   http2, ssl_reused, ssl_protocol, ssl_cipher, ssl_curve)
    ts.server_request.header['X-Client-IP'] = client_ip
    ts.server_request.header['X-Client-Port'] = client_port
    ts.server_request.header['X-Connection-Properties'] = header_content
    ts.server_request.header['X-Forwarded-Proto'] = 'https'
end
