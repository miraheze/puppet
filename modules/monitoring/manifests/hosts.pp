define monitoring::hosts (
    $ensure      = present,
    $contacts    = lookup('contactgroups', {'default_value' => [ 'infra' ]}),
) {
    if ( $facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens19']['ip']
        $address6 = undef
    } elsif ( $facts['networking']['interfaces']['ens18'] ) {
        $address = undef
        $address6 = $facts['networking']['interfaces']['ens18']['ip6']
    } else {
        $address = undef
        $address6 = $facts['networking']['ip6']
    }

    if $ensure == present {
        icinga2::object::host { $title:
            export   => lookup('icinga2_host', {'default_value' => 'mon181.fsslc.wtnet'}),
            import   => ['generic-host'],
            address  => $address,
            address6 => $address6,
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
}
