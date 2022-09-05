class { '::icinga::repos':
  manage_epel   => true,
  manage_extras => true,
}

class { '::icinga::server':
  ca                => true,
  config_server     => true,
  global_zones      => [ 'global-templates', 'linux-commands', 'windows-commands' ],
  web_api_pass      => 'icingaweb2',
  director_api_pass => 'director',
  run_web           => true,
}

class { '::icinga::ido':
  db_type         => 'mysql',
  db_host         => 'localhost',
  db_pass         => 'icinga2',
  manage_database => true,
}

class { '::icinga::web':
  backend_db_type    => $icinga::ido::db_type,
  backend_db_host    => $icinga::ido::db_host,
  backend_db_pass    => $icinga::ido::db_pass,
  db_type            => 'mysql',
  db_host            => 'localhost',
  db_pass            => 'icingaweb2',
  default_admin_user => 'admin',
  default_admin_pass => 'admin',
  manage_database    => true,
  api_pass           => $icinga::server::web_api_pass,
}

class { '::icinga::web::director':
  db_type         => 'mysql',
  db_host         => 'localhost',
  db_pass         => 'director',
  manage_database => true,
  endpoint        => $::fqdn,
  api_host        => 'localhost',
  api_pass        => $icinga::server::director_api_pass,
}

class { '::icinga::web::vspheredb':
  db_type         => 'mysql',
  db_host         => 'localhost',
  db_pass         => 'vspheredb',
  manage_database => true,
}
