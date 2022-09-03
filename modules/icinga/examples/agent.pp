class { '::icinga::repos':
  manage_epel => true,
}

class { '::icinga::agent':
  ca_server        => '192.168.5.13',
  parent_endpoints => { 'debian10.localdomain' => { 'host' => '192.168.5.23', }, 'centos8.localdomain' => { 'host' => '192.168.5.13', } },
  global_zones     => [ 'linux-commands' ],
}
