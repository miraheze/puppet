-- The JIT compiler is causing severe performance issues
jit.off(true, true)

function do_remap()
    local xwd = ts.client_request.header['X-Miraheze-Debug']
    if not xwd then
        -- Stop immediately if no XWD header has been specified
        return TS_LUA_REMAP_NO_REMAP
    end

    local debug_map = {
        ["1"]                  = "mw8.miraheze.org",
        ["mw8.miraheze.org"]   = "mw8.miraheze.org",
        ["mw9.miraheze.org"]   = "mw9.miraheze.org",
        ["mw10.miraheze.org"]  = "mw10.miraheze.org",
        ["mw11.miraheze.org"]  = "mw11.miraheze.org",
        ["mw12.miraheze.org"]  = "mw12.miraheze.org",
        ["mw13.miraheze.org"]  = "mw13.miraheze.org",
        ["test3.miraheze.org"] = "test3.miraheze.org",
    }

    local backend = string.match(xwd, 'backend=([%a%d%.]+)')

    -- For backward-compatibility, if the header does not contain a
    -- well-formed 'backend' attribute, then the entire header is used as
    -- the backend value
    if not backend then
        backend = xwd
    end

    if debug_map[backend] then
        ts.client_request.set_url_host(debug_map[backend])

        -- Skip the cache if XWD is valid
        ts.http.config_int_set(TS_LUA_CONFIG_HTTP_CACHE_HTTP, 0)

        return TS_LUA_REMAP_DID_REMAP_STOP
    else
        ts.http.set_resp(400, "x-miraheze-debug-routing: no match found for the backend specified in X-Miraheze-Debug")
        return TS_LUA_REMAP_NO_REMAP_STOP
    end
end
