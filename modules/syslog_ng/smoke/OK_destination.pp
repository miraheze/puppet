class  { 'syslog_ng':
  config_file                 => '/tmp/syslog-ng.conf',
  manage_package              => false,
  syntax_check_before_reloads => false,
  user                        => 'fwernli',
  group                       => 'fwernli',
  manage_init_defaults        => false,
}

syslog_ng::destination { 'd_udp':
    params => {
        'type'    => 'udp',
        'options' => [
            "'127.0.0.1'",
            {'port' => '1999'},
            {'localport' => '999'}
        ]
    }
}

