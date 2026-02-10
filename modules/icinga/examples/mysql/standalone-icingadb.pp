class { 'icinga::repos':
  manage_epel   => true,
  manage_extras => true,
}

# Setting riquired for MySQL < 5.7 and MariaDB < 10.2
if $facts['os']['family'] == 'redhat' and Integer($facts['os']['release']['major']) < 8 {
  class { 'mysql::server':
    override_options => {
      mysqld => {
        innodb_file_format    => 'barracuda',
        innodb_file_per_table => 1,
        innodb_large_prefix   => 1,
      },
    },
  }
}

class { 'icinga::server':
  ca                => true,
  config_server     => true,
  global_zones      => ['global-templates', 'linux-commands', 'windows-commands'],
  web_api_pass      => Sensitive('icingaweb2'),
  director_api_pass => Sensitive('director'),
  run_web           => true,
}

class { 'icinga::db':
  db_type         => 'mysql',
  db_pass         => Sensitive('icinga2'),
  manage_database => true,
}

class { 'icinga::web':
  db_type            => 'mysql',
  db_pass            => Sensitive('icingaweb2'),
  default_admin_user => 'admin',
  default_admin_pass => Sensitive('admin'),
  manage_database    => true,
  api_pass           => $icinga::server::web_api_pass,
}

class { 'icinga::web::icingadb':
  db_type => $icinga::db::db_type,
  db_pass => $icinga::db::db_pass,
}

class { 'icinga::web::director':
  db_type         => 'mysql',
  db_pass         => Sensitive('director'),
  manage_database => true,
  endpoint        => $facts['networking']['fqdn'],
  api_pass        => $icinga::server::director_api_pass,
}
