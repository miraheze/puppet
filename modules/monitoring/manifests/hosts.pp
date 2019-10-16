define monitoring::hosts (
    $ensure   = present,
    $contacts = hiera('contactgroups', [ 'icingaadmins', 'ops' ]),
    # Defaults to use the variables below.
    $ip       = hiera('monitoring::hosts::ip', undef),
) {

    if $ip != undef {
        $ipaddress = $ip
    } else {
        # If on a container instead of a physical machine or real VM,
        # use the custom fact to get the IP.
        if $facts['virtual'] == 'openvz' {
            $ipaddress = $facts['virtual_ip_address']
        } else {
            $ipaddress = $facts['ipaddress']
        }
    }

    @@icinga2::object::host { $title:
        ensure  => $ensure,
        import  => ['generic-host'],
        address => $ipaddress,
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
