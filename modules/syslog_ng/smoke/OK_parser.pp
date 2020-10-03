class  { 'syslog_ng':
  config_file                 => '/tmp/syslog-ng.conf',
  manage_package              => false,
  syntax_check_before_reloads => false,
  user                        => 'fwernli',
  group                       => 'fwernli',
  manage_init_defaults        => false,
}

syslog_ng::parser {'p_hostname_segmentation':
    params => {
        'type'    => 'csv-parser',
        'options' => [
            {'columns' => [
                '"HOSTNAME.NAME"',
                '"HOSTNAME.ID"'
            ]},
            {'delimiters' => '"-"'},
            {'flags' => 'escape-none'},
#lint:ignore:single_quote_string_with_variables
            {'template' => '"${HOST}"'}
#lint:endignore
        ]
    }
}

