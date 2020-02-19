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

    $new_servers = hiera('new_servers', false)
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
