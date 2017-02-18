# exported resource for monitoring all hosts
define icinga::host (
  $ensure   = present,
  $ip       = $::ipaddress,
  $contacts = hiera('contactgroups', 'ops'),
  ) {
    $host = {
        "${title}" => {
            ensure                => $ensure,
            use                   => 'generic-host',
            host_name             => $title,
            address               => $ip,
            contact_groups        => $contacts,
            target                => '/etc/icinga/config/puppet_hosts.cfg',
        },
    }

    if defined(Class['icinga']) {
        create_resources(nagios_host, $host)
    } else {
        create_resources('@@nagios_host', $host)
    }
}
