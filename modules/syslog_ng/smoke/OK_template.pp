class  { 'syslog_ng':
  config_file                 => '/tmp/syslog-ng.conf',
  manage_package              => false,
  syntax_check_before_reloads => false,
  user                        => 'fwernli',
  group                       => 'fwernli',
  manage_init_defaults        => false,
}

syslog_ng::template {'t_demo_filetemplate':
    params => [
        {
            'type'    => 'template',
            'options' => [
                '"$ISODATE $HOST $MSG\n"'
            ]
        },
        {
            'type'    => 'template_escape',
            'options' => [
                'no'
            ]
        }
    ]
}
