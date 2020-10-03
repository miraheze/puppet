class  { 'syslog_ng':
  config_file                 => '/tmp/syslog-ng.conf',
  manage_package              => false,
  syntax_check_before_reloads => false,
  user                        => 'fwernli',
  group                       => 'fwernli',
  manage_init_defaults        => false,
}

syslog_ng::source { 's_gsoc':
    params => {
        'type'    => 'tcp',
        'options' => [
          { 'ip' => "'127.0.0.1'" },
          { 'port' => 1999 }
        ]
    }
}

syslog_ng::source {'s_external':
    params => [
        { 'type'    => 'udp',
          'options' => [
            {'ip' => ["'127.0.0.1'"]},
            {'port' => [514]}
            ]
        },
        { 'type'    => 'tcp',
          'options' => [
            {'ip' => ["'127.0.0.1'"]},
            {'port' => [514]}
            ]
        },
        {
          'type'    => 'syslog',
          'options' => [
            {'flags' => ['no-multi-line', 'no-parse']},
            {'ip' => ["'127.0.0.1'"]},
            {'keep-alive' => ['yes']},
            {'keep_hostname' => ['yes']},
            {'transport' => ['udp']}
            ]
        },
        {
            'tcp'  =>  [
                {'ip' => ["'127.0.0.1'"]},
                {'port' => [514]},
                {'tls' => [
                    {'key_file' => ['"/opt/syslog-ng/etc/syslog-ng/key.d/syslog-ng.key"']},
                    {'cert_file'=> '"/opt/syslog-ng/etc/syslog-ng/cert.d/syslog-ng.cert"'},
                    {'peer_verify' => 'optional-untrusted'}
                ]}
            ]
        }
    ]
}

