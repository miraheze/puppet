class { '::icinga::repos':
  manage_epel => true,
}

class { '::icinga::server':
  ca_server            => '192.168.5.13',
  colocation_endpoints => { 'centos8.localdomain' => { 'host' => '192.168.5.13', } },
  global_zones         => [ 'global-templates', 'linux-commands', 'windows-commands' ],
  logging_type         => 'syslog',
  logging_level        => 'warning',
}
