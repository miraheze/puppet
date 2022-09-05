define monitoring::wiki (
    $ensure       = present,
    $contacts     = lookup('contactgroups', {'default_value' => [ 'sre' ]}),
    $protocol     = 'https',
    $domain       = 'miraheze.org',
    $testpage     = 'Main_Page',
    $http_version = '1.1',
    $enable_ssl   = true,
) {
    $wikifqdn = "${name}.${domain}"
    $testuri  = "/wiki/${testpage}"
    $protocol_string = upcase($protocol)

    monitoring::services {"${wikifqdn} ${protocol_string}":
        check_command => 'check_http',
        vars          => {
            address     => $wikifqdn,
            http_expect => "HTTP/${http_version} 200",
            http_ssl    => $enable_ssl ? {
                true    => true,
                default => false,
            },
            http_vhost  => $wikifqdn,
            http_uri    => $testuri,
        },
    }
}
