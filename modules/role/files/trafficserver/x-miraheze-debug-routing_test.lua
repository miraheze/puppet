_G.ts = {
  client_request = {
    header = {}
  },
  http = {}
}

describe("Busted unit testing framework", function()
  describe("script for ATS Lua Plugin", function()

    it("test - do_remap without X-Miraheze-Debug request header", function()
      require("x-miraheze-debug-routing")

      assert.are.equals(TS_LUA_REMAP_NO_REMAP, do_remap())
    end)

    it("test - valid X-Miraheze-Debug", function()
      stub(ts.client_request, "set_url_host")
      stub(ts, "hook")
      stub(ts.http, "config_int_set")

      require("x-mediawiki-debug-routing")

      _G.ts.client_request.header['X-Miraheze-Debug'] = "backend=mw8.miraheze.org; profile"

      do_remap()

      assert.stub(ts.client_request.set_url_host).was.called_with("mw8.miraheze.org")
      assert.stub(ts.http.config_int_set).was.called_with(TS_LUA_CONFIG_HTTP_CACHE_HTTP, 0)
    end)

    it("test - X-Miraheze-Debug with hostname only", function()
      stub(ts.client_request, "set_url_host")
      stub(ts, "hook")
      stub(ts.http, "config_int_set")

      require("x-miraheze-debug-routing")

      _G.ts.client_request.header['X-Miraheze-Debug'] = "mw9.miraheze.org"

      do_remap()

      assert.stub(ts.client_request.set_url_host).was.called_with("mw9.miraheze.org")
      assert.stub(ts.http.config_int_set).was.called_with(TS_LUA_CONFIG_HTTP_CACHE_HTTP, 0)
    end)

    it("test - X-Miraheze-Debug with invalid value", function()
      stub(ts.client_request, "set_url_host")
      stub(ts, "hook")
      stub(ts.http, "set_resp")

      require("x-miraheze-debug-routing")

      _G.ts.client_request.header['X-Miraheze-Debug'] = "the best banana and the worst potato"

      do_remap()

      assert.stub(ts.http.set_resp).was.called_with(400, "x-miraheze-debug-routing: no match found for the backend specified in X-Miraheze-Debug")
    end)
  end)
end)
