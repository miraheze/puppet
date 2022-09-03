class { 'mysql::server':
  override_options => {
    'mysqld' => {
      'bind-address' => '0.0.0.0',
    },
  },
}

class { '::icinga::ido::database':
  ido_instances => ['192.168.5.13', '192.168.5.23'],
  db_type       => 'mysql',
  db_pass       => 'icinga2',
}

class { '::icinga::web::database':
  ido_instances => ['192.168.5.13', '192.168.5.23'],
  db_type       => 'mysql',
  db_pass       => 'icingaweb2',
}
