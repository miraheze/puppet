# === class role::trafficserver
#
# Sets up Traffic Server.
#
class role::trafficserver (
    String $user                                                = lookup('role::trafficserver::user', {default_value => 'trafficserver'}),
    Integer $max_lua_states                                     = lookup('role::trafficserver::max_lua_states', {default_value => 256}),
    Trafficserver::Inbound_TLS_settings $inbound_tls_settings   = lookup('role::trafficserver::inbound_tls_settings'),
    Trafficserver::Outbound_TLS_settings $outbound_tls_settings = lookup('role::trafficserver::outbound_tls_settings'),
    Optional[Trafficserver::Network_settings] $network_settings = lookup('role::trafficserver::network_settings', {default_value => undef}),
    Optional[Trafficserver::HTTP_settings] $http_settings       = lookup('role::trafficserver::http_settings', {default_value => undef}),
    Optional[Trafficserver::H2_settings] $h2_settings           = lookup('role::trafficserver::h2_settings', {default_value => undef}),
    Boolean $enable_xdebug                                      = lookup('role::trafficserver::enable_xdebug', {default_value => false}),
    Boolean $enable_compress                                    = lookup('role::trafficserver::enable_compress', {default_value => false}),
    Boolean $origin_coalescing                                  = lookup('role::trafficserver::origin_coalescing', {default_value => true}),
    Hash $req_handling                                          = lookup('role::trafficserver::cache::req_handling'),
    Hash $alternate_domains                                     = lookup('role::trafficserver::cache::alternate_domains', {'default_value' => {}}),
    Array[TrafficServer::Mapping_rule] $mapping_rules           = lookup('role::trafficserver::mapping_rules', {default_value => []}),
    Optional[TrafficServer::Negative_Caching] $negative_caching = lookup('role::trafficserver::negative_caching', {default_value => undef}),
    Array[TrafficServer::Storage_element] $storage              = lookup('role::trafficserver::storage_elements', {default_value => []}),
    Array[TrafficServer::Log_format] $log_formats               = lookup('role::trafficserver::log_formats', {default_value => []}),
    Array[TrafficServer::Log_filter] $log_filters               = lookup('role::trafficserver::log_filters', {default_value => []}),
    Array[TrafficServer::Log] $logs                             = lookup('role::trafficserver::logs', {default_value => []}),
    Array[TrafficServer::Parent_rule] $parent_rules             = lookup('role::trafficserver::parent_rules'),
    Optional[Integer] $ram_cache_size                           = lookup('role::trafficserver::ram_cache_size', {default_value => -1}),
    Optional[Integer[0,2]] $res_track_memory                    = lookup('role::trafficserver::res_track_memory', {'default_value' => undef}),
    Boolean $systemd_hardening                                  = lookup('role::trafficserver::systemd_hardening', {default_value => true}),
) {

    # Add hostname to the configuration file read by the default global Lua
    # plugin
    file { "/etc/trafficserver/lua/default.lua.conf":
        ensure  => present,
        owner   => root,
        group   => root,
        mode    => '0444',
        content => "lua_hostname = '${::hostname}'\n",
        notify  => Service['trafficserver'],
    }

    $paths = trafficserver::get_paths()

    class { '::trafficserver':
        paths                   => $paths,
        http_port               => 80,
        https_port              => 443,
        network_settings        => $network_settings,
        http_settings           => $http_settings,
        h2_settings             => $h2_settings,
        inbound_tls_settings    => $inbound_tls_settings,
        outbound_tls_settings   => $outbound_tls_settings,
        enable_xdebug           => $enable_xdebug,
        enable_compress         => $enable_compress,
        origin_coalescing       => $origin_coalescing,
        max_lua_states          => $max_lua_states,
        storage                 => $storage,
        ram_cache_size          => $ram_cache_size,
        mapping_rules           => $mapping_rules,
        guaranteed_max_lifetime => 86400, # 24 hours
        caching_rules           => role::trafficserver_caching_rules($req_handling, $alternate_domains, $mapping_rules),
        negative_caching        => $negative_caching,
        log_formats             => $log_formats,
        log_filters             => $log_filters,
        logs                    => $logs,
        parent_rules            => $parent_rules,
        error_page              => template('role/trafficserver/errorpage.html.erb'),
        systemd_hardening       => $systemd_hardening,
        res_track_memory        => $res_track_memory,
    }

    $module_path = get_module_path($module_name)
    $csp_whitelist = loadyaml("${module_path}/data/csp_whitelist.yaml")
    $frame_whitelist = loadyaml("${module_path}/data/frame_whitelist.yaml")

    # Install default Lua script
    trafficserver::lua_script { 'default':
        content   => template('role/trafficserver/default.lua.erb'),
        unit_test => 'puppet:///modules/role/trafficserver/default_test.lua',
    }

    trafficserver::lua_script { 'x-miraheze-debug-routing':
        source    => 'puppet:///modules/role/trafficserver/x-miraheze-debug-routing.lua',
    }

    # We do this last so it detects trafficserver service
    include ssl::wildcard
    include ssl::hiera

    ssl::cert { 'm.miraheze.org': }
}
