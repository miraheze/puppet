# === class role::trafficserver
#
# Sets up a Traffic Server instance.
#
class role::trafficserver (
    String $user                                                = lookup('role::trafficserver::user', {default_value => 'trafficserver'}),
    Integer $max_lua_states                                     = lookup('role::trafficserver::max_lua_states', {default_value => 256}),
    Trafficserver::Inbound_TLS_settings $tls_settings           = lookup('role::trafficserver::inbound_tls_settings'),
    Trafficserver::Outbound_TLS_settings $outbound_tls_settings = lookup('role::trafficserver::outbound_tls_settings'),
    Optional[Trafficserver::Network_settings] $network_settings = lookup('role::trafficserver::network_settings', {default_value => undef}),
    Optional[Trafficserver::HTTP_settings] $http_settings       = lookup('role::trafficserver::http_settings', {default_value => undef}),
    Optional[Trafficserver::H2_settings] $h2_settings           = lookup('role::trafficserver::h2_settings', {default_value => undef}),
    Boolean $enable_xdebug                                      = lookup('role::trafficserver::enable_xdebug', {default_value => false}),
    Boolean $enable_compress                                    = lookup('role::trafficserver::enable_compress', {default_value => true}),
    Boolean $origin_coalescing                                  = lookup('role::trafficserver::origin_coalescing', {default_value => true}),
    Hash $req_handling                                          = lookup('role::trafficserver::cache::req_handling'),
    Hash $alternate_domains                                     = lookup('role::trafficserver::cache::alternate_domains', {'default_value' => {}}),
    Array[TrafficServer::Mapping_rule] $mapping_rules           = lookup('role::trafficserver::mapping_rules', {default_value => []}),
    Optional[TrafficServer::Negative_Caching] $negative_caching = lookup('role::trafficserver::negative_caching', {default_value => undef}),
    String $default_lua_script                                  = lookup('role::trafficserver::default_lua_script', {default_value => ''}),
    Array[TrafficServer::Storage_element] $storage              = lookup('role::trafficserver::storage_elements', {default_value => []}),
    Array[TrafficServer::Log_format] $log_formats               = lookup('role::trafficserver::log_formats', {default_value => []}),
    Array[TrafficServer::Log_filter] $log_filters               = lookup('role::trafficserver::log_filters', {default_value => []}),
    Array[TrafficServer::Log] $logs                             = lookup('role::trafficserver::logs', {default_value => []}),
    Array[TrafficServer::Parent_rule] $parent_rules             = lookup('role::trafficserver::parent_rules'),
    Optional[Integer] $ram_cache_size                           = lookup('role::trafficserver::ram_cache_size', {default_value => -1}),
    Optional[Integer[0,2]] $res_track_memory                    = lookup('role::trafficserver::res_track_memory', {'default_value' => undef}),
) {

    $global_lua_script = $default_lua_script? {
        ''      => '',
        default => "/etc/trafficserver/lua/${default_lua_script}.lua",
    }

    # Add hostname to the configuration file read by the default global Lua
    # plugin
    file { "/etc/trafficserver/lua/${default_lua_script}.lua.conf":
        ensure  => present,
        owner   => root,
        group   => root,
        mode    => '0444',
        content => "lua_hostname = '${::hostname}'\n",
        notify  => Service['trafficserver'],
    }

    $errorpage = {
        # An explanation for these (and more) fields is available here:
        # https://docs.trafficserver.apache.org/en/latest/admin-guide/logging/formatting.en.html
        # Rendered example:
        # Request from 93.184.216.34 via cp1071.eqiad.wmnet, ATS/8.0.3
        # Error: 502, connect failed at 2019-04-04 12:22:08 GMT
        footer      => "Request from %<chi> via ${::fqdn}, %<{Server}psh><br>Error: %<pssc>, %<prrp> at %<cqtd> %<cqtt> GMT",
    }

    $default_instance = true
    $instance_name = 'backend'
    $paths = trafficserver::get_paths($default_instance, 'backend')

    trafficserver::instance { $instance_name:
        paths                   => $paths,
        default_instance        => $default_instance,
        http_port               => 80,
        https_port               => 443,
        network_settings        => $network_settings,
        http_settings           => $http_settings,
        h2_settings             => $h2_settings,
        inbound_tls_settings    => $inbound_tls_settings,
        outbound_tls_settings   => $outbound_tls_settings,
        enable_xdebug           => $enable_xdebug,
        enable_compress         => $enable_compress,
        origin_coalescing       => $origin_coalescing,
        global_lua_script       => $global_lua_script,
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
        x_forwarded_for         => 1,
        systemd_hardening       => $systemd_hardening,
        res_track_memory        => $res_track_memory,
    }

    # Install default Lua script
    if $default_lua_script != '' {
        trafficserver::lua_script { $default_lua_script:
            source    => "puppet:///modules/role/trafficserver/${default_lua_script}.lua",
            unit_test => "puppet:///modules/role/trafficserver/${default_lua_script}_test.lua",
        }
    }

    trafficserver::lua_script { 'x-mediawiki-original':
        source    => 'puppet:///modules/role/trafficserver/x-mediawiki-original.lua',
        unit_test => 'puppet:///modules/role/trafficserver/x-mediawiki-original_test.lua',
    }

    trafficserver::lua_script { 'normalize-path':
        source    => 'puppet:///modules/role/trafficserver/normalize-path.lua',
    }

    trafficserver::lua_script { 'rb-mw-mangling':
        source    => 'puppet:///modules/role/trafficserver/rb-mw-mangling.lua',
    }

    trafficserver::lua_script { 'x-miraheze-debug-routing':
        source    => 'puppet:///modules/role/trafficserver/x-miraheze-debug-routing.lua',
    }
}
