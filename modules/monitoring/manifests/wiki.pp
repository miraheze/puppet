define monitoring::wiki (
    $ensure       = present,
    $name         = undef,
    $contacts     = hiera('contactgroups', [ 'icingaadmins', 'ops' ]),
    $protocol     = 'https',
    $domain       = 'miraheze.org',
    $testpage     = 'Main_Page',
    $http_version = '1.1',
) {

    $wikifqdn = "${name}.${domain}"
    $testuri  = "${protocol}://${name}.${domain}/wiki/${testpage}"
    $protocol_string = upcase($protocol)

    monitoring::services {"${wikifqdn} ${protocol_string}":
        check_command => 'check_http',
        vars          => {
            http_expect => "HTTP/${http_version} 200",
            http_ssl    => true,
            http_vhost  => $wikifqdn,
            http_uri    => $testuri,
        },
    }
}
