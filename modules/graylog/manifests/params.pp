class graylog::params {
  $major_version = '5.1'
  $package_name = 'graylog-server'
  $package_version = 'installed'

  $repository_release = 'stable'

  $default_config = {
    'bin_dir'             => '/usr/share/graylog-server/bin',
    'data_dir'            => '/var/lib/graylog-server',
    'plugin_dir'          => '/usr/share/graylog-server/plugin',
    'message_journal_dir' => '/var/lib/graylog-server/journal',
    'is_leader'           => true,
  }

  $server_user = 'graylog'
  $server_group = 'graylog'

  $java_initial_heap_size = '1g'
  $java_max_heap_size = '1g'
  $java_opts = ''
}
