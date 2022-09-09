define monitoring::hosts (
    $ensure      = present,
    $contacts    = lookup('contactgroups', {'default_value' => [ 'sre' ]}),
) {
    @@icinga2::object::host { $title:
        ensure   => $ensure,
        import   => ['generic-host'],
        address6 => $facts['ipaddress6'],
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
