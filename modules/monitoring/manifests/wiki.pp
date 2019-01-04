define monitoring::wiki (
    $ensure       = present,
    $contacts     = hiera('contactgroups', [ 'icingaadmins', 'ops' ]),
    $domain       = 'miraheze.org',
    $testpage     = 'Main_Page',
    $http_version = '1.1',
    $enable_ssl    = true,
) {
    $wikifqdn = "${name}.${domain}"
    $testuri  = "${protocol}://${name}.${domain}/wiki/${testpage}"
    $protocol_string = upcase($protocol)

    monitoring::services {"${wikifqdn} ${protocol_string}":
        check_command => 'check_http',
        vars          => {
            host        => $wikifqdn,
            http_expect => "HTTP/${http_version} 200",
            http_ssl    => $enable_ssl ? true : false,
            http_vhost  => $wikifqdn,
            http_uri    => $testuri,
        },
    }
}
