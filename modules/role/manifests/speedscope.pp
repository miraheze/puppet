# role: speedscope
class role::speedscope (
  String $bind_host = '127.0.0.1',
  Integer $port = 3000,
  String $image = 'ghcr.io/weirdgloop/speedscope-service',
  String $version = 'main@sha256:46df2c52f0307c5bc0b6bf8d918026e4e408e5738c3e9d87a36e0f7ae0c48214',
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


  firewall::service { 'http':
    proto   => 'tcp',
    port    => 80,
    src_sets  => ['MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
    notrack => true,
  }

  firewall::service { 'https':
    proto   => 'tcp',
    port    => 443,
    src_sets  => ['MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
    notrack => true,
  }

  system::role { 'speedscope':
    description => 'Speedscope service server'
  }
}
