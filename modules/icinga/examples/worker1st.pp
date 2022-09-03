class { '::icinga::repos':
  manage_epel => true,
}

class { '::icinga::worker':
  ca_server            => '192.168.5.13',
  zone                 => 'dmz',
  parent_endpoints     => { 'debian10.localdomain' => { 'host' => '192.168.5.23', }, 'centos8.localdomain' => { 'host' => '192.168.5.13', } },
  colocation_endpoints => { 'ubuntu16.localdomain' => { 'host' => '192.168.5.31', } },
  global_zones         => [ 'global-templates', 'linux-commands', 'windows-commands' ],
  logging_type         => 'syslog',
  logging_level        => 'warning',
}
