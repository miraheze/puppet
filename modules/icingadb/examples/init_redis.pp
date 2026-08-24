file {
  default:
    ensure => file,
    owner  => 'icingadb-redis',
    group  => 'icingadb-redis',
    mode   => '0640',
    tag    => 'icingadb::redis::config::file',
  ;
  '/etc/icingadb-redis/server.crt':
    source => 'puppet:///modules/icinga/examples/server.icinga.com.crt',
  ;
  '/etc/icingadb-redis/server.key':
    source => 'puppet:///modules/icinga/examples/server.icinga.com.key',
    mode   => '0400',
  ;
  '/etc/icingadb-redis/ca.crt':
    source => 'puppet:///modules/icinga/examples/ca.crt',
  ;
}

class { 'icingadb::redis':
  manage_repos    => true,
  bind            => $facts[networking][interfaces][eth1][ip],
  requirepass     => 'supersecret',
  use_tls         => true,
  tls_cert_file   => '/etc/icingadb-redis/server.crt',
  tls_key_file    => '/etc/icingadb-redis/server.key',
  tls_cacert_file => '/etc/icingadb-redis/ca.crt',
#  tls_auth_clients => 'yes',
}
