# == Class: speedscope

class speedscope (
  String $bind_host = '127.0.0.1',
  Integer $port = 3000,
  String $log_token = lookup('speedscope::log_token'),
  String $image = 'ghcr.io/weirdgloop/speedscope-service',
  String $version = '1fc7213162ec41442451e4d7a322fc9033f41016e52640159381567393554c65',
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
}
