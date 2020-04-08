define monitoring::hosts (
    $ensure      = present,
    $contacts    = lookup('contactgroups', {'default_value' => [ 'icingaadmins', 'ops' ]}),
    # Defaults to use the variables below.
    $ipaddress = lookup('monitoring::hosts::ipaddress', {'default_value' => undef}),
) {

    if $ipaddress != undef {
        $ipaddresses = $ipaddress
    } else {
        # If on a container instead of a physical machine or real VM,
        # use the custom fact to get the IP.
        if $facts['virtual'] == 'openvz' {
            $ipaddresses = $facts['virtual_ip_address']
        } else {
            $ipaddresses = $facts['ipaddress']
        }
    }

    @@icinga2::object::host { $title:
        ensure  => $ensure,
        import  => ['generic-host'],
        address => $ipaddresses,
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
