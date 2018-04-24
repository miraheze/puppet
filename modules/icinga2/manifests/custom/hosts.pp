define icinga2::custom::hosts (
  $ensure   = present,
  $ip       = $::ipaddress,
  $contacts = hiera('contactgroups', [ 'icingaadmins', 'ops' ]),
) {
    icinga2::object::host { $title:
        ensure  => $ensure,
        import  => ['generic-host'],
        address => $ip,
        target  => '/etc/icinga2/conf.d/puppet_hosts.conf',
        vars    => {
            notification => {
                mail => {
                    groups => $contacts,
                },
            },
        },
    }
}
