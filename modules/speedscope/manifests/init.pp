# == Class: speedscope

class speedscope {
  file { '/srv/speedscope':
    ensure => directory,
  }

  $speedscope_version = '1fc7213162ec41442451e4d7a322fc9033f41016e52640159381567393554c65'
  $speedscope_log_token = lookup('speedscope::log_token')
  $speedscope_port = 3000

  file { '/srv/speedscope/.env':
    ensure => present,
    content => template('speedscope/.env.erb'),
    owner => 'root',
    group => 'root',
    mode => '0600',
  }

  file { '/srv/speedscope/docker-compose.yml':
    ensure => present,
    content => template('speedscope/docker-compose.yml.erb'),
    owner => 'root',
    group => 'root',
    mode => '0644',
  }

  docker::compose { 'speedscope':
    ensure => present,
    compose_file => '/srv/speedscope/docker-compose.yml',
    require => [
      File['/srv/speedscope/docker-compose.yml'],
      File['/srv/speedscope/.env'],
    ],
  }

  # TODO Add aggregation cronjobs
}
