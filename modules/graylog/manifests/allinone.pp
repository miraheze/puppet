class graylog::allinone (
  $opensearch,
  $graylog,
) inherits graylog::params {
  class { 'mongodb::globals':
    manage_package_repo => true,
    version             => '5.0.19',
  }
  -> class { 'mongodb::server':
    bind_ip => ['127.0.0.1'],
  }

  if 'version' in $opensearch {
    $opensearch_version = $opensearch['version']
  } else {
    $opensearch_version = '2.9.0'
  }

  class { 'opensearch':
    version  => $opensearch_version,
    settings => $opensearch['settings'],
  }

  if 'major_version' in $graylog {
    $graylog_major_version = $graylog['major_version']
  } else {
    $graylog_major_version = $graylog::params::major_version
  }

  class { 'graylog::repository':
    version => $graylog_major_version,
  }
  -> class { 'graylog::server':
    package_name           => $graylog['package_name'],
    config                 => $graylog['config'],
    java_initial_heap_size => $graylog['java_initial_heap_size'],
    java_max_heap_size     => $graylog['java_max_heap_size'],
    java_opts              => $graylog['java_opts'],
  }
}
