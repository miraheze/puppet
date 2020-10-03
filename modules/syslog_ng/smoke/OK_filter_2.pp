class  { 'syslog_ng':
  config_file                 => '/tmp/syslog-ng.conf',
  manage_package              => false,
  syntax_check_before_reloads => false,
  user                        => 'fwernli',
  group                       => 'fwernli',
  manage_init_defaults        => false,
}

syslog_ng::filter {'f_tag_filter':
    params => {
        'type'    => 'tags',
        'options' => [
            '".classifier.system"'
        ]
    }
}

syslog_ng::filter {'f_tag_filter_2':
    params => {
      'tags' => [
          '".classifier.system"'
      ]
    }
}
