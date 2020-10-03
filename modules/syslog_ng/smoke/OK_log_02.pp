class  { 'syslog_ng':
  config_file                 => '/tmp/syslog-ng.conf',
  manage_package              => false,
  syntax_check_before_reloads => false,
  user                        => 'fwernli',
  group                       => 'fwernli',
  manage_init_defaults        => false,
}

syslog_ng::log {'l2':
    params => [
        {'source' => 's_gsoc2014'},
        {'junction' => [
            {
            'channel' => [
                {'filter' => 'f_json'},
                {'parser' => 'p_json'}
            ]},
            {
            'channel' => [
                {'filter' => 'f_not_json'},
                {'flags' => 'final'}
            ]}
        ]
        },
        {'destination' => 'd_gsoc'}
    ]
}
