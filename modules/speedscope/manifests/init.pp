# == Class: speedscope

class speedscope (
  String $bind_host,
  Integer $port,
  String $log_token,
  String $image,
  String $version,
) {
  file { '/srv/speedscope':
    ensure => directory,
  }

  file { '/srv/speedscope/.env':
    ensure  => present,
    content => epp('speedscope/speedscope.env.epp', {
      'port'      => $port,
      'log_token' => $log_token
    }),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
  }

  file { '/srv/speedscope/docker-compose.yml':
    ensure  => present,
    content => epp('speedscope/docker-compose.yml.epp', {
      'image'     => $image,
      'version'   => $version,
      'bind_host' => $bind_host,
      'port'      => $port,
    }),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  docker::compose { 'speedscope':
    ensure       => present,
    compose_file => '/srv/speedscope/docker-compose.yml',
    require      => [
      File['/srv/speedscope/docker-compose.yml'],
      File['/srv/speedscope/.env'],
    ],
  }

  systemd::timer::job { 'speedscope_hourly_aggregation':
    ensure            => present,
    description       => 'Generates the hourly speedscope aggregation',
    working_directory => '/srv/speedscope',
    command           => "/usr/bin/docker run --rm --env-file .env -v \"./speedscope.db:/data/speedscope.db:rw\" \"${speedscope_image}:${speedscope_version}\" node dist/src/aggregateHourly.js",
    interval          => {
      start    => 'OnCalendar',
      interval => '*-*-* *:00:00',
    },
  }

  systemd::timer::job { 'speedscope_daily_aggregation':
    ensure            => present,
    description       => 'Generates the daily speedscope aggregation',
    working_directory => '/srv/speedscope',
    command           => "/usr/bin/docker run --rm --env-file .env -v \"./speedscope.db:/data/speedscope.db:rw\" \"${speedscope_image}:${speedscope_version}\" node dist/src/aggregateDaily.js",
    interval          => {
      start    => 'OnCalendar',
      interval => '*-*-* 00:30:00',
    },
  }

  monitoring::nrpe { "speedscope ${port} check":
    ensure  => present,
    command => "/usr/lib/nagios/plugins/check_tcp -H 127.0.0.1 -p ${port}",
  }

  if ( $facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18'] ) {
    $address = $facts['networking']['interfaces']['ens19']['ip']
  } elsif ( $facts['networking']['interfaces']['ens18'] ) {
    $address = $facts['networking']['interfaces']['ens18']['ip6']
  } else {
    $address = $facts['networking']['ip6']
  }

  monitoring::services { 'speedscope.wikitide.net HTTPS':
    check_command => 'check_http',
    vars          => {
      address    => $address,
      http_ssl   => true,
      http_vhost => 'speedscope.wikitide.net',
      # Use /aggregations endpoint, as / serves a static site
      http_uri    => 'https://speedscope.wikitide.net/aggregations'
    },
  }
}
