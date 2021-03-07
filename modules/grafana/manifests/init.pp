# class: grafana
class grafana (
    String $grafana_password = lookup('passwords::db::grafana'),
    String $mail_password = lookup('passwords::mail::noreply'),
    String $ldap_password = lookup('passwords::ldap_password'),
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

    file { '/etc/grafana/grafana.ini':
        content => template('grafana/grafana.ini.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Service['grafana-server'],
        require => Package['grafana'],
    }

    file { '/etc/grafana/ldap.toml':
        content => template('grafana/ldap.toml.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Service['grafana-server'],
        require => Package['grafana'],
    }

    service { 'grafana-server':
        ensure  => 'running',
        enable  => true,
        require => Package['grafana'],
    }

    include ssl::wildcard

    nginx::site { 'grafana.miraheze.org':
        ensure => present,
        source => 'puppet:///modules/grafana/nginx/grafana.conf',
    }

    monitoring::services { 'grafana.miraheze.org HTTPS':
        check_command => 'check_http',
        vars          => {
            http_ssl   => true,
            http_vhost => 'grafana.miraheze.org',
        },
     }
}
