class graylog::allinone(
  $elasticsearch,
  $graylog,
) inherits graylog::params {

  class {'::mongodb::globals':
    manage_package_repo => true,
    version             => '4.0.6',
  }
  -> class {'::mongodb::server':
    bind_ip => ['127.0.0.1'],
  }


  if ('version' in $elasticsearch) {
    $es_version = $elasticsearch['version']
  } else {
    $es_version = '6.6.0'
  }

  class { 'elasticsearch':
    version     => $es_version,
    manage_repo => true,
  }
  -> elasticsearch::instance { 'graylog':
    config => {
      'cluster.name' => 'graylog',
      'network.host' => '127.0.0.1',
    },
  }


  if ('major_version' in $graylog) {
    $graylog_major_version = $graylog['major_version']
  } else {
    $graylog_major_version = $graylog::params::major_version
  }

  class { 'graylog::repository':
    version => $graylog_major_version,
  }
  -> class { 'graylog::server':
    config => $graylog['config'],
  }
}
