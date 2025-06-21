# hostname for the example certificate
# should be server.icinga.com or db.icinga.com
#host { 'db.icinga.com':
#  ip => $facts[networking][interfaces][eth1][ip],
#}

$ssl_dir = $facts['os']['family'] ? {
  'redhat' => '/etc/pki/tls',
  'debian' => '/etc/ssl',
}

file { "${ssl_dir}/private":
  ensure => directory,
  mode   => '0755',
}

package { 'mariadb-server':
  ensure => installed,
}

file {
  default:
    ensure => file,
    group  => 'mysql',
    mode   => '0644',
    notify => Class['mysql::server'],
    ;
  "${ssl_dir}/private/mysql.pem":
    source => 'puppet:///modules/icinga/examples/server.icinga.com.key',
    mode   => '0440',
    ;
  "${ssl_dir}/certs/mysql.pem":
    source => 'puppet:///modules/icinga/examples/server.icinga.com.crt',
    ;
  "${ssl_dir}/certs/mysql-ca.crt":
    source => 'puppet:///modules/icinga/examples/ca.crt',
    ;
}

class { 'mysql::server':
  package_manage   => false,
  override_options => {
    'mysqld' => {
      innodb_file_format    => 'barracuda',
      innodb_file_per_table => 1,
      innodb_large_prefix   => 1,
      bind-address          => '0.0.0.0',
      ssl                   => 'on',
      ssl-cert              => "${ssl_dir}/certs/mysql.pem",
      ssl-key               => "${ssl_dir}/private/mysql.pem",
      ssl-ca                => "${ssl_dir}/certs/mysql-ca.crt",
    },
  },
}

class { 'icinga::ido::database':
  ido_instances => ['192.168.6.2', '192.168.6.11', '192.168.6.12'],
  db_type       => 'mysql',
  db_pass       => 'icinga2',
  tls           => 'password',
}

class { 'icinga::db::database':
  access_instances => ['192.168.6.2', '192.168.6.11', '192.168.6.12'],
  db_type          => 'mysql',
  db_pass          => 'icingadb',
  tls              => 'cert',
}

class { 'icinga::web::database':
  web_instances => ['192.168.6.2', '192.168.6.11', '192.168.6.12'],
  db_type       => 'mysql',
  db_pass       => 'icingaweb2',
  tls           => 'cert',
}

class { 'icinga::web::director::database':
  web_instances => ['192.168.6.2'],
  db_type       => 'mysql',
  db_pass       => 'director',
  tls           => 'password',
}

class { 'icinga::web::reporting::database':
  web_instances => ['192.168.6.2'],
  db_type       => 'mysql',
  db_pass       => 'reporting',
  tls           => 'password',
}

class { 'icinga::web::x509::database':
  web_instances => ['192.168.6.2'],
  db_type       => 'mysql',
  db_pass       => 'x509',
  tls           => 'password',
}

class { 'icinga::web::vspheredb::database':
  web_instances => ['192.168.6.2'],
  db_type       => 'mysql',
  db_pass       => 'vspheredb',
  tls           => 'password',
}
