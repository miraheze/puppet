# role: speedscope
class role::speedscope (
  String $bind_host = '127.0.0.1',
  Integer $port = 3000,
  String $image = 'ghcr.io/weirdgloop/speedscope-service',
  String $version = 'main@sha256:b95cb6528df15063a86d1ec7a44f0b94ffe7b803b3297c1e1f01f7cacf2d3b8f',
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

  firewall::service { 'http':
    proto   => 'tcp',
    port    => 80,
    srange  => "(${firewall_rules_str})",
    notrack => true,
  }

  firewall::service { 'https':
    proto   => 'tcp',
    port    => 443,
    srange  => "(${firewall_rules_str})",
    notrack => true,
  }

  system::role { 'speedscope':
    description => 'Speedscope service server'
  }
}
