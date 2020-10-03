class  { 'syslog_ng':
  config_file                 => '/tmp/syslog-ng.conf',
  manage_package              => false,
  syntax_check_before_reloads => false,
  user                        => 'fwernli',
  group                       => 'fwernli',
  manage_init_defaults        => false,
}

#lint:ignore:autoloader_layout
class syslog_ng::default_config {
#lint:endignore

    syslog_ng::config {'header comment':
        content => '
    # Default syslog-ng.conf file which collects all local logs into a
    # single file called /var/log/messages.
    #
    '}

    syslog_ng::config {'version':
        content => '@version: 3.6',
        order   => '03'
    }

    syslog_ng::source {'s_local':
        params => [
            {
                'type'    => 'system',
                'options' => ''
            },
            {
                'type'    => 'internal',
                'options' => ''
            }
        ]
    }

    syslog_ng::source {'s_local':
        params =>
            {
                'type'    => 'udp',
                'options' => ''
            }
    }

    syslog_ng::destination { 'd_local':
        params =>
            {
                'type'    => 'file',
                'options' => [
                    '/var/log/messages'
                ]
            }
    }

    syslog_ng::log { 'l':
        params => [
            {'source' => 's_local'},
            {'destination' => 'd_local'}
        ]
    }
}
