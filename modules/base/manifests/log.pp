# class: base::log
class base::log {
    class { 'syslog_ng':
        config_file_header   => '# This file is managed by Puppet',
        manage_init_defaults => false,
        manage_repo          => false
    } ->

    syslog_ng::options { 'global_options':
        options => {
            'chain_hostname' => 'off',
            'flush_lines'    => 0,
            'stats_freq'     => 0,
            'use_dns'        => 'no',
            'use_fqdn'       => 'yes',
            'dns_cache'      => 'no'
        }
    } ->

    syslog_ng::rewrite { 'r_hostname':
        params => {
            'type'    => 'set',
            'options' => [
                $::fqdn,
                {
                    'value' => 'HOST'
                }
            ]
        }
    } ->

    syslog_ng::source { 's_system':
        params => {
            'type'    => 'system',
            'options' => []
        }
    } ->

    syslog_ng::source { 's_internal':
        params => {
            'type'    => 'internal',
            'options' => []
        }
    } ->

    syslog_ng::source { 's_udp':
        params => {
            'type'    => 'syslog',
            'options' => [
                {
                    'transport' => 'udp'
                },
                {
                    'port' => 10514
                }
            ]
        }
    } ->

    syslog_ng::destination { 'd_graylog_tls':
        params => {
            'type'    => 'syslog',
            'options' => [
                'graylog2.miraheze.org',
                {
                    'port' => [ 12210 ]
                },
                {
                    'transport' => 'tls'
                },
                {
                    'tls' => [
                        {
                            'peer-verify' => 'require-trusted'
                        },
                        {
                            'ca-dir' => '/etc/ssl/certs'
                        },
                        {
                            'ssl-options' => [
                                'no-sslv2',
                                'no-sslv3',
                                'no-tlsv1',
                                'no-tlsv11'
                            ]
                        }
                    ]
                },
                {
                    'disk-buffer' => [
                        {
                            'dir' => '/var/tmp'
                        },
                        {
                            'disk-buf-size' => '1073741824'
                        },
                        {
                            'mem-buf-size' => '33554432'
                        },
                        {
                            'reliable' => 'yes'
                        }
                    ]
                }
            ]
        }
    } ->

    syslog_ng::log { 's_system to d_graylog_tls':
        params => [
            {
                'source' => 's_system'
            },
            {
                'destination' => 'd_graylog_tls'
            }
        ]
    } ->

    syslog_ng::log { 's_internal to d_graylog_tls':
        params => [
            {
                'source' => 's_internal'
            },
            {
                'destination' => 'd_graylog_tls'
            }
        ]
    } ->

    syslog_ng::log { 's_udp to d_graylog_tls':
        params => [
            {
                'source' => 's_udp'
            },
            {
                'destination' => 'd_graylog_tls'
            }
        ]
    }
}
