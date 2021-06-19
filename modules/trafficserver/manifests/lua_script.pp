# == Define: trafficserver::lua_script
#
# Add the Lua script defined in $source under /etc/trafficserver/lua/ and
# notify trafficserver.
#
# For details about Lua scripting in Traffic Server, see:
# https://docs.trafficserver.apache.org/en/8.0.x/admin-guide/plugins/ts_lua.en.html
#
# === Parameters
#
# [*source*]
#   Lua script source file
#
# [*content*]
#   Lua script content file (template)
#
# [*unit_test*]
#   Busted unit test source file for this Lua script (optional)
#
# === Examples
#
#      trafficserver::lua_script { 'set-x-cache':
#          source    => 'puppet:///modules/profile/trafficserver/set-x-cache.lua',
#          unit_test => 'puppet:///modules/profile/trafficserver/set-x-cache_test.lua',
#      }
#
define trafficserver::lua_script(
    Optional[Stdlib::Filesource] $source        = undef,
    Optional                     $content       = undef,
    Optional[Stdlib::Filesource] $unit_test     = undef,
    String                       $service_name  = 'trafficserver',
    Stdlib::Absolutepath         $config_prefix = '/etc/trafficserver',
) {
    if !defined(Trafficserver::Lua_infra["infra-${service_name}"]) {
        trafficserver::lua_infra{ "infra-${service_name}":
            service_name  => $service_name,
            config_prefix => $config_prefix,
        }
    }

    $lua_path = "${config_prefix}/lua"

    $defaults = {
        owner   => $trafficserver::user,
        require => File[$lua_path],
    }

    if $unit_test != undef {
        file { "${lua_path}/${title}_test.lua":
            *      => $defaults,
            source => $unit_test,
            before => File["${lua_path}/${title}.lua"],
        }
    }

    file { "${lua_path}/${title}.lua":
        *       => $defaults,
        source  => $source,
        content => $content,
    }

    # Upon Lua scripts modification, run busted and reload trafficserver iff
    # all tests are green
    File["${lua_path}/${title}.lua"] ~> Exec["unit_tests_${service_name}"] ~> Exec["trigger_lua_reload_${config_prefix}"] ~> Service[$service_name]
}
