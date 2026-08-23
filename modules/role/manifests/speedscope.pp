# role: speedscope
class role::speedscope (
  String $bind_host = '127.0.0.1',
  Integer $port = 3000,
  String $image = 'ghcr.io/weirdgloop/speedscope-service',
  String $version = 'sha256-1fc7213162ec41442451e4d7a322fc9033f41016e52640159381567393554c65',
) {
  ssl::wildcard { 'speedscope wildcard': }

  nginx::site { 'speedscope_proxy':
    ensure => present,
    source => 'puppet:///modules/role/speedscope/speedscope.wikitide.net.conf',
  }

  include ::docker
  class { '::speedscope':
    bind_host => $bind_host,
    port      => $port,
    log_token => lookup('speedscope::log_token'),
    image     => $image,
    version   => $version,
  }

  $subquery = @("PQL")
    (resources { type = 'Class' and title = 'Role::MediaWiki' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_task' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_beta' } or
    resources { type = 'Class' and title = 'Role::Varnish' } or
    resources { type = 'Class' and title = 'Role::Cache::Cache' } or
    resources { type = 'Class' and title = 'Role::Icinga2' })
    | PQL
  $firewall_rules_str = vmlib::generate_firewall_ip($subquery)

  ferm::service { 'http':
    proto   => 'tcp',
    port    => '80',
    srange  => "(${firewall_rules_str})",
    notrack => true,
  }

  ferm::service { 'https':
    proto   => 'tcp',
    port    => '443',
    srange  => "(${firewall_rules_str})",
    notrack => true,
  }

  system::role { 'speedscope':
    description => 'Speedscope service server'
  }
}
