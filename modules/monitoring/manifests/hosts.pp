define monitoring::hosts (
    $ensure      = present,
    $contacts    = lookup('contactgroups', {'default_value' => [ 'icingaadmins', 'infrastructure' ]}),
) {

    # If on a container instead of a physical machine or real VM,
    # use the custom fact to get the IP.
    if $facts['virtual'] == 'openvz' {
        $ipaddress4 = $facts['virtual_ip_address']
    } else {
        $ipaddress4 = $facts['ipaddress']
    }

    $ipaddress6 = $facts['ipaddress6']

    @@icinga2::object::host { $title:
        ensure   => $ensure,
        import   => ['generic-host'],
        address  => $ipaddress4,
        address6 => $ipaddress6,
        target   => '/etc/icinga2/conf.d/puppet_hosts.conf',
        vars     => {
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
