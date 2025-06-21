host { 'monitor.icinga.com':
  ip => $facts[networking][interfaces][eth1][ip],
}

class { 'postgresql::server':
  listen_addresses    => '*',
  password_encryption => 'scram-sha-256',
  config_entries      => {
    ssl           => 'on',
    ssl_cert_file => 'server.crt',
    ssl_key_file  => 'server.key',
  },
}

file {
  default:
    ensure => file,
    owner  => $postgresql::server::user,
    group  => $postgresql::server::group,
    ;
  "${postgresql::server::confdir}/server.key":
    source => 'puppet:///modules/icinga/examples/monitor.icinga.com.key',
    mode   => '0600',
    ;
  "${postgresql::server::confdir}/server.crt":
    source => 'puppet:///modules/icinga/examples/monitor.icinga.com.crt',
    mode   => '0640',
    ;
}

class { 'icinga::db::database':
  icingadb_instances => ['monitor.icinga.com'],
  db_type            => 'pgsql',
  db_pass            => 'icingadb',
  tls                => true,
}
