define monitoring::hosts (
    $ensure   = present,
    $contacts = hiera('contactgroups', [ 'icingaadmins', 'ops' ]),
) {

   # If on a container instead of a physical machine or real VM,
    # use the custom fact to get the IP.
    if $facts['virtual'] == 'openvz' {
        $ip = $facts['virtual_ip_address']
    } else {
        $ip = $facts['ipaddress']
    }

    @@icinga2::object::host { $title:
        ensure  => $ensure,
        import  => ['generic-host'],
        address => $ip,
        target  => '/etc/icinga2/conf.d/puppet_hosts.conf',
        vars    => {
            notification => {
                mail => {
                    groups => $contacts,
                },
                irc => {
                    groups => [ 'icingaadmins' ],
                },
            },
        },
    }
}
