class { 'icinga::repos':
  manage_epel   => true,
  manage_extras => true,
}

class { 'icinga::server':
  ca                => true,
  config_server     => true,
  global_zones      => ['global-templates', 'linux-commands', 'windows-commands'],
  web_api_pass      => Sensitive('icingaweb2'),
  director_api_pass => Sensitive('director'),
  run_web           => true,
}

class { 'icinga::ido':
  db_type         => 'pgsql',
  db_pass         => Sensitive('icinga2'),
  manage_database => true,
}

class { 'icinga::web':
  db_type            => 'pgsql',
  db_pass            => Sensitive('icingaweb2'),
  default_admin_user => 'admin',
  default_admin_pass => Sensitive('admin'),
  manage_database    => true,
  api_pass           => $icinga::server::web_api_pass,
}

class { 'icinga::web::monitoring':
  db_type => $icinga::ido::db_type,
  db_pass => $icinga::ido::db_pass,
}

class { 'icinga::web::director':
  db_type         => 'pgsql',
  db_pass         => Sensitive('director'),
  manage_database => true,
  endpoint        => $facts['networking']['fqdn'],
  api_pass        => $icinga::server::director_api_pass,
}

class { 'icinga::web::reporting':
  db_type         => 'pgsql',
  db_pass         => Sensitive('reporting'),
  manage_database => true,
}
