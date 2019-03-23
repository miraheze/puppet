# class: grafana
class grafana (
    String $grafana_password = hiera('passwords::db::grafana'),
    String $mail_password = hiera('passwords::mail::noreply'),
) {

    include ::apt

    apt::source { 'grafana_apt':
        comment  => 'Grafana stable',
        location => 'https://packages.grafana.com/oss/deb',
        release  => 'stable',
        repos    => 'main',
        key      => 'F51A91A5EE001AA5D77D53C4C6E319C334410682',
    }

    package { 'grafana':
        ensure  => present,
        require => Apt::Source['grafana_apt'],
    }

    ensure_resource_duplicate('class', 'php::php_fpm', {
        'config'  => {
            'display_errors'            => 'Off',
            'error_log'                 => '/var/log/php/php.log',
            'error_reporting'           => 'E_ALL & ~E_DEPRECATED & ~E_STRICT',
            'log_errors'                => 'On',
            'max_execution_time'        => 70,
            'opcache'                   => {
                'enable'                  => 1,
                'memory_consumption'      => 256,
                'interned_strings_buffer' => 64,
                'max_accelerated_files'   => 32531,
                'revalidate_freq'         => 60,
            },
            'post_max_size'       => '35M',
            'register_argc_argv'  => 'Off',
            'request_order'       => 'GP',
            'track_errors'        => 'Off',
            'upload_max_filesize' => '100M',
            'variables_order'     => 'GPCS',
        },
        'version' => hiera('php::php_version', '7.3'),
    })

    file { '/etc/grafana/grafana.ini':
        content => template('grafana/grafana.ini.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => Package['grafana'],
    }

    service { 'grafana-server':
        ensure => 'running',
        enable => true,
        subscribe => [
            File['/etc/grafana/grafana.ini'],
            Package['grafana'],
        ],
    }

    include ssl::wildcard

    nginx::site { 'grafana.miraheze.org':
        ensure       => present,
        source       => 'puppet:///modules/grafana/nginx/grafana.conf',
        notify_site  => Exec['nginx-syntax-grafana'],
    }

    exec { 'nginx-syntax-grafana':
        command     => '/usr/sbin/nginx -t',
        notify      => Exec['nginx-reload-grafana'],
        refreshonly => true,
    }

    exec { 'nginx-reload-grafana':
        command     => '/usr/sbin/service nginx reload',
        refreshonly => true,
        require     => Exec['nginx-syntax-grafana'],
    }

    monitoring::services { 'grafana.miraheze.org HTTPS':
        check_command => 'check_http',
        vars          => {
            http_ssl   => true,
            http_vhost => 'grafana.miraheze.org',
        },
     }
}
