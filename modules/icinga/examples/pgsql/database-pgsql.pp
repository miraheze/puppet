class { 'postgresql::server':
  listen_addresses           => '*',
}

class { '::icinga::ido::database':
  ido_instances => ['192.168.5.13', '192.168.5.23'],
  db_type       => 'pgsql',
  db_pass       => 'icinga2',
}

class { '::icinga::web::database':
  ido_instances => ['192.168.5.13', '192.168.5.23'],
  db_type       => 'pgsql',
  db_pass       => 'icingaweb2',
}
