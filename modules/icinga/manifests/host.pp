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
    
    file { '/etc/icinga/config/puppet_hosts.cfg':
      ensure  => present,
      owner   => 'icinga',
      group   => 'icinga', 
      mode    => '0644',
    }

    if defined(Class['icinga']) {
        create_resources(nagios_host, $host)
    } else {
        create_resources('icinga::exported_nagios_host', $host)
    }
}
