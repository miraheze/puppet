define monitoring::hosts (
    $ensure      = present,
    $contacts    = lookup('contactgroups', {'default_value' => [ 'sre' ]}),
) {
    if ( $facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18'] ) {
        $address6 = $facts['networking']['interfaces']['ens18']['ip6']
    } elsif ( $facts['networking']['interfaces']['ens18'] ) {
        $address6 = $facts['networking']['interfaces']['ens18']['ip6']
    } else {
        $address6 = $facts['networking']['ip6']
    }

    @@icinga2::object::host { $title:
        ensure   => $ensure,
        import   => ['generic-host'],
        address6 => $facts['networking']['ip6'],
        target   => '/etc/icinga2/conf.d/puppet_hosts.conf',
        vars     => {
            notification => {
                mail => {
                    groups => $contacts,
                },
                irc  => {
                    groups => [ 'icingaadmins' ],
                },
            },
        },
    }
}
